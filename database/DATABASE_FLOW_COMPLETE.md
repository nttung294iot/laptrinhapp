# 🔄 Database Flow - Hoàn chỉnh

## Tổng quan

Database hiện có **9 bảng** với **15 Foreign Key relationships** kết nối đầy đủ theo flow nghiệp vụ.

---

## 📊 Sơ đồ Flow hoàn chỉnh

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE SYSTEM FLOW                             │
└─────────────────────────────────────────────────────────────────────────┘

STEP 1: USER LOGIN
┌──────────────┐
│    users     │
│  ──────────  │
│  id (PK)     │──┐
│  username    │  │
│  role        │  │
└──────────────┘  │
                  │ 1
                  │
                  │ N
                  ▼
        ┌──────────────────┐
        │  login_history   │
        │  ──────────────  │
        │  user_id (FK)    │
        │  login_time      │
        │  ip_address      │
        └──────────────────┘

═══════════════════════════════════════════════════════════════════════════

STEP 2: IOT SCANNING (ESP32 + ESP32-CAM)

┌──────────────────┐                    ┌──────────────────┐
│    readers       │                    │      books       │
│  ──────────────  │                    │  ──────────────  │
│  id (PK)         │                    │  id (PK)         │
│  student_id (UK) │                    │  book_code (UK)  │
│  rfid_card_uid   │                    │  barcode (UK)    │
└──────────────────┘                    └──────────────────┘
        │ 1                                      │ 1
        │                                        │
        ├────────────────┬───────────────────────┤
        │ N              │ N                     │ N
        ▼                ▼                       ▼
┌──────────────────┐  ┌──────────────────┐
│ iot_scan_logs    │  │   scan_logs      │
│  ──────────────  │  │  ──────────────  │
│  reader_id (FK)  │  │  reader_id (FK)  │
│  card_uid        │  │  book_id (FK)    │
│  scan_result     │  │  scan_type       │
│  scanned_at      │  │  device_info     │
└──────────────────┘  └──────────────────┘
   ESP32 RFID            ESP32-CAM Barcode

═══════════════════════════════════════════════════════════════════════════

STEP 3: CREATE BORROW CARD (Junction Table)

┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│    readers       │          │  borrow_cards    │          │      books       │
│  ──────────────  │          │  ──────────────  │          │  ──────────────  │
│  id (PK)         │──────────│  reader_id (FK)  │          │  id (PK)         │
│  student_id      │     1:N  │  book_id (FK)    │──────────│  book_code       │
│  name            │          │  borrow_date     │     N:1  │  title           │
└──────────────────┘          │  status          │          │  available_copies│
                              │                  │          └──────────────────┘
                              │  Audit Trail:    │
┌──────────────────┐          │  ──────────────  │
│     users        │          │  created_by (FK) │──┐
│  ──────────────  │          │  approved_by(FK) │──┼───────┐
│  id (PK)         │──────────│  returned_by(FK) │──┘       │
│  username        │     N:1  └──────────────────┘          │
│  role            │                  │ 1                    │
└──────────────────┘                  │                      │
        │                             │ N                    │
        │                             ▼                      │
        │                   ┌──────────────────┐            │
        │                   │  notifications   │            │
        │                   │  ──────────────  │            │
        └───────────────────│  user_id (FK)    │            │
                       ┌────│  reader_id (FK)  │            │
                       │    │  borrow_card(FK) │────────────┘
                       │    │  type            │
                       │    │  is_read         │
                       │    └──────────────────┘
                       │
                       │
        ┌──────────────┴──────────────┐
        │                             │
        ▼                             ▼
┌──────────────────┐          ┌──────────────────┐
│    readers       │          │  borrow_cards    │
│  (notification)  │          │  (notification)  │
└──────────────────┘          └──────────────────┘

═══════════════════════════════════════════════════════════════════════════

STEP 4: RETURN BOOK

┌──────────────────┐
│  borrow_cards    │
│  ──────────────  │
│  status          │ ← Update: 'borrowed' → 'returned'
│  actual_return   │ ← Set date
│  returned_by(FK) │ ← Set user_id
└──────────────────┘
        │
        ▼
