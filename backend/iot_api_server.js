/**
 * IoT API Server for Library Management System
 * Backend để nhận request từ ESP32-CAM
 * 
 * Requirements:
 * - Node.js 16+
 * - npm install express pg cors body-parser
 * 
 * Run:
 * node iot_api_server.js
 */

const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const bodyParser = require('body-parser');
const multer = require('multer');
const axios = require('axios');
const FormData = require('form-data');

const app = express();
const PORT = 3000;

// ============================================
// CONFIGURATION - Sửa thông tin database
// ============================================

const pool = new Pool({
    host: 'localhost',  // ← Dùng localhost nếu backend chạy cùng máy database
    port: 5432,
    database: 'quan_ly_thu_vien_dev',
    user: 'postgres',
    password: '1234',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,  // Tăng timeout lên 5s
});

// ============================================
// IN-MEMORY SESSION STORAGE
// ============================================

// Lưu session quét: { studentId: { student: {...}, book: {...}, timestamp: ... } }
const scanSessions = new Map();
const SESSION_TIMEOUT = 60000; // 60 seconds

// Cleanup old sessions every 30 seconds
setInterval(() => {
    const now = Date.now();
    for (const [key, session] of scanSessions.entries()) {
        if (now - session.timestamp > SESSION_TIMEOUT) {
            console.log('[SESSION] Expired:', key);
            scanSessions.delete(key);
        }
    }
}, 30000);

// ============================================
// MIDDLEWARE
// ============================================

app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Multer for file upload
const upload = multer({ storage: multer.memoryStorage() });

// Logging middleware
app.use((req, res, next) => {
    const timestamp = new Date().toISOString();
    const clientIP = req.ip || req.connection.remoteAddress;
    console.log(`[${timestamp}] ${req.method} ${req.path} from ${clientIP}`);
    next();
});

// Response settings for ESP32 compatibility
app.use((req, res, next) => {
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Content-Type', 'application/json');
    next();
});

// ============================================
// ROUTES
// ============================================

// Health check
app.get('/', (req, res) => {
    res.json({
        status: 'ok',
        message: 'IoT API Server is running',
        timestamp: new Date().toISOString()
    });
});

// ============================================
// POST /api/iot/scan-student-card
// Nhận request quét thẻ RFID từ ESP32
// ============================================

