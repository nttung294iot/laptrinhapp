-- ============================================
-- Thêm cột barcode vào bảng books
-- ============================================

-- Thêm cột barcode (nếu chưa có)
ALTER TABLE books 
ADD COLUMN IF NOT EXISTS barcode VARCHAR(50) UNIQUE;

-- Index để tìm kiếm nhanh
CREATE INDEX IF NOT EXISTS idx_books_barcode ON books(barcode);

-- Update sách với ISBN có sẵn (dùng ISBN làm barcode)
UPDATE books SET barcode = isbn WHERE isbn IS NOT NULL AND isbn != '';

-- Hoặc update từng sách cụ thể
UPDATE books SET barcode = '978-604-1-00001-1' WHERE book_code = 'PTIT001';
UPDATE books SET barcode = '978-604-1-00002-2' WHERE book_code = 'PTIT002';
UPDATE books SET barcode = '978-604-1-00003-3' WHERE book_code = 'PTIT003';
UPDATE books SET barcode = '978-604-1-00004-4' WHERE book_code = 'PTIT004';
UPDATE books SET barcode = '978-604-1-00005-5' WHERE book_code = 'PTIT005';

-- Kiểm tra
SELECT book_code, title, author, isbn, barcode FROM books WHERE barcode IS NOT NULL;

COMMENT ON COLUMN books.barcode IS 'Mã barcode của sách (ISBN hoặc mã tự định nghĩa)';