┌──────────────────┐
│      books       │
│  ──────────────  │
│  available_copies│ ← Increment +1
└──────────────────┘
        │
        ▼
┌──────────────────┐
│  notifications   │
│  ──────────────  │
│  type: returned  │ ← Create notification
└──────────────────┘
```

---

## 🔗 Foreign Key Relationships (15 FKs)

### Authentication Module (2 FKs)

| From Table | Column | To Table | Column | Cardinality |
|------------|--------|----------|--------|-------------|
| password_reset_tokens | user_id | users | id | N:1 |
| login_history | user_id | users | id | N:1 |

### Library Core Module (5 FKs)

| From Table | Column | To Table | Column | Cardinality |
|------------|--------|----------|--------|-------------|
| borrow_cards | reader_id | readers | id | N:1 |
| borrow_cards | book_id | books | id | N:1 |
| borrow_cards | created_by_user_id | users | id | N:1 |
| borrow_cards | approved_by_user_id | users | id | N:1 |
| borrow_cards | returned_by_user_id | users | id | N:1 |

### IoT Scanning Module (3 FKs)

| From Table | Column | To Table | Column | Cardinality |
|------------|--------|----------|--------|-------------|
| iot_scan_logs | reader_id | readers | id | N:1 |
| scan_logs | reader_id | readers | id | N:1 |
| scan_logs | book_id | books | id | N:1 |

### Notification Module (3 FKs)

| From Table | Column | To Table | Column | Cardinality |
|------------|--------|----------|--------|-------------|
| notifications | user_id | users | id | N:1 |
| notifications | reader_id | readers | id | N:1 |
| notifications | borrow_card_id | borrow_cards | id | N:1 |

### Password Reset (2 FKs - already counted above)

---

## 📝 Complete Flow Steps

### 1. User Login Flow

```sql
-- 1.1. User đăng nhập
SELECT * FROM users 
WHERE username = 'librarian' AND is_active = true;

-- 1.2. Log đăng nhập
INSERT INTO login_history (user_id, login_time, ip_address, success)
VALUES (1, NOW(), '192.168.1.100', true);

-- 1.3. Update last_login
UPDATE users SET last_login = NOW() WHERE id = 1;
```

**Relationships:**
- `login_history.user_id` → `users.id`

---

### 2. IoT Scanning Flow

#### 2.1. RFID Scan (ESP32)

```sql
-- ESP32 quét thẻ RFID
INSERT INTO iot_scan_logs (card_uid, reader_id, reader_name, scan_result)
SELECT 
    'A1B2C3D4',
    r.id,
    r.name,
    'success'
FROM readers r
WHERE r.rfid_card_uid = 'A1B2C3D4';

-- Tìm reader
SELECT * FROM readers WHERE rfid_card_uid = 'A1B2C3D4';
```

**Relationships:**
- `iot_scan_logs.reader_id` → `readers.id`

#### 2.2. Barcode Scan (ESP32-CAM)

```sql
-- ESP32-CAM quét barcode sách
INSERT INTO scan_logs (reader_id, book_id, barcode, scan_type, device_info)
SELECT 
    r.id,
    b.id,
    '978-604-1-00001-1',
    'barcode',
    'ESP32-CAM'
FROM readers r, books b
WHERE r.student_id = 'SV001'
  AND b.barcode = '978-604-1-00001-1';

-- Tìm sách
SELECT * FROM books WHERE barcode = '978-604-1-00001-1';
```

**Relationships:**
- `scan_logs.reader_id` → `readers.id`
- `scan_logs.book_id` → `books.id`

---

### 3. Create Borrow Card Flow

```sql
-- 3.1. Tạo phiếu mượn (sử dụng function)
SELECT create_borrow_card(
    p_reader_id := 1,              -- readers.id
    p_book_id := 1,                -- books.id
    p_created_by_user_id := 1,     -- users.id (librarian)
    p_borrow_date := CURRENT_DATE,
    p_expected_return_date := CURRENT_DATE + INTERVAL '14 days'
);

