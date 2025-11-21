-- ============================================
-- Migration: Update Relationships - Complete Flow
-- Mục đích: Thêm FK đầy đủ để kết nối tất cả tables
-- ============================================

-- ============================================
-- 1. UPDATE borrow_cards - Thêm FK relationships
-- ============================================

-- Thêm columns mới
ALTER TABLE borrow_cards 
ADD COLUMN IF NOT EXISTS reader_id INTEGER,
ADD COLUMN IF NOT EXISTS book_id INTEGER,
ADD COLUMN IF NOT EXISTS created_by_user_id INTEGER,
ADD COLUMN IF NOT EXISTS approved_by_user_id INTEGER,
ADD COLUMN IF NOT EXISTS returned_by_user_id INTEGER;

-- Migrate dữ liệu cũ sang columns mới
UPDATE borrow_cards bc
SET reader_id = r.id
FROM readers r
WHERE bc.borrower_student_id = r.student_id
  AND bc.reader_id IS NULL;

UPDATE borrow_cards bc
SET book_id = b.id
FROM books b
WHERE bc.book_code = b.book_code
  AND bc.book_id IS NULL;

-- Thêm Foreign Keys
ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_reader
FOREIGN KEY (reader_id) REFERENCES readers(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_book
FOREIGN KEY (book_id) REFERENCES books(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_created_by
FOREIGN KEY (created_by_user_id) REFERENCES users(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_approved_by
FOREIGN KEY (approved_by_user_id) REFERENCES users(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_returned_by
FOREIGN KEY (returned_by_user_id) REFERENCES users(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_borrow_cards_reader_id ON borrow_cards(reader_id);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_book_id ON borrow_cards(book_id);
CREATE INDEX IF NOT EXISTS idx_borrow_cards_created_by ON borrow_cards(created_by_user_id);

-- Comments
COMMENT ON COLUMN borrow_cards.reader_id IS 'FK: Độc giả mượn sách';
COMMENT ON COLUMN borrow_cards.book_id IS 'FK: Sách được mượn';
COMMENT ON COLUMN borrow_cards.created_by_user_id IS 'FK: User tạo phiếu mượn';
COMMENT ON COLUMN borrow_cards.approved_by_user_id IS 'FK: User duyệt phiếu';
COMMENT ON COLUMN borrow_cards.returned_by_user_id IS 'FK: User xác nhận trả sách';

-- ============================================
-- 2. UPDATE scan_logs - Thêm FK và fields
-- ============================================

-- Thêm columns mới
ALTER TABLE scan_logs
ADD COLUMN IF NOT EXISTS reader_id INTEGER,
ADD COLUMN IF NOT EXISTS scan_type VARCHAR(20) DEFAULT 'barcode',
ADD COLUMN IF NOT EXISTS device_info VARCHAR(100);

-- Migrate dữ liệu cũ
UPDATE scan_logs sl
SET reader_id = r.id
FROM readers r
WHERE sl.student_id = r.student_id
  AND sl.reader_id IS NULL;

-- Thêm Foreign Key
ALTER TABLE scan_logs
ADD CONSTRAINT fk_scan_logs_reader
FOREIGN KEY (reader_id) REFERENCES readers(id)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Index
CREATE INDEX IF NOT EXISTS idx_scan_logs_reader_id ON scan_logs(reader_id);
CREATE INDEX IF NOT EXISTS idx_scan_logs_scan_type ON scan_logs(scan_type);

-- Comments
COMMENT ON COLUMN scan_logs.reader_id IS 'FK: Người quét sách';
COMMENT ON COLUMN scan_logs.scan_type IS 'Loại quét: rfid/barcode/manual';
COMMENT ON COLUMN scan_logs.device_info IS 'Thiết bị: ESP32-CAM/ESP32-S3/App';

-- ============================================
-- 3. CREATE notifications table
-- ============================================

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    reader_id INTEGER REFERENCES readers(id) ON DELETE CASCADE,
    borrow_card_id INTEGER REFERENCES borrow_cards(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_reader_id ON notifications(reader_id);
CREATE INDEX IF NOT EXISTS idx_notifications_borrow_card_id ON notifications(borrow_card_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_sent_at ON notifications(sent_at DESC);

-- Comments
COMMENT ON TABLE notifications IS 'Bảng thông báo (quá hạn, nhắc nhở, etc.)';
COMMENT ON COLUMN notifications.type IS 'Loại: overdue/reminder/approved/returned';

-- ============================================
-- 4. CREATE VIEWS - Với relationships đầy đủ
-- ============================================

-- View: Borrow cards với thông tin đầy đủ
CREATE OR REPLACE VIEW v_borrow_cards_full AS
SELECT 
    bc.id,
    bc.borrow_date,
    bc.expected_return_date,
    bc.actual_return_date,
    bc.status,
    -- Reader info
    r.id as reader_id,
    r.name as reader_name,
    r.student_id,
    r.class as reader_class,
    r.phone as reader_phone,
    r.email as reader_email,
    -- Book info
    b.id as book_id,
    b.book_code,
    b.title as book_title,
    b.author as book_author,
    b.category as book_category,
    b.available_copies,
    -- User audit trail
    u_created.username as created_by,
    u_approved.username as approved_by,
    u_returned.username as returned_by,
    bc.created_at,
    bc.updated_at
FROM borrow_cards bc
LEFT JOIN readers r ON bc.reader_id = r.id
LEFT JOIN books b ON bc.book_id = b.id
LEFT JOIN users u_created ON bc.created_by_user_id = u_created.id
LEFT JOIN users u_approved ON bc.approved_by_user_id = u_approved.id
LEFT JOIN users u_returned ON bc.returned_by_user_id = u_returned.id
ORDER BY bc.created_at DESC;

COMMENT ON VIEW v_borrow_cards_full IS 'Phiếu mượn với thông tin đầy đủ (reader, book, users)';

-- View: Scan logs với thông tin đầy đủ
CREATE OR REPLACE VIEW v_scan_logs_full AS
SELECT 
    sl.id,
    sl.scan_type,
    sl.device_info,
    sl.barcode,
    sl.created_at,
    -- Reader info
    r.id as reader_id,
    r.name as reader_name,
    r.student_id,
    r.class as reader_class,
    -- Book info
    b.id as book_id,
    b.book_code,
    b.title as book_title,
    b.author as book_author,
    b.barcode as book_barcode
FROM scan_logs sl
LEFT JOIN readers r ON sl.reader_id = r.id
LEFT JOIN books b ON sl.book_id = b.id
ORDER BY sl.created_at DESC;

COMMENT ON VIEW v_scan_logs_full IS 'Log quét với thông tin đầy đủ (reader, book)';

-- View: Reader statistics với relationships
CREATE OR REPLACE VIEW v_reader_stats_full AS
SELECT 
    r.id,
    r.name,
    r.student_id,
    r.class,
    r.rfid_card_uid,
    -- Borrow statistics
    COUNT(DISTINCT bc.id) as total_borrows,
    COUNT(DISTINCT CASE WHEN bc.status = 'borrowed' THEN bc.id END) as current_borrows,
    COUNT(DISTINCT CASE WHEN bc.status = 'returned' THEN bc.id END) as returned_borrows,
    COUNT(DISTINCT CASE WHEN bc.status = 'overdue' THEN bc.id END) as overdue_borrows,
    -- Scan statistics
    COUNT(DISTINCT isl.id) as rfid_scans,
    COUNT(DISTINCT sl.id) as barcode_scans,
    -- Latest activity
    MAX(bc.borrow_date) as last_borrow_date,
    MAX(isl.scanned_at) as last_rfid_scan,
    MAX(sl.created_at) as last_barcode_scan
FROM readers r
LEFT JOIN borrow_cards bc ON r.id = bc.reader_id
LEFT JOIN iot_scan_logs isl ON r.id = isl.reader_id
LEFT JOIN scan_logs sl ON r.id = sl.reader_id
GROUP BY r.id, r.name, r.student_id, r.class, r.rfid_card_uid;

COMMENT ON VIEW v_reader_stats_full IS 'Thống kê đầy đủ của độc giả (mượn sách, quét thẻ)';

-- View: Book statistics với relationships
CREATE OR REPLACE VIEW v_book_stats_full AS
SELECT 
    b.id,
    b.book_code,
    b.title,
    b.author,
    b.category,
    b.total_copies,
    b.available_copies,
    b.barcode,
    -- Borrow statistics
    COUNT(DISTINCT bc.id) as total_borrows,
    COUNT(DISTINCT CASE WHEN bc.status = 'borrowed' THEN bc.id END) as current_borrows,
    COUNT(DISTINCT CASE WHEN bc.status = 'returned' THEN bc.id END) as returned_borrows,
    -- Scan statistics
    COUNT(DISTINCT sl.id) as total_scans,
    -- Latest activity
    MAX(bc.borrow_date) as last_borrow_date,
    MAX(sl.created_at) as last_scan_date
FROM books b
LEFT JOIN borrow_cards bc ON b.id = bc.book_id
LEFT JOIN scan_logs sl ON b.id = sl.book_id
GROUP BY b.id, b.book_code, b.title, b.author, b.category, 
         b.total_copies, b.available_copies, b.barcode;

COMMENT ON VIEW v_book_stats_full IS 'Thống kê đầy đủ của sách (mượn, quét)';

-- View: Notifications chưa đọc
CREATE OR REPLACE VIEW v_unread_notifications AS
SELECT 
    n.*,
    u.username,
    u.email as user_email,
    r.name as reader_name,
    r.student_id,
    bc.book_name,
    bc.status as borrow_status
FROM notifications n
LEFT JOIN users u ON n.user_id = u.id
LEFT JOIN readers r ON n.reader_id = r.id
LEFT JOIN borrow_cards bc ON n.borrow_card_id = bc.id
WHERE n.is_read = false
ORDER BY n.sent_at DESC;

COMMENT ON VIEW v_unread_notifications IS 'Thông báo chưa đọc với thông tin đầy đủ';

-- ============================================
-- 5. FUNCTIONS - Với relationships
-- ============================================

-- Function: Tạo phiếu mượn với audit trail
CREATE OR REPLACE FUNCTION create_borrow_card(
    p_reader_id INTEGER,
    p_book_id INTEGER,
    p_created_by_user_id INTEGER,
    p_borrow_date DATE DEFAULT CURRENT_DATE,
    p_expected_return_date DATE DEFAULT CURRENT_DATE + INTERVAL '14 days'
)
RETURNS INTEGER AS $$
DECLARE
    v_borrow_card_id INTEGER;
    v_reader RECORD;
    v_book RECORD;
BEGIN
    -- Get reader info
    SELECT * INTO v_reader FROM readers WHERE id = p_reader_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reader not found: %', p_reader_id;
    END IF;
    
    -- Get book info
    SELECT * INTO v_book FROM books WHERE id = p_book_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Book not found: %', p_book_id;
    END IF;
    
    -- Check available copies
    IF v_book.available_copies <= 0 THEN
        RAISE EXCEPTION 'Book not available: %', v_book.title;
    END IF;
    
    -- Create borrow card
    INSERT INTO borrow_cards (
        reader_id,
        book_id,
        borrower_name,
        borrower_class,
        borrower_student_id,
        borrower_phone,
        borrower_email,
        book_name,
        book_code,
        borrow_date,
        expected_return_date,
        status,
        created_by_user_id
    ) VALUES (
        p_reader_id,
        p_book_id,
        v_reader.name,
        v_reader.class,
        v_reader.student_id,
        v_reader.phone,
        v_reader.email,
        v_book.title,
        v_book.book_code,
        p_borrow_date,
        p_expected_return_date,
        'borrowed',
        p_created_by_user_id
    )
    RETURNING id INTO v_borrow_card_id;
    
    -- Update available copies
    UPDATE books 
    SET available_copies = available_copies - 1
    WHERE id = p_book_id;
    
    RETURN v_borrow_card_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_borrow_card IS 'Tạo phiếu mượn với audit trail và update available_copies';

-- Function: Trả sách
CREATE OR REPLACE FUNCTION return_book(
    p_borrow_card_id INTEGER,
    p_returned_by_user_id INTEGER,
    p_actual_return_date DATE DEFAULT CURRENT_DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    v_book_id INTEGER;
BEGIN
    -- Get book_id
    SELECT book_id INTO v_book_id 
    FROM borrow_cards 
    WHERE id = p_borrow_card_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Borrow card not found: %', p_borrow_card_id;
    END IF;
    
    -- Update borrow card
    UPDATE borrow_cards
    SET status = 'returned',
        actual_return_date = p_actual_return_date,
        returned_by_user_id = p_returned_by_user_id
    WHERE id = p_borrow_card_id;
    
    -- Update available copies
    UPDATE books
    SET available_copies = available_copies + 1
    WHERE id = v_book_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION return_book IS 'Trả sách và update available_copies';

-- ============================================
-- 6. TRIGGERS - Auto create notifications
-- ============================================

-- Trigger: Tạo notification khi phiếu mượn quá hạn
CREATE OR REPLACE FUNCTION notify_overdue_borrow_cards()
RETURNS void AS $$
BEGIN
    INSERT INTO notifications (user_id, reader_id, borrow_card_id, type, title, message)
    SELECT 
        bc.created_by_user_id,
        bc.reader_id,
        bc.id,
        'overdue',
        'Phiếu mượn quá hạn',
        CONCAT('Sách "', bc.book_name, '" của ', bc.borrower_name, ' đã quá hạn ', 
               CURRENT_DATE - bc.expected_return_date, ' ngày')
    FROM borrow_cards bc
    WHERE bc.status = 'borrowed'
      AND bc.expected_return_date < CURRENT_DATE
      AND NOT EXISTS (
          SELECT 1 FROM notifications n
          WHERE n.borrow_card_id = bc.id
            AND n.type = 'overdue'
            AND n.sent_at::date = CURRENT_DATE
      );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION notify_overdue_borrow_cards IS 'Tạo notification cho phiếu mượn quá hạn';

-- ============================================
-- DONE!
-- ============================================

SELECT 'Migration completed successfully!' as message;
SELECT 'Total tables: ' || COUNT(*) as info
FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
