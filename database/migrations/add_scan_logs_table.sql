-- ============================================
-- Thêm bảng scan_logs (thiếu trong schema ban đầu)
-- Bảng này được sử dụng trong iot_api_server.js
-- ============================================

-- 1. Tạo bảng scan_logs
CREATE TABLE IF NOT EXISTS scan_logs (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50),
    book_id INTEGER REFERENCES books(id) ON DELETE CASCADE,
    barcode VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Indexes
CREATE INDEX IF NOT EXISTS idx_scan_logs_student_id ON scan_logs(student_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_book_id ON scan_logs(book_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_created_at ON scan_logs(created_at DESC);

-- 3. Comments
COMMENT ON TABLE scan_logs IS 'Log quét barcode sách từ ESP32-CAM';
COMMENT ON COLUMN scan_logs.student_id IS 'Mã sinh viên (soft reference to readers.student_id)';
COMMENT ON COLUMN scan_logs.book_id IS 'ID sách (FK to books.id)';
COMMENT ON COLUMN scan_logs.barcode IS 'Barcode đã quét';

-- ============================================
-- THÊM FOREIGN KEYS cho borrow_cards (Optional)
-- Nếu muốn data integrity chặt chẽ hơn
-- ============================================

-- Lưu ý: Hiện tại borrow_cards dùng soft references
-- Nếu muốn thêm FK, uncomment các dòng dưới:

/*
-- Thêm FK từ borrow_cards -> readers
ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_reader
FOREIGN KEY (borrower_student_id) 
REFERENCES readers(student_id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Thêm FK từ borrow_cards -> books
ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_book
FOREIGN KEY (book_code) 
REFERENCES books(book_code)
ON DELETE SET NULL
ON UPDATE CASCADE;
*/

-- ============================================
-- View: Lịch sử quét sách với thông tin đầy đủ
-- ============================================

CREATE OR REPLACE VIEW v_scan_logs_detail AS
SELECT 
    sl.id,
    sl.student_id,
    r.name as student_name,
    r.class as student_class,
    sl.book_id,
    b.book_code,
    b.title as book_title,
    b.author as book_author,
    sl.barcode,
    sl.created_at
FROM scan_logs sl
LEFT JOIN readers r ON sl.student_id = r.student_id
LEFT JOIN books b ON sl.book_id = b.id
ORDER BY sl.created_at DESC;

COMMENT ON VIEW v_scan_logs_detail IS 'Lịch sử quét sách với thông tin chi tiết';

-- ============================================
-- DONE!
-- ============================================

SELECT 'scan_logs table created successfully!' as message;