-- Function sẽ:
-- 1. Validate reader exists
-- 2. Validate book exists và available
-- 3. Create borrow_card với đầy đủ thông tin
-- 4. Update books.available_copies -= 1
-- 5. Return borrow_card_id
```

**Relationships:**
- `borrow_cards.reader_id` → `readers.id`
- `borrow_cards.book_id` → `books.id`
- `borrow_cards.created_by_user_id` → `users.id`

**Denormalization:**
- Lưu snapshot: `borrower_name`, `borrower_student_id`, `book_name`, `book_code`
- Lý do: Giữ thông tin tại thời điểm mượn, không bị ảnh hưởng khi update readers/books

---

### 4. Approve Borrow Card Flow (Optional)

```sql
-- 4.1. Admin/Librarian duyệt phiếu mượn
UPDATE borrow_cards
SET approved_by_user_id = 2,  -- users.id (admin)
    updated_at = NOW()
WHERE id = 1;

-- 4.2. Tạo notification cho reader
INSERT INTO notifications (user_id, reader_id, borrow_card_id, type, title, message)
SELECT 
    bc.created_by_user_id,
    bc.reader_id,
    bc.id,
    'approved',
    'Phiếu mượn đã được duyệt',
    CONCAT('Phiếu mượn sách "', bc.book_name, '" đã được duyệt')
FROM borrow_cards bc
WHERE bc.id = 1;
```

**Relationships:**
- `borrow_cards.approved_by_user_id` → `users.id`
- `notifications.user_id` → `users.id`
- `notifications.reader_id` → `readers.id`
- `notifications.borrow_card_id` → `borrow_cards.id`

---

### 5. Return Book Flow

```sql
-- 5.1. Trả sách (sử dụng function)
SELECT return_book(
    p_borrow_card_id := 1,
    p_returned_by_user_id := 1,  -- users.id (librarian)
    p_actual_return_date := CURRENT_DATE
);

-- Function sẽ:
-- 1. Update borrow_cards.status = 'returned'
-- 2. Set actual_return_date
-- 3. Set returned_by_user_id
-- 4. Update books.available_copies += 1

-- 5.2. Tạo notification
INSERT INTO notifications (user_id, reader_id, borrow_card_id, type, title, message)
SELECT 
    bc.created_by_user_id,
    bc.reader_id,
    bc.id,
    'returned',
    'Sách đã được trả',
    CONCAT('Sách "', bc.book_name, '" đã được trả thành công')
FROM borrow_cards bc
WHERE bc.id = 1;
```

**Relationships:**
- `borrow_cards.returned_by_user_id` → `users.id`
- `notifications` → `users`, `readers`, `borrow_cards`

---

### 6. Overdue Notification Flow

```sql
-- 6.1. Tự động tạo notification cho phiếu quá hạn (chạy daily)
SELECT notify_overdue_borrow_cards();

-- Function sẽ:
-- 1. Tìm tất cả borrow_cards quá hạn
-- 2. Tạo notifications cho user và reader
-- 3. Gửi email/push notification (nếu có)
```

**Relationships:**
- `notifications.user_id` → `users.id` (librarian)
- `notifications.reader_id` → `readers.id` (người mượn)
- `notifications.borrow_card_id` → `borrow_cards.id`

---

## 🎯 Junction Tables

### borrow_cards (Main Junction Table)

**Kết nối:**
- `readers` ↔ `books` (Many-to-Many)
- `users` → `borrow_cards` (Audit trail)

**Đặc điểm:**
- Có business logic (status, dates)
- Có audit trail (created_by, approved_by, returned_by)
- Có denormalization (snapshot data)
- Có thể tồn tại độc lập

**Không phải pure junction table vì:**
- Có nhiều columns bổ sung
- Có relationships với nhiều tables khác
- Có business rules phức tạp

---

## 📊 Statistics & Reporting

### Reader Statistics

```sql
SELECT * FROM v_reader_stats_full
WHERE student_id = 'SV001';

