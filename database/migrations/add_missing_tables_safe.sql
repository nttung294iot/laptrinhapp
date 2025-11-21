-- =====================================================
-- Migration: Thêm các bảng còn thiếu (SAFE cho database có data)
-- Mục đích: Thêm scan_logs và notifications nếu chưa có
-- An toàn: Không ảnh hưởng data hiện tại
-- =====================================================

-- =====================================================
-- 1. Kiểm tra và tạo bảng scan_logs (nếu chưa có)
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'scan_logs') THEN
        CREATE TABLE scan_logs (
            id SERIAL PRIMARY KEY,
            reader_id INTEGER,
            book_id INTEGER,
            student_id VARCHAR(50),
            barcode VARCHAR(50),
            scan_type VARCHAR(20),
            device_info VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- Indexes
        CREATE INDEX idx_scan_logs_reader_id ON scan_logs(reader_id);
        CREATE INDEX idx_scan_logs_book_id ON scan_logs(book_id);
        CREATE INDEX idx_scan_logs_student_id ON scan_logs(student_id);
        CREATE INDEX idx_scan_logs_scan_type ON scan_logs(scan_type);
        CREATE INDEX idx_scan_logs_created_at ON scan_logs(created_at DESC);

        -- Comments
        COMMENT ON TABLE scan_logs IS 'Log quét barcode sách (từ ESP32-CAM)';
        COMMENT ON COLUMN scan_logs.scan_type IS 'Loại quét: rfid/barcode/manual';
        COMMENT ON COLUMN scan_logs.device_info IS 'Thiết bị: ESP32-CAM/ESP32-S3/App';

        RAISE NOTICE 'Table scan_logs created successfully';
    ELSE
        RAISE NOTICE 'Table scan_logs already exists, skipping...';
    END IF;
END $$;

-- =====================================================
-- 2. Kiểm tra và tạo bảng notifications (nếu chưa có)
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
        CREATE TABLE notifications (
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

        -- Indexes
        CREATE INDEX idx_notifications_user_id ON notifications(user_id);
        CREATE INDEX idx_notifications_reader_id ON notifications(reader_id);
        CREATE INDEX idx_notifications_borrow_card_id ON notifications(borrow_card_id);
        CREATE INDEX idx_notifications_type ON notifications(type);
        CREATE INDEX idx_notifications_is_read ON notifications(is_read);
        CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);

        -- Comments
        COMMENT ON TABLE notifications IS 'Bảng thông báo (quá hạn, nhắc nhở, etc.)';
        COMMENT ON COLUMN notifications.type IS 'Loại: overdue/reminder/approved/returned';

        RAISE NOTICE 'Table notifications created successfully';
    ELSE
        RAISE NOTICE 'Table notifications already exists, skipping...';
    END IF;
END $$;

-- =====================================================
-- 3. Thêm columns mới vào borrow_cards (nếu chưa có)
-- =====================================================

-- Thêm reader_id
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'borrow_cards' AND column_name = 'reader_id'
    ) THEN
        ALTER TABLE borrow_cards ADD COLUMN reader_id INTEGER;
        CREATE INDEX idx_borrow_cards_reader_id ON borrow_cards(reader_id);
        COMMENT ON COLUMN borrow_cards.reader_id IS 'FK: Độc giả mượn sách';
        RAISE NOTICE 'Column reader_id added to borrow_cards';
    ELSE
        RAISE NOTICE 'Column reader_id already exists in borrow_cards';
    END IF;
END $$;

-- Thêm book_id
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'borrow_cards' AND column_name = 'book_id'
    ) THEN
        ALTER TABLE borrow_cards ADD COLUMN book_id INTEGER;
        CREATE INDEX idx_borrow_cards_book_id ON borrow_cards(book_id);
        COMMENT ON COLUMN borrow_cards.book_id IS 'FK: Sách được mượn';
        RAISE NOTICE 'Column book_id added to borrow_cards';
    ELSE
        RAISE NOTICE 'Column book_id already exists in borrow_cards';
    END IF;
END $$;

-- Thêm created_by_user_id
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'borrow_cards' AND column_name = 'created_by_user_id'
    ) THEN
        ALTER TABLE borrow_cards ADD COLUMN created_by_user_id INTEGER;
        CREATE INDEX idx_borrow_cards_created_by ON borrow_cards(created_by_user_id);
        COMMENT ON COLUMN borrow_cards.created_by_user_id IS 'FK: User tạo phiếu mượn';
        RAISE NOTICE 'Column created_by_user_id added to borrow_cards';
    ELSE
        RAISE NOTICE 'Column created_by_user_id already exists in borrow_cards';
    END IF;
END $$;

-- Thêm approved_by_user_id
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'borrow_cards' AND column_name = 'approved_by_user_id'
    ) THEN
        ALTER TABLE borrow_cards ADD COLUMN approved_by_user_id INTEGER;
        COMMENT ON COLUMN borrow_cards.approved_by_user_id IS 'FK: User duyệt phiếu';
        RAISE NOTICE 'Column approved_by_user_id added to borrow_cards';
    ELSE
        RAISE NOTICE 'Column approved_by_user_id already exists in borrow_cards';
    END IF;
