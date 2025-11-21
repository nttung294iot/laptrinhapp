-- ============================================
-- IoT Tables - ĐƠN GIẢN
-- Chỉ cần thêm cột RFID vào bảng readers
-- ============================================

-- 1. Thêm cột rfid_card_uid vào bảng readers
ALTER TABLE readers 
ADD COLUMN IF NOT EXISTS rfid_card_uid VARCHAR(20) UNIQUE;

-- 2. Bảng log quét thẻ (để tracking)
CREATE TABLE IF NOT EXISTS iot_scan_logs (
    id SERIAL PRIMARY KEY,
    card_uid VARCHAR(20) NOT NULL,
    reader_id INTEGER REFERENCES readers(id),
    reader_name VARCHAR(255),
    scan_result VARCHAR(20) DEFAULT 'success',
    error_message TEXT,
    scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Index
CREATE INDEX IF NOT EXISTS idx_readers_rfid_card_uid ON readers(rfid_card_uid);
CREATE INDEX IF NOT EXISTS idx_iot_scan_logs_scanned_at ON iot_scan_logs(scanned_at DESC);

-- 4. Function: Log scan event
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

-- 5. View: Lịch sử quét thẻ
CREATE OR REPLACE VIEW v_scan_history AS
SELECT 
    isl.id,
    isl.card_uid,
    isl.reader_name,
    isl.scan_result,
    isl.scanned_at
FROM iot_scan_logs isl
ORDER BY isl.scanned_at DESC;

-- ============================================
-- DONE! Đơn giản hơn nhiều rồi
-- ============================================

COMMENT ON COLUMN readers.rfid_card_uid IS 'UID của thẻ RFID (unique)';
COMMENT ON TABLE iot_scan_logs IS 'Log các lần quét thẻ RFID';