-- Kết quả:
-- - total_borrows: Tổng số lần mượn
-- - current_borrows: Đang mượn
-- - overdue_borrows: Quá hạn
-- - rfid_scans: Số lần quét RFID
-- - barcode_scans: Số lần quét barcode
-- - last_borrow_date: Lần mượn gần nhất
```

### Book Statistics

```sql
SELECT * FROM v_book_stats_full
WHERE book_code = 'BK001';

-- Kết quả:
-- - total_borrows: Tổng số lần được mượn
-- - current_borrows: Đang được mượn
-- - total_scans: Số lần được quét
-- - last_borrow_date: Lần mượn gần nhất
```

### User Activity

```sql
-- Xem hoạt động của user
SELECT 
    u.username,
    COUNT(DISTINCT bc_created.id) as cards_created,
    COUNT(DISTINCT bc_approved.id) as cards_approved,
    COUNT(DISTINCT bc_returned.id) as cards_returned,
    COUNT(DISTINCT lh.id) as login_count
FROM users u
LEFT JOIN borrow_cards bc_created ON u.id = bc_created.created_by_user_id
LEFT JOIN borrow_cards bc_approved ON u.id = bc_approved.approved_by_user_id
LEFT JOIN borrow_cards bc_returned ON u.id = bc_returned.returned_by_user_id
LEFT JOIN login_history lh ON u.id = lh.user_id
WHERE u.id = 1
GROUP BY u.id, u.username;
```

---

## 🔒 Data Integrity

### Cascade Rules

| FK | Delete Rule | Update Rule | Lý do |
|----|-------------|-------------|-------|
| password_reset_tokens.user_id | CASCADE | CASCADE | Token không có ý nghĩa nếu user bị xóa |
| login_history.user_id | CASCADE | CASCADE | History không cần nếu user bị xóa |
| borrow_cards.reader_id | SET NULL | CASCADE | Giữ lại phiếu mượn, SET NULL reader |
| borrow_cards.book_id | SET NULL | CASCADE | Giữ lại phiếu mượn, SET NULL book |
| borrow_cards.*_user_id | SET NULL | CASCADE | Giữ lại phiếu mượn, SET NULL user |
| iot_scan_logs.reader_id | SET NULL | CASCADE | Giữ lại log, SET NULL reader |
| scan_logs.reader_id | SET NULL | CASCADE | Giữ lại log, SET NULL reader |
| scan_logs.book_id | CASCADE | CASCADE | Xóa log nếu book bị xóa |
| notifications.* | CASCADE | CASCADE | Xóa notification nếu parent bị xóa |

---

## 💡 Best Practices

### 1. Luôn dùng Functions cho Business Logic

```sql
-- ✅ GOOD: Dùng function
SELECT create_borrow_card(...);

-- ❌ BAD: Insert trực tiếp
INSERT INTO borrow_cards (...) VALUES (...);
```

**Lý do:**
- Đảm bảo data integrity
- Centralized business logic
- Dễ maintain và test

### 2. Denormalization cho Performance

```sql
-- Lưu snapshot trong borrow_cards:
borrower_name, borrower_student_id, book_name, book_code

-- Thay vì JOIN mỗi lần query
```

**Trade-off:**
- ✅ Performance tốt hơn
- ✅ Giữ thông tin tại thời điểm mượn
- ❌ Dữ liệu có thể không đồng bộ

### 3. Audit Trail cho Compliance

```sql
-- Luôn track ai làm gì:
created_by_user_id
approved_by_user_id
returned_by_user_id
```

**Lợi ích:**
- Security audit
- Compliance (ISO, GDPR)
- Debugging và troubleshooting

---

## 🚀 Performance Optimization

### Indexes

```sql
-- Tất cả FK columns đều có index
-- Tất cả columns thường dùng trong WHERE đều có index
-- Composite indexes cho queries phức tạp

CREATE INDEX idx_borrow_cards_reader_book 
ON borrow_cards(reader_id, book_id);

CREATE INDEX idx_borrow_cards_status_date 
ON borrow_cards(status, expected_return_date);
```

### Partitioning (Future)

```sql
-- Partition borrow_cards theo năm
CREATE TABLE borrow_cards_2025 PARTITION OF borrow_cards
FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

---

**Last Updated:** 2025-01-21
