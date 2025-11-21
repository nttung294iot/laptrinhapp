-- =====================================================
-- Script Setup PostgreSQL cho Quản Lý Thư Viện
-- Version: 2.0 (Updated with 8 tables + AI Chatbot support)
-- =====================================================
-- Chạy script này trong PostgreSQL để tạo database và tables
-- Cách chạy:
--   1. Mở pgAdmin hoặc psql
--   2. Kết nối với PostgreSQL server
--   3. Chạy toàn bộ script này
-- =====================================================

-- Tạo database (nếu chưa có)
-- Lưu ý: Phải chạy lệnh này riêng nếu đang kết nối vào database khác
-- DROP DATABASE IF EXISTS quan_ly_thu_vien_dev;
-- CREATE DATABASE quan_ly_thu_vien_dev
--     WITH 
--     OWNER = postgres
--     ENCODING = 'UTF8'
--     LC_COLLATE = 'en_US.UTF-8'
--     LC_CTYPE = 'en_US.UTF-8'
--     TABLESPACE = pg_default
--     CONNECTION LIMIT = -1;

-- Kết nối vào database (trong psql: \c quan_ly_thu_vien_dev)

-- =====================================================
-- TABLE 1: books (Sách)
-- =====================================================
CREATE TABLE IF NOT EXISTS books (
    id SERIAL PRIMARY KEY,
    book_code VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(500) NOT NULL,
    author VARCHAR(255),
    category VARCHAR(100),
    isbn VARCHAR(50),
    barcode VARCHAR(50) UNIQUE,
    publisher VARCHAR(255),
    publish_year INTEGER,
    total_copies INTEGER NOT NULL DEFAULT 1,
    available_copies INTEGER NOT NULL DEFAULT 1,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index cho books
CREATE INDEX IF NOT EXISTS idx_books_book_code ON books(book_code);
CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
CREATE INDEX IF NOT EXISTS idx_books_author ON books(author);
CREATE INDEX IF NOT EXISTS idx_books_category ON books(category);
CREATE INDEX IF NOT EXISTS idx_books_barcode ON books(barcode);

COMMENT ON TABLE books IS 'Bảng quản lý sách trong thư viện';
COMMENT ON COLUMN books.barcode IS 'Mã barcode để quét (ISBN hoặc custom)';
COMMENT ON COLUMN books.available_copies IS 'Số lượng sách còn có thể mượn';

-- =====================================================
-- TABLE 2: readers (Độc giả)
-- =====================================================
CREATE TABLE IF NOT EXISTS readers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    student_id VARCHAR(50) UNIQUE,
    rfid_card_uid VARCHAR(20) UNIQUE,
    class VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    date_of_birth DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index cho readers
CREATE INDEX IF NOT EXISTS idx_readers_student_id ON readers(student_id);
CREATE INDEX IF NOT EXISTS idx_readers_name ON readers(name);
CREATE INDEX IF NOT EXISTS idx_readers_class ON readers(class);
CREATE INDEX IF NOT EXISTS idx_readers_rfid_card_uid ON readers(rfid_card_uid);

COMMENT ON TABLE readers IS 'Bảng quản lý độc giả';
COMMENT ON COLUMN readers.rfid_card_uid IS 'UID của thẻ RFID (unique)';
COMMENT ON COLUMN readers.student_id IS 'Mã sinh viên (unique)';

-- =====================================================
-- TABLE 3: borrow_cards (Phiếu mượn sách)
-- =====================================================
CREATE TABLE IF NOT EXISTS borrow_cards (
    id SERIAL PRIMARY KEY,
    reader_id INTEGER,
    book_id INTEGER,
    borrower_name VARCHAR(255) NOT NULL,
    borrower_class VARCHAR(100),
    borrower_student_id VARCHAR(50),
    borrower_phone VARCHAR(20),
    borrower_email VARCHAR(255),
    book_name VARCHAR(500) NOT NULL,
    book_code VARCHAR(100),
    borrow_date DATE NOT NULL,
    expected_return_date DATE NOT NULL,
    actual_return_date DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'borrowed',
    created_by_user_id INTEGER,
    approved_by_user_id INTEGER,
    returned_by_user_id INTEGER,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index cho borrow_cards
CREATE INDEX IF NOT EXISTS idx_borrow_cards_reader_id ON borrow_cards(reader_id);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_book_id ON borrow_cards(book_id);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_status ON borrow_cards(status);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_borrower_name ON borrow_cards(borrower_name);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_borrower_student_id ON borrow_cards(borrower_student_id);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_book_code ON borrow_cards(book_code);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_borrower_email ON borrow_cards(borrower_email);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_book_name ON borrow_cards(book_name);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_borrow_date ON borrow_cards(borrow_date);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_expected_return_date ON borrow_cards(expected_return_date);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_created_by ON borrow_cards(created_by_user_id);

COMMENT ON TABLE borrow_cards IS 'Bảng quản lý phiếu mượn sách';
COMMENT ON COLUMN borrow_cards.status IS 'Trạng thái: borrowed/returned/overdue';
COMMENT ON COLUMN borrow_cards.reader_id IS 'FK: Độc giả mượn sách';
COMMENT ON COLUMN borrow_cards.book_id IS 'FK: Sách được mượn';
COMMENT ON COLUMN borrow_cards.created_by_user_id IS 'FK: User tạo phiếu mượn';
COMMENT ON COLUMN borrow_cards.approved_by_user_id IS 'FK: User duyệt phiếu';
COMMENT ON COLUMN borrow_cards.returned_by_user_id IS 'FK: User xác nhận trả sách';

-- =====================================================
-- TABLE 4: users (Người dùng hệ thống - Authentication)
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Index cho users
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

COMMENT ON TABLE users IS 'Bảng người dùng hệ thống (Authentication)';
COMMENT ON COLUMN users.role IS 'Vai trò: admin/librarian/user';

-- =====================================================
-- TABLE 5: password_reset_tokens (Token reset mật khẩu)
-- =====================================================
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index cho password_reset_tokens
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token ON password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires_at ON password_reset_tokens(expires_at);

COMMENT ON TABLE password_reset_tokens IS 'Bảng token reset mật khẩu';

-- =====================================================
-- TABLE 6: login_history (Lịch sử đăng nhập)
-- =====================================================
CREATE TABLE IF NOT EXISTS login_history (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    login_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_info TEXT,
    ip_address VARCHAR(50),
    success BOOLEAN DEFAULT true
);

-- Index cho login_history
CREATE INDEX IF NOT EXISTS idx_login_history_user_id ON login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_login_time ON login_history(login_time);

COMMENT ON TABLE login_history IS 'Bảng lịch sử đăng nhập';

-- =====================================================
-- TABLE 7: iot_scan_logs (Log quét thẻ RFID)
-- =====================================================
CREATE TABLE IF NOT EXISTS iot_scan_logs (
    id SERIAL PRIMARY KEY,
    card_uid VARCHAR(20) NOT NULL,
    reader_id INTEGER,
    reader_name VARCHAR(255),
    scan_result VARCHAR(20) DEFAULT 'success',
    error_message TEXT,
    scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index cho iot_scan_logs
CREATE INDEX IF NOT EXISTS idx_iot_scan_logs_scanned_at ON iot_scan_logs(scanned_at DESC);
CREATE INDEX IF NOT EXISTS idx_iot_scan_logs_reader_id ON iot_scan_logs(reader_id);
CREATE INDEX IF NOT EXISTS idx_iot_scan_logs_card_uid ON iot_scan_logs(card_uid);

COMMENT ON TABLE iot_scan_logs IS 'Bảng log quét thẻ RFID';
COMMENT ON COLUMN iot_scan_logs.scan_result IS 'Kết quả quét: success/error/not_found';

-- =====================================================
-- TABLE 8: scan_logs (Log quét barcode sách)
-- =====================================================
CREATE TABLE IF NOT EXISTS scan_logs (
    id SERIAL PRIMARY KEY,
    reader_id INTEGER,
    book_id INTEGER,
    student_id VARCHAR(50),
    barcode VARCHAR(50),
    scan_type VARCHAR(20),
    device_info VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index cho scan_logs
CREATE INDEX IF NOT EXISTS idx_scan_logs_reader_id ON scan_logs(reader_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_book_id ON scan_logs(book_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_student_id ON scan_logs(student_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_scan_type ON scan_logs(scan_type);
CREATE INDEX IF NOT EXISTS idx_scan_logs_created_at ON scan_logs(created_at DESC);

COMMENT ON TABLE scan_logs IS 'Log quét barcode sách (từ ESP32-CAM)';
COMMENT ON COLUMN scan_logs.scan_type IS 'Loại quét: rfid/barcode/manual';
COMMENT ON COLUMN scan_logs.device_info IS 'Thiết bị: ESP32-CAM/ESP32-S3/App';

-- =====================================================
-- TABLE 9 (BONUS): notifications (Thông báo)
-- =====================================================
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    reader_id INTEGER,
    borrow_card_id INTEGER,
    type VARCHAR(50),
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
);

-- Index cho notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_reader_id ON notifications(reader_id);
CREATE INDEX IF NOT EXISTS idx_notifications_borrow_card_id ON notifications(borrow_card_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_sent_at ON notifications(sent_at DESC);

COMMENT ON TABLE notifications IS 'Bảng thông báo (quá hạn, nhắc nhở, etc.)';
COMMENT ON COLUMN notifications.type IS 'Loại: overdue/reminder/approved/returned';

-- =====================================================
-- FOREIGN KEYS (Optional - Uncomment nếu muốn)
-- =====================================================

-- Borrow cards relationships
-- ALTER TABLE borrow_cards
-- ADD CONSTRAINT fk_borrow_cards_reader
-- FOREIGN KEY (reader_id) REFERENCES readers(id)
-- ON DELETE SET NULL ON UPDATE CASCADE;

-- ALTER TABLE borrow_cards
-- ADD CONSTRAINT fk_borrow_cards_book
-- FOREIGN KEY (book_id) REFERENCES books(id)
-- ON DELETE SET NULL ON UPDATE CASCADE;

-- ALTER TABLE borrow_cards
-- ADD CONSTRAINT fk_borrow_cards_created_by
-- FOREIGN KEY (created_by_user_id) REFERENCES users(id)
-- ON DELETE SET NULL ON UPDATE CASCADE;

-- ALTER TABLE borrow_cards
-- ADD CONSTRAINT fk_borrow_cards_approved_by
-- FOREIGN KEY (approved_by_user_id) REFERENCES users(id)
-- ON DELETE SET NULL ON UPDATE CASCADE;

-- ALTER TABLE borrow_cards
-- ADD CONSTRAINT fk_borrow_cards_returned_by
-- FOREIGN KEY (returned_by_user_id) REFERENCES users(id)
-- ON DELETE SET NULL ON UPDATE CASCADE;

-- IoT scan logs relationships
-- ALTER TABLE iot_scan_logs
-- ADD CONSTRAINT fk_iot_scan_logs_reader
-- FOREIGN KEY (reader_id) REFERENCES readers(id)
-- ON DELETE SET NULL ON UPDATE CASCADE;

-- Scan logs relationships
-- ALTER TABLE scan_logs
-- ADD CONSTRAINT fk_scan_logs_reader
-- FOREIGN KEY (reader_id) REFERENCES readers(id)
-- ON DELETE SET NULL ON UPDATE CASCADE;

-- ALTER TABLE scan_logs
-- ADD CONSTRAINT fk_scan_logs_book
-- FOREIGN KEY (book_id) REFERENCES books(id)
-- ON DELETE CASCADE ON UPDATE CASCADE;

-- Notifications relationships
-- ALTER TABLE notifications
-- ADD CONSTRAINT fk_notifications_user
-- FOREIGN KEY (user_id) REFERENCES users(id)
-- ON DELETE CASCADE ON UPDATE CASCADE;

-- ALTER TABLE notifications
-- ADD CONSTRAINT fk_notifications_reader
-- FOREIGN KEY (reader_id) REFERENCES readers(id)
-- ON DELETE CASCADE ON UPDATE CASCADE;

-- ALTER TABLE notifications
-- ADD CONSTRAINT fk_notifications_borrow_card
-- FOREIGN KEY (borrow_card_id) REFERENCES borrow_cards(id)
-- ON DELETE CASCADE ON UPDATE CASCADE;

-- =====================================================
-- Function để tự động cập nhật updated_at
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger cho borrow_cards
DROP TRIGGER IF EXISTS update_borrow_cards_updated_at ON borrow_cards;
CREATE TRIGGER update_borrow_cards_updated_at
    BEFORE UPDATE ON borrow_cards
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger cho books
DROP TRIGGER IF EXISTS update_books_updated_at ON books;
CREATE TRIGGER update_books_updated_at
    BEFORE UPDATE ON books
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger cho readers
DROP TRIGGER IF EXISTS update_readers_updated_at ON readers;
CREATE TRIGGER update_readers_updated_at
    BEFORE UPDATE ON readers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger cho users
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Function: Log scan event
-- =====================================================
CREATE OR REPLACE FUNCTION log_scan_event(
    p_card_uid VARCHAR(20),
    p_reader_id INTEGER DEFAULT NULL,
    p_reader_name VARCHAR(255) DEFAULT NULL,
    p_scan_result VARCHAR(20) DEFAULT 'success',
    p_error_message TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_log_id INTEGER;
BEGIN
    INSERT INTO iot_scan_logs (
        card_uid,
        reader_id,
        reader_name,
        scan_result,
        error_message,
        scanned_at
    )
    VALUES (
        p_card_uid,
        p_reader_id,
        p_reader_name,
        p_scan_result,
        p_error_message,
        CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION log_scan_event IS 'Ghi log mỗi lần quét thẻ RFID';

-- =====================================================
-- VIEWS hữu ích
-- =====================================================

-- View: Thống kê sách đang được mượn
CREATE OR REPLACE VIEW v_borrowed_books_summary AS
SELECT 
    b.book_code,
    b.title,
    b.total_copies,
    b.available_copies,
    COUNT(bc.id) as currently_borrowed
FROM books b
LEFT JOIN borrow_cards bc ON b.book_code = bc.book_code AND bc.status = 'borrowed'
GROUP BY b.id, b.book_code, b.title, b.total_copies, b.available_copies;

COMMENT ON VIEW v_borrowed_books_summary IS 'Thống kê sách đang được mượn';

-- View: Phiếu mượn quá hạn
CREATE OR REPLACE VIEW v_overdue_borrow_cards AS
SELECT 
    bc.*,
    CURRENT_DATE - bc.expected_return_date as days_overdue
FROM borrow_cards bc
WHERE bc.status != 'returned' 
  AND bc.expected_return_date < CURRENT_DATE
ORDER BY bc.expected_return_date ASC;

COMMENT ON VIEW v_overdue_borrow_cards IS 'Danh sách phiếu mượn quá hạn';

-- View: Thống kê độc giả
CREATE OR REPLACE VIEW v_reader_statistics AS
SELECT 
    r.id,
    r.name,
    r.student_id,
    r.class,
    COUNT(bc.id) as total_borrows,
    COUNT(CASE WHEN bc.status = 'borrowed' THEN 1 END) as current_borrows,
    COUNT(CASE WHEN bc.status = 'returned' THEN 1 END) as returned_borrows,
    COUNT(CASE WHEN bc.status = 'overdue' THEN 1 END) as overdue_borrows
FROM readers r
LEFT JOIN borrow_cards bc ON r.student_id = bc.borrower_student_id
GROUP BY r.id, r.name, r.student_id, r.class;

COMMENT ON VIEW v_reader_statistics IS 'Thống kê hoạt động của độc giả';

-- View: Lịch sử quét thẻ
CREATE OR REPLACE VIEW v_scan_history AS
SELECT 
    isl.id,
    isl.card_uid,
    isl.reader_name,
    isl.scan_result,
    isl.scanned_at
FROM iot_scan_logs isl
ORDER BY isl.scanned_at DESC;

COMMENT ON VIEW v_scan_history IS 'Lịch sử quét thẻ RFID';

-- =====================================================
-- Dữ liệu mẫu (Sample Data) - CHỈ DÙNG KHI SETUP LẦN ĐẦU
-- =====================================================
-- LƯU Ý: Nếu database đã có data thực, COMMENT hoặc XÓA phần này
-- để tránh conflict với data hiện tại
-- =====================================================

/*
-- Uncomment phần này NẾU muốn thêm sample data (chỉ dùng lần đầu)

-- Thêm user mẫu (password: "admin123" đã hash)
-- Lưu ý: Trong production, password phải được hash bằng bcrypt
INSERT INTO users (username, email, password_hash, full_name, role, is_active) VALUES
('admin', 'admin@library.com', '$2a$10$rKvqLZZ9Z9Z9Z9Z9Z9Z9ZuXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxX', 'Quản trị viên', 'admin', true),
('librarian', 'librarian@library.com', '$2a$10$rKvqLZZ9Z9Z9Z9Z9Z9Z9ZuXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxX', 'Thủ thư', 'librarian', true),
('user', 'user@library.com', '$2a$10$rKvqLZZ9Z9Z9Z9Z9Z9Z9ZuXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxX', 'Người dùng', 'user', true)
ON CONFLICT (username) DO NOTHING;

-- Thêm sách mẫu
INSERT INTO books (book_code, title, author, category, isbn, barcode, publisher, publish_year, total_copies, available_copies, description) VALUES
('BK001', 'Lập trình Flutter cơ bản', 'Nguyễn Văn A', 'Công nghệ', '978-604-1-00001-1', '978-604-1-00001-1', 'NXB Trẻ', 2023, 5, 4, 'Sách hướng dẫn lập trình Flutter từ cơ bản đến nâng cao'),
('BK002', 'Dart Programming', 'Trần Thị B', 'Công nghệ', '978-604-1-00002-2', '978-604-1-00002-2', 'NXB Giáo dục', 2023, 3, 3, 'Giáo trình lập trình Dart'),
('BK003', 'Toán học rời rạc', 'Lê Văn C', 'Toán học', '978-604-1-00003-3', '978-604-1-00003-3', 'NXB Đại học Quốc gia', 2022, 10, 8, 'Giáo trình toán học rời rạc'),
('BK004', 'Cấu trúc dữ liệu và giải thuật', 'Phạm Văn D', 'Công nghệ', '978-604-1-00004-4', '978-604-1-00004-4', 'NXB Thông tin và Truyền thông', 2023, 7, 6, 'Sách về cấu trúc dữ liệu và giải thuật'),
('BK005', 'Cơ sở dữ liệu', 'Hoàng Thị E', 'Công nghệ', '978-604-1-00005-5', '978-604-1-00005-5', 'NXB Khoa học và Kỹ thuật', 2022, 8, 7, 'Giáo trình cơ sở dữ liệu')
ON CONFLICT (book_code) DO NOTHING;

-- Thêm độc giả mẫu
INSERT INTO readers (name, student_id, rfid_card_uid, class, phone, email, address, date_of_birth) VALUES
('Nguyễn Văn An', 'SV001', 'A1B2C3D4', '12A1', '0901234567', 'an.nguyen@email.com', 'Hà Nội', '2005-03-15'),
('Trần Thị Bình', 'SV002', 'E5F6G7H8', '12A2', '0902345678', 'binh.tran@email.com', 'Hồ Chí Minh', '2005-05-20'),
('Lê Văn Cường', 'SV003', 'I9J0K1L2', '12A1', '0903456789', 'cuong.le@email.com', 'Đà Nẵng', '2005-07-10'),
('Phạm Thị Dung', 'SV004', 'M3N4O5P6', '12A3', '0904567890', 'dung.pham@email.com', 'Hải Phòng', '2005-02-28'),
('Hoàng Văn Em', 'SV005', 'Q7R8S9T0', '12A2', '0905678901', 'em.hoang@email.com', 'Cần Thơ', '2005-09-05')
ON CONFLICT (student_id) DO NOTHING;

-- Thêm phiếu mượn mẫu
INSERT INTO borrow_cards (borrower_name, borrower_class, borrower_student_id, borrower_phone, borrower_email, book_name, book_code, borrow_date, expected_return_date, actual_return_date, status) VALUES
('Nguyễn Văn An', '12A1', 'SV001', '0901234567', 'an.nguyen@email.com', 'Lập trình Flutter cơ bản', 'BK001', '2025-01-05', '2025-01-19', NULL, 'borrowed'),
('Trần Thị Bình', '12A2', 'SV002', '0902345678', 'binh.tran@email.com', 'Toán học rời rạc', 'BK003', '2025-01-08', '2025-01-22', NULL, 'borrowed'),
('Lê Văn Cường', '12A1', 'SV003', '0903456789', 'cuong.le@email.com', 'Cấu trúc dữ liệu và giải thuật', 'BK004', '2024-12-20', '2025-01-03', '2025-01-02', 'returned'),
('Phạm Thị Dung', '12A3', 'SV004', '0904567890', 'dung.pham@email.com', 'Cơ sở dữ liệu', 'BK005', '2024-12-25', '2025-01-08', NULL, 'overdue'),
('Hoàng Văn Em', '12A2', 'SV005', '0905678901', 'em.hoang@email.com', 'Toán học rời rạc', 'BK003', '2025-01-10', '2025-01-24', NULL, 'borrowed')
ON CONFLICT DO NOTHING;

*/

-- =====================================================
-- Nếu database đã có data thực, chỉ cần chạy phần trên
-- (CREATE TABLE, INDEXES, FUNCTIONS, VIEWS)
-- và BỎ QUA phần sample data này
-- =====================================================

-- =====================================================
-- Hoàn thành!
-- =====================================================

-- Kiểm tra kết quả
SELECT 'Số lượng sách:' as info, COUNT(*) as count FROM books
UNION ALL
SELECT 'Số lượng độc giả:', COUNT(*) FROM readers
UNION ALL
SELECT 'Số lượng phiếu mượn:', COUNT(*) FROM borrow_cards
UNION ALL
SELECT 'Số lượng users:', COUNT(*) FROM users;

-- Hiển thị thông tin tables
SELECT 
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- =====================================================
-- SUMMARY
-- =====================================================
-- Total Tables: 9 (8 main + 1 bonus notifications)
-- Total Views: 4
-- Total Functions: 2
-- Total Triggers: 4
-- Total Indexes: 40+
-- =====================================================