END $$;

-- Thêm returned_by_user_id
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'borrow_cards' AND column_name = 'returned_by_user_id'
    ) THEN
        ALTER TABLE borrow_cards ADD COLUMN returned_by_user_id INTEGER;
        COMMENT ON COLUMN borrow_cards.returned_by_user_id IS 'FK: User xác nhận trả sách';
        RAISE NOTICE 'Column returned_by_user_id added to borrow_cards';
    ELSE
        RAISE NOTICE 'Column returned_by_user_id already exists in borrow_cards';
    END IF;
END $$;

-- =====================================================
-- 4. Thêm columns mới vào scan_logs (nếu bảng đã tồn tại)
-- =====================================================

-- Thêm reader_id vào scan_logs
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'scan_logs') THEN
        IF NOT EXISTS (
            SELECT FROM information_schema.columns 
            WHERE table_name = 'scan_logs' AND column_name = 'reader_id'
        ) THEN
            ALTER TABLE scan_logs ADD COLUMN reader_id INTEGER;
            CREATE INDEX idx_scan_logs_reader_id ON scan_logs(reader_id);
            RAISE NOTICE 'Column reader_id added to scan_logs';
        END IF;

        IF NOT EXISTS (
            SELECT FROM information_schema.columns 
            WHERE table_name = 'scan_logs' AND column_name = 'scan_type'
        ) THEN
            ALTER TABLE scan_logs ADD COLUMN scan_type VARCHAR(20);
            CREATE INDEX idx_scan_logs_scan_type ON scan_logs(scan_type);
            RAISE NOTICE 'Column scan_type added to scan_logs';
        END IF;

        IF NOT EXISTS (
            SELECT FROM information_schema.columns 
            WHERE table_name = 'scan_logs' AND column_name = 'device_info'
        ) THEN
            ALTER TABLE scan_logs ADD COLUMN device_info VARCHAR(100);
            RAISE NOTICE 'Column device_info added to scan_logs';
        END IF;
    END IF;
END $$;

-- =====================================================
-- 5. Migrate data (nếu cần)
-- =====================================================

-- Populate reader_id từ borrower_student_id
DO $$ 
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'borrow_cards' AND column_name = 'reader_id'
    ) THEN
        UPDATE borrow_cards bc
        SET reader_id = r.id
        FROM readers r
        WHERE bc.borrower_student_id = r.student_id
          AND bc.reader_id IS NULL;
        
        RAISE NOTICE 'Migrated reader_id data in borrow_cards';
    END IF;
END $$;

-- Populate book_id từ book_code
DO $$ 
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'borrow_cards' AND column_name = 'book_id'
    ) THEN
        UPDATE borrow_cards bc
        SET book_id = b.id
        FROM books b
        WHERE bc.book_code = b.book_code
          AND bc.book_id IS NULL;
        
        RAISE NOTICE 'Migrated book_id data in borrow_cards';
    END IF;
END $$;

-- =====================================================
-- 6. Tạo Foreign Keys (Optional - Uncomment nếu muốn)
-- =====================================================

/*
-- Borrow cards relationships
ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_reader
FOREIGN KEY (reader_id) REFERENCES readers(id)
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_book
FOREIGN KEY (book_id) REFERENCES books(id)
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_created_by
FOREIGN KEY (created_by_user_id) REFERENCES users(id)
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_approved_by
FOREIGN KEY (approved_by_user_id) REFERENCES users(id)
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE borrow_cards
ADD CONSTRAINT fk_borrow_cards_returned_by
FOREIGN KEY (returned_by_user_id) REFERENCES users(id)
ON DELETE SET NULL ON UPDATE CASCADE;

-- Scan logs relationships
ALTER TABLE scan_logs
ADD CONSTRAINT fk_scan_logs_reader
FOREIGN KEY (reader_id) REFERENCES readers(id)
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE scan_logs
ADD CONSTRAINT fk_scan_logs_book
FOREIGN KEY (book_id) REFERENCES books(id)
ON DELETE CASCADE ON UPDATE CASCADE;

-- Notifications relationships
ALTER TABLE notifications
ADD CONSTRAINT fk_notifications_user
FOREIGN KEY (user_id) REFERENCES users(id)
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE notifications
ADD CONSTRAINT fk_notifications_reader
FOREIGN KEY (reader_id) REFERENCES readers(id)
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE notifications
ADD CONSTRAINT fk_notifications_borrow_card
FOREIGN KEY (borrow_card_id) REFERENCES borrow_cards(id)
ON DELETE CASCADE ON UPDATE CASCADE;
*/

-- =====================================================
-- DONE!
-- =====================================================

-- Kiểm tra kết quả
SELECT 
    'Migration completed!' as status,
    COUNT(*) as total_tables
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE';

-- Hiển thị danh sách tables
SELECT 
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as columns
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_type = 'BASE TABLE'
ORDER BY table_name;
