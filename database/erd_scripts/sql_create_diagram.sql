-- ============================================
-- SQL Script để tạo ERD trong các công cụ
-- ============================================
-- Sử dụng với:
-- 1. pgAdmin (PostgreSQL) - Built-in ERD tool
-- 2. DBeaver - ERD Diagram
-- 3. MySQL Workbench
-- 4. DataGrip
-- ============================================

-- Chỉ cần import database schema này vào tool
-- Sau đó sử dụng chức năng "Generate ERD" hoặc "Database Diagram"

-- ============================================
-- METADATA cho ERD Tools
-- ============================================

-- Thêm comments cho tables (hiển thị trong ERD)
COMMENT ON TABLE books IS 'Quản lý sách trong thư viện';
COMMENT ON TABLE readers IS 'Quản lý độc giả';
COMMENT ON TABLE borrow_cards IS 'Phiếu mượn sách';
COMMENT ON TABLE users IS 'Người dùng hệ thống (Authentication)';
COMMENT ON TABLE password_reset_tokens IS 'Token reset mật khẩu';
COMMENT ON TABLE login_history IS 'Lịch sử đăng nhập';
COMMENT ON TABLE iot_scan_logs IS 'Log quét thẻ RFID';

-- Thêm comments cho columns quan trọng
COMMENT ON COLUMN books.barcode IS 'Mã barcode để quét (ISBN hoặc custom)';
COMMENT ON COLUMN books.available_copies IS 'Số lượng sách còn có thể mượn';
COMMENT ON COLUMN readers.rfid_card_uid IS 'UID của thẻ RFID (unique)';
COMMENT ON COLUMN readers.student_id IS 'Mã sinh viên (unique)';
COMMENT ON COLUMN borrow_cards.status IS 'Trạng thái: borrowed/returned/overdue';
COMMENT ON COLUMN borrow_cards.borrower_student_id IS 'Soft reference to readers.student_id';
COMMENT ON COLUMN borrow_cards.book_code IS 'Soft reference to books.book_code';
COMMENT ON COLUMN users.role IS 'Vai trò: admin/librarian/user';
COMMENT ON COLUMN iot_scan_logs.scan_result IS 'Kết quả quét: success/error/not_found';

-- ============================================
-- QUERY để xuất metadata cho ERD tools
-- ============================================

-- 1. Lấy danh sách tất cả tables và columns
SELECT 
    t.table_name,
    c.column_name,
    c.data_type,
    c.character_maximum_length,
    c.is_nullable,
    c.column_default,
    pgd.description as column_comment
FROM information_schema.tables t
JOIN information_schema.columns c 
    ON t.table_name = c.table_name
LEFT JOIN pg_catalog.pg_statio_all_tables st 
    ON st.relname = c.table_name
LEFT JOIN pg_catalog.pg_description pgd 
    ON pgd.objoid = st.relid 
    AND pgd.objsubid = c.ordinal_position
WHERE t.table_schema = 'public'
    AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name, c.ordinal_position;

-- 2. Lấy danh sách Primary Keys
SELECT
    tc.table_name,
    kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'PRIMARY KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- 3. Lấy danh sách Foreign Keys
SELECT
    tc.table_name as from_table,
    kcu.column_name as from_column,
    ccu.table_name as to_table,
    ccu.column_name as to_column,
    tc.constraint_name,
    rc.delete_rule,
    rc.update_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- 4. Lấy danh sách Unique Constraints
SELECT
    tc.table_name,
    kcu.column_name,
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- 5. Lấy danh sách Indexes
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- ============================================
-- EXPORT cho các công cụ cụ thể
-- ============================================

-- Cho dbdiagram.io (DBML format)
-- Đã tạo file: dbdiagram_io.dbml

-- Cho Mermaid (Markdown)
-- Đã tạo file: mermaid_erd.md

-- Cho PlantUML
-- Đã tạo file: plantuml_erd.puml

-- ============================================
-- Hướng dẫn sử dụng với các tools
-- ============================================

/*
1. pgAdmin (PostgreSQL):
   - Kết nối database
   - Right click database -> Generate ERD
   - Chọn tables cần vẽ
   - Auto generate diagram

2. DBeaver:
   - Kết nối database
   - Right click database -> View Diagram
   - Hoặc: Database Navigator -> ER Diagram

3. MySQL Workbench:
   - Database -> Reverse Engineer
   - Chọn connection và schema
   - Auto generate ERD

4. DataGrip (JetBrains):
   - Right click database -> Diagrams -> Show Visualization
   - Chọn tables
   - Auto layout

5. dbdiagram.io (Online):
   - Vào https://dbdiagram.io/
   - Import file: dbdiagram_io.dbml
   - Hoặc paste code vào editor

6. draw.io / diagrams.net:
   - Vào https://app.diagrams.net/
   - Arrange -> Insert -> Advanced -> SQL
   - Paste schema SQL
   - Auto generate

7. Mermaid (GitHub/GitLab):
   - Copy code từ mermaid_erd.md
   - Paste vào file .md
   - Push lên GitHub/GitLab
   - Auto render

8. PlantUML:
   - Cài VS Code extension: PlantUML
   - Mở file: plantuml_erd.puml
   - Alt+D để preview
   - Export PNG/SVG
*/

-- ============================================
-- SOFT REFERENCES (Không có FK constraint)
-- ============================================

/*
Lưu ý: Các mối quan hệ sau là SOFT REFERENCES (không có FK):

1. borrow_cards.borrower_student_id -> readers.student_id
   - Lý do: Linh hoạt, có thể mượn sách mà chưa có trong hệ thống

2. borrow_cards.book_code -> books.book_code
   - Lý do: Linh hoạt, có thể ghi nhận mượn sách chưa có trong DB

Khi vẽ ERD:
- Dùng đường nét đứt (dashed line) cho soft references
- Dùng đường nét liền (solid line) cho FK constraints
*/

-- ============================================
-- CARDINALITY (Bản số)
-- ============================================

/*
Mối quan hệ trong database:

1. users (1) -> password_reset_tokens (N)
   - 1 user có thể có nhiều token reset

2. users (1) -> login_history (N)
   - 1 user có nhiều lần đăng nhập

3. readers (1) -> iot_scan_logs (N)
   - 1 độc giả có nhiều lần quét thẻ

4. readers (1) ..> borrow_cards (N) [SOFT]
   - 1 độc giả mượn nhiều lần

5. books (1) ..> borrow_cards (N) [SOFT]
   - 1 sách được mượn nhiều lần
*/