app.post('/api/iot/scan-student-card', async (req, res) => {
    const { card_uid } = req.body;
    
    console.log('[SCAN] Card UID:', card_uid);
    
    try {
        // 1. Tìm độc giả theo rfid_card_uid
        const readerQuery = `
            SELECT 
                id,
                student_id,
                name,
                class,
                phone,
                email
            FROM readers
            WHERE rfid_card_uid = $1
        `;
        
        const result = await pool.query(readerQuery, [card_uid]);
        
        if (result.rows.length === 0) {
            // Không tìm thấy thẻ
            console.log('[SCAN] Card not found:', card_uid);
            
            // Log scan event
            await pool.query(
                `SELECT log_scan_event($1, NULL, NULL, 'failed', 'Card not registered')`,
                [card_uid]
            );
            
            return res.json({
                success: false,
                error: 'Khong tim thay',
                message: 'Thẻ chưa được đăng ký trong hệ thống'
            });
        }
        
        const reader = result.rows[0];
        
        // 2. Thành công - Log và trả về thông tin
        console.log('[SCAN] Reader found:', reader.student_id, reader.name);
        
        await pool.query(
            `SELECT log_scan_event($1, $2, $3, 'success', NULL)`,
            [card_uid, reader.id, reader.name]
        );
        
        // 3. Lưu vào session để app có thể lấy
        const studentData = {
            student_id: reader.student_id,
            name: reader.name,
            class: reader.class || '',
            phone: reader.phone || '',
            email: reader.email || ''
        };
        
        scanSessions.set(reader.student_id, {
            student: studentData,
            book: null,
            timestamp: Date.now()
        });
        
        console.log('[SESSION] Saved student:', reader.student_id);
        
        res.json({
            success: true,
            reader: studentData,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('[ERROR] Database error:', error);
        
        res.status(500).json({
            success: false,
            error: 'Loi he thong',
            message: error.message
        });
    }
});

// ============================================
// GET /api/iot/heartbeat
// Nhận heartbeat từ ESP32 (đơn giản)
// ============================================

app.get('/api/iot/heartbeat', async (req, res) => {
    console.log('[HEARTBEAT] OK');
    res.json({ success: true, timestamp: new Date().toISOString() });
});

// ============================================
// POST /api/iot/scan-book-image
// Nhận ảnh từ ESP32-CAM, decode barcode, tra cứu sách
// ============================================

app.post('/api/iot/scan-book-image', upload.single('image'), async (req, res) => {
    console.log('[IMAGE] Received image from ESP32-CAM');
    
    if (!req.file) {
        return res.json({
            success: false,
            error: 'No image uploaded'
        });
    }
    
    try {
        // Gửi ảnh tới Barcode Decoder (localhost)
        const formData = new FormData();
        formData.append('image', req.file.buffer, {
            filename: 'barcode.jpg',
            contentType: 'image/jpeg'
        });
        
        console.log('[DECODE] Sending to barcode decoder...');
        const decodeResponse = await axios.post('http://localhost:5000/decode-barcode', formData, {
            headers: formData.getHeaders(),
            timeout: 15000
        });
        
        if (!decodeResponse.data.success) {
            console.log('[DECODE] Failed:', decodeResponse.data.error);
            return res.json({
                success: false,
                error: 'Khong tim thay barcode',
                message: decodeResponse.data.error
            });
        }
        
        const barcode = decodeResponse.data.barcode;
        console.log('[DECODE] Barcode:', barcode);
        
        // Tìm sách theo barcode hoặc isbn
        const bookQuery = `
            SELECT 
                id, book_code, title, author, category,
                available_copies, total_copies, isbn, barcode
            FROM books
            WHERE barcode = $1 OR isbn = $1
        `;
        
        const result = await pool.query(bookQuery, [barcode]);
        
        if (result.rows.length === 0) {
            console.log('[BOOK] Not found:', barcode);
            return res.json({
                success: false,
                error: 'Khong tim thay sach',
                barcode: barcode
            });
        }
        
        const book = result.rows[0];
        console.log('[BOOK] Found:', book.book_code, book.title);
        
        // Log scan vào database
        const student_id = req.body.student_id || 'UNKNOWN';
        try {
            await pool.query(
                `INSERT INTO scan_logs (student_id, book_id, barcode, created_at) 
                 VALUES ($1, $2, $3, NOW())`,
                [student_id, book.id, barcode]
            );
            console.log('[LOG] Scan logged for student:', student_id);
        } catch (logError) {
            console.error('[LOG] Failed to log scan:', logError.message);
        }
        
        // Cập nhật session với thông tin sách
        const bookData = {
            book_code: book.book_code,
            title: book.title,
            author: book.author,
            category: book.category,
            available_copies: book.available_copies,
            total_copies: book.total_copies
        };
        
        // Tìm session của student gần nhất (trong 60s)
        const now = Date.now();
        for (const [studentId, session] of scanSessions.entries()) {
            if (now - session.timestamp < SESSION_TIMEOUT && !session.book) {
                session.book = bookData;
                session.timestamp = now;
                console.log('[SESSION] Updated with book for student:', studentId);
                break;
            }
        }
        
        res.json({
            success: true,
            barcode: barcode,
            book: bookData
        });
        
    } catch (error) {
        console.error('[ERROR]', error.message);
        res.json({
            success: false,
            error: 'Loi xu ly',
            message: error.message
        });
    }
});

// ============================================
// POST /api/iot/scan-book-barcode
// Nhận ảnh barcode từ ESP32-S3 Hub
// ============================================

app.post('/api/iot/scan-book-barcode', upload.single('image'), async (req, res) => {
    console.log('[BARCODE] Received request from ESP32-S3');
    
    // Kiểm tra có ảnh không
    if (!req.file) {
        // Fallback: nhận barcode text trực tiếp
        const { barcode } = req.body;
        
        if (!barcode) {
            return res.json({
                success: false,
                error: 'No image or barcode provided'
            });
        }
        
        console.log('[BARCODE] Text mode:', barcode);
        
        try {
            const bookQuery = `
                SELECT id, book_code, title, author, category,
                       available_copies, total_copies
                FROM books
                WHERE barcode = $1
            `;
            
            const result = await pool.query(bookQuery, [barcode]);
            
            if (result.rows.length === 0) {
                return res.json({
                    success: false,
                    error: 'Khong tim thay sach'
                });
            }
            
            const book = result.rows[0];
            console.log('[BARCODE] Book found:', book.title);
            
            return res.json({
                success: true,
                book: {
                    book_code: book.book_code,
                    title: book.title,
                    author: book.author || '',
                    category: book.category || '',
                    available: book.available_copies,
                    total: book.total_copies
                }
            });
            
        } catch (error) {
            console.error('[ERROR]', error);
            return res.status(500).json({
                success: false,
                error: 'Loi he thong'
            });
        }
    }
    
    // Image mode: decode barcode từ ảnh
    console.log('[BARCODE] Image mode, size:', req.file.size, 'bytes');
    
    try {
        // Gửi ảnh tới Barcode Decoder
        const formData = new FormData();
        formData.append('image', req.file.buffer, {
            filename: 'barcode.jpg',
            contentType: 'image/jpeg'
        });
        
        console.log('[DECODE] Sending to barcode decoder...');
        const decodeResponse = await axios.post('http://localhost:5000/decode-barcode', formData, {
            headers: formData.getHeaders(),
            timeout: 15000
        });
        
        if (!decodeResponse.data.success) {
            console.log('[DECODE] Failed:', decodeResponse.data.error);
            return res.json({
                success: false,
                error: 'Khong doc duoc barcode',
                message: decodeResponse.data.error
            });
        }
        
        const barcode = decodeResponse.data.barcode;
        console.log('[DECODE] Barcode:', barcode);
        
        // Tìm sách theo barcode hoặc isbn
        const bookQuery = `
            SELECT id, book_code, title, author, category,
                   available_copies, total_copies, isbn, barcode
            FROM books
            WHERE barcode = $1 OR isbn = $1
        `;
        
        const result = await pool.query(bookQuery, [barcode]);
        
        if (result.rows.length === 0) {
            console.log('[BOOK] Not found:', barcode);
            return res.json({
                success: false,
                error: 'Khong tim thay sach',
                barcode: barcode
            });
        }
        
        const book = result.rows[0];
        console.log('[BOOK] Found:', book.title);
        
        res.json({
            success: true,
            barcode: barcode,
            book: {
                book_code: book.book_code,
                title: book.title,
                author: book.author || '',
                category: book.category || '',
                available: book.available_copies,
                total: book.total_copies
            }
        });
        
    } catch (error) {
        console.error('[ERROR]', error.message);
        res.json({
            success: false,
            error: 'Loi xu ly',
            message: error.message
        });
    }
});

// ============================================
// GET /api/iot/last-scan-result
// Lấy kết quả scan sách gần nhất
// ============================================

app.get('/api/iot/last-scan-result', async (req, res) => {
    const { student_id } = req.query;
    
    console.log('[LAST-SCAN] Checking for student:', student_id);
    
    if (!student_id) {
        return res.json({
            success: false,
            error: 'student_id required'
        });
    }
    
    try {
        // Check if scan_logs table exists
        const tableCheck = await pool.query(`
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'scan_logs'
            );
        `);
        
        if (!tableCheck.rows[0].exists) {
            console.log('[LAST-SCAN] scan_logs table does not exist');
            return res.json({
                success: false,
                error: 'Scan logs not configured'
            });
        }
        
        // Lấy scan gần nhất trong 30 giây
        const query = `
            SELECT 
                b.book_code, b.title, b.author, b.category,
                b.available_copies, b.total_copies,
                sl.created_at
            FROM scan_logs sl
            JOIN books b ON sl.book_id = b.id
            WHERE sl.student_id = $1
              AND sl.created_at > NOW() - INTERVAL '30 seconds'
            ORDER BY sl.created_at DESC
            LIMIT 1
        `;
        
        const result = await pool.query(query, [student_id]);
        
        if (result.rows.length > 0) {
            const book = result.rows[0];
            console.log('[LAST-SCAN] Found:', book.book_code, book.title);
            
            res.json({
                success: true,
                book: {
                    book_code: book.book_code,
                    title: book.title,
                    author: book.author || '',
                    category: book.category || '',
                    available: book.available_copies,
                    total: book.total_copies
                },
                scanned_at: book.created_at
            });
        } else {
            console.log('[LAST-SCAN] No recent scan found');
            res.json({
                success: false,
                error: 'No recent scan found',
                message: 'Chưa có sách được quét gần đây'
            });
        }
        
    } catch (error) {
        console.error('[LAST-SCAN ERROR]', error.message);
        res.json({
            success: false,
            error: error.message
        });
    }
});

// ============================================
// GET /api/iot/scan-session
// Lấy session quét (cả thẻ + sách) cho app
// ============================================

app.get('/api/iot/scan-session', (req, res) => {
    console.log('[SESSION] App polling for scan data');
    
    // Tìm session hoàn chỉnh (có cả student và book)
    const now = Date.now();
    for (const [studentId, session] of scanSessions.entries()) {
        if (now - session.timestamp < SESSION_TIMEOUT) {
            if (session.student && session.book) {
                console.log('[SESSION] Found complete session:', studentId);
                
                // Xóa session sau khi app lấy
                scanSessions.delete(studentId);
                
                return res.json({
                    success: true,
                    data: {
                        student: session.student,
                        book: session.book,
                        scanned_at: new Date(session.timestamp).toISOString()
                    }
                });
            } else if (session.student) {
                // Có student nhưng chưa có book
                console.log('[SESSION] Waiting for book scan:', studentId);
                return res.json({
                    success: false,
                    status: 'waiting_book',
                    message: 'Đã quét thẻ, đang chờ quét sách...',
                    student: session.student
                });
            }
        }
    }
    
    // Không có session nào
    console.log('[SESSION] No active session');
    res.json({
        success: false,
        status: 'no_session',
        message: 'Chưa có quét nào. Vui lòng quét thẻ sinh viên.'
    });
});

// ============================================
// GET /api/iot/scan-logs
// Lấy lịch sử quét thẻ
// ============================================

app.get('/api/iot/scan-logs', async (req, res) => {
    const limit = parseInt(req.query.limit) || 50;
    
    try {
        const result = await pool.query(`
            SELECT * FROM v_scan_history
            LIMIT $1
        `, [limit]);
        
        res.json({
            success: true,
            logs: result.rows
        });
        
    } catch (error) {
        console.error('[ERROR]', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ============================================
// Error handling
// ============================================

app.use((err, req, res, next) => {
    console.error('[ERROR]', err);
    res.status(500).json({
        success: false,
        error: 'Internal server error',
        message: err.message
    });
});

// ============================================
// START SERVER
// ============================================

const server = app.listen(PORT, '0.0.0.0', () => {
    console.log('========================================');
    console.log('  IoT API Server');
    console.log('========================================');
    console.log(`Server running on port ${PORT}`);
    console.log(`Local:   http://localhost:${PORT}`);
    console.log(`Network: http://0.0.0.0:${PORT}`);
    console.log('========================================');
    console.log('Endpoints:');
    console.log('  POST /api/iot/scan-student-card  <- ESP32 quét thẻ RFID');
    console.log('  POST /api/iot/scan-book-barcode  <- ESP32 quét barcode sách');
    console.log('  POST /api/iot/scan-book-image    <- ESP32-CAM gửi ảnh');
    console.log('  GET  /api/iot/heartbeat          <- ESP32 heartbeat');
    console.log('  GET  /api/iot/scan-logs          <- Xem lịch sử');
    console.log('========================================\n');
    
    // Test database connection
    pool.query('SELECT NOW()', (err, res) => {
        if (err) {
            console.error('[ERROR] Database connection failed:', err.message);
        } else {
            console.log('[OK] Database connected:', res.rows[0].now);
        }
    });
});

// Server settings for better connection handling
server.keepAliveTimeout = 5000;  // 5 seconds
server.headersTimeout = 6000;    // 6 seconds (must be > keepAliveTimeout)
server.timeout = 30000;          // 30 seconds total timeout

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('\n[SHUTDOWN] Closing server...');
    pool.end(() => {
        console.log('[SHUTDOWN] Database pool closed');
        process.exit(0);
    });
});
