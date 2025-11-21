# 📊 ERD Scripts - Hệ thống Quản lý Thư viện

Thư mục này chứa các script để vẽ sơ đồ ERD (Entity Relationship Diagram) cho database của hệ thống.

## 📁 Danh sách files

| File | Công cụ | Mô tả |
|------|---------|-------|
| `dbdiagram_io.dbml` | [dbdiagram.io](https://dbdiagram.io/) | **Full version** - Tất cả columns ⭐ |
| `dbdiagram_io_clean_layout.dbml` | [dbdiagram.io](https://dbdiagram.io/) | **Clean layout** - Có màu sắc, dễ nhìn ⭐⭐ **KHUYÊN DÙNG** |
| `dbdiagram_io_minimal.dbml` | [dbdiagram.io](https://dbdiagram.io/) | **Minimal** - Chỉ PK/FK, tổng quan |
| `mermaid_erd.md` | Mermaid | Dùng trong GitHub, GitLab, VS Code |
| `plantuml_erd.puml` | PlantUML | Dùng trong VS Code, IntelliJ |
| `sql_create_diagram.sql` | SQL Tools | Metadata và queries cho ERD tools |

## 📋 Tổng quan Database

### Bảng chính (8 tables)

#### 🔵 Core Tables (Nghiệp vụ)
1. **books** - Quản lý sách
2. **readers** - Quản lý độc giả
3. **borrow_cards** - Phiếu mượn sách (Junction table)

#### 🔴 Authentication Tables
4. **users** - Người dùng hệ thống
5. **password_reset_tokens** - Token reset mật khẩu
6. **login_history** - Lịch sử đăng nhập

#### 🟢 IoT Tables
7. **iot_scan_logs** - Log quét thẻ RFID (ESP32)
8. **scan_logs** - Log quét barcode sách (ESP32-CAM)

### Mối quan hệ (Relationships)

#### ✅ Foreign Keys (Strong Relationships)

```
Authentication Module:
  users (1) ──→ (N) password_reset_tokens
  users (1) ──→ (N) login_history

Library Core Module:
  readers (1) ──→ (N) borrow_cards
  books (1) ──→ (N) borrow_cards
  books (1) ──→ (N) scan_logs

IoT Module:
  readers (1) ──→ (N) iot_scan_logs
```

#### 📊 Cardinality
- Tất cả relationships đều là **1:N** (One-to-Many)
- **borrow_cards** là junction table kết nối readers và books
- Không có N:M trực tiếp (đã normalize)

---

## 🎯 Hướng dẫn sử dụng

### 1️⃣ Vẽ ERD online (⭐ Khuyên dùng - Nhanh nhất)

**Sử dụng dbdiagram.io:**

1. Vào https://dbdiagram.io/
2. Tạo project mới (hoặc login để save)
3. **Chọn file phù hợp:**
   - `dbdiagram_io_clean_layout.dbml` - **KHUYÊN DÙNG** (có màu sắc, layout rõ ràng)
   - `dbdiagram_io_minimal.dbml` - Tổng quan nhanh (chỉ PK/FK)
   - `dbdiagram_io.dbml` - Full version (tất cả columns)
4. Copy toàn bộ nội dung file đã chọn
5. Paste vào editor bên trái
6. Diagram tự động render bên phải
7. **Tùy chỉnh layout:**
   - Kéo thả các bảng để sắp xếp
   - Click "Auto Arrange" để tự động sắp xếp
   - Zoom in/out bằng scroll
8. Export PNG/PDF/SVG (nút Export ở góc trên)

**Ưu điểm:**
- ✅ Miễn phí, không cần đăng ký
- ✅ Không cần cài đặt
- ✅ Giao diện đẹp, professional
- ✅ Export nhiều format (PNG, PDF, SVG)
- ✅ Share link dễ dàng
- ✅ Tự động layout, không cần chỉnh tay

**Kết quả:**
- Sơ đồ ERD đầy đủ với tất cả 8 bảng
- Hiển thị rõ ràng Foreign Keys
- Màu sắc phân biệt module
- Có thể zoom, pan, export

---

### 2️⃣ Vẽ ERD trong GitHub/GitLab

**Sử dụng Mermaid:**

1. Copy nội dung từ `mermaid_erd.md`
2. Tạo file `.md` trong repo (ví dụ: `DATABASE_ERD.md`)
3. Paste code vào
4. Push lên GitHub/GitLab
5. Diagram tự động hiển thị khi xem file

**Ưu điểm:**
- ✅ Tích hợp sẵn trong GitHub/GitLab
- ✅ Version control (track changes)
- ✅ Không cần tool bên ngoài
- ✅ Hiển thị trong README
- ✅ Miễn phí

**Xem trực tiếp:**
- GitHub: Tự động render
- Mermaid Live Editor: https://mermaid.live/
- VS Code: Cài extension "Markdown Preview Mermaid Support"

---

### 3️⃣ Vẽ ERD trong VS Code

**Sử dụng PlantUML:**

1. Cài extension: "PlantUML" trong VS Code
2. Mở file `plantuml_erd.puml`
3. Nhấn `Alt+D` để preview
4. Right click → Export → PNG/SVG

**Cài đặt:**
```bash
# 1. Cài Java (required cho PlantUML)
# Download từ: https://www.java.com/

# 2. Cài Graphviz (optional, cho layout đẹp hơn)
# Windows: 
choco install graphviz
# hoặc download: https://graphviz.org/download/

# Mac: 
brew install graphviz

# Linux:
sudo apt-get install graphviz
```

**Ưu điểm:**
- ✅ Offline, không cần internet
- ✅ Tích hợp VS Code
- ✅ Customize dễ dàng
- ✅ Export chất lượng cao
- ✅ Có notes và annotations

---

### 4️⃣ Vẽ ERD từ Database thực

**Sử dụng pgAdmin (PostgreSQL):**

1. Kết nối database
2. Right click database → **Generate ERD**
3. Chọn tables cần vẽ (hoặc Select All)
4. Click **Generate**
5. Auto layout
6. Export image (File → Save As → PNG)

**Sử dụng DBeaver:**

1. Kết nối database
2. Right click database → **View Diagram**
3. Hoặc: Database Navigator → **ER Diagram**
4. Drag & drop tables vào canvas
5. Auto arrange
6. Export (File → Export Diagram)

**Sử dụng DataGrip (JetBrains):**

1. Right click database → **Diagrams** → **Show Visualization**
2. Chọn tables
3. Auto layout (Ctrl+Shift+F5)
4. Export (Right click → Export Diagram)

**Ưu điểm:**
- ✅ Tự động từ database thực
- ✅ Luôn đồng bộ với schema
- ✅ Không cần viết code
- ✅ Hiển thị data types chính xác

---

## 🎨 So sánh các công cụ

| Công cụ | Độ khó | Offline | Export | Đẹp | Tốc độ | Khuyên dùng |
|---------|--------|---------|--------|-----|--------|-------------|
| **dbdiagram.io** | ⭐ Dễ | ❌ | ✅ PNG/PDF/SVG | ⭐⭐⭐⭐⭐ | ⚡ Nhanh | ✅ **Tốt nhất** |
| **Mermaid** | ⭐⭐ TB | ✅ | ✅ PNG/SVG | ⭐⭐⭐⭐ | ⚡ Nhanh | ✅ Cho GitHub |
| **PlantUML** | ⭐⭐⭐ Khó | ✅ | ✅ PNG/SVG | ⭐⭐⭐ | 🐌 Chậm | ✅ Cho dev |
| **pgAdmin** | ⭐ Dễ | ✅ | ✅ PNG | ⭐⭐⭐ | ⚡ Nhanh | ✅ Từ DB thực |
| **DBeaver** | ⭐ Dễ | ✅ | ✅ PNG | ⭐⭐⭐⭐ | ⚡ Nhanh | ✅ Từ DB thực |

---

## 🚀 Quick Start (1 phút)

### Cách nhanh nhất - Layout đẹp:

1. Vào https://dbdiagram.io/
2. Copy file `dbdiagram_io_clean_layout.dbml` ⭐
3. Paste vào editor
4. Click "Auto Arrange" nếu cần
5. Done! 🎉

### Layout suggestions:

**Bố cục đề xuất (kéo thả các bảng):**

```
┌─────────────────────┬─────────────────────┐
│  AUTHENTICATION     │  LIBRARY CORE       │
│  (Top Left)         │  (Top Right)        │
│                     │                     │
│  • users            │  • readers          │
│  • password_reset   │  • books            │
│  • login_history    │  • borrow_cards     │
│                     │                     │
├─────────────────────┼─────────────────────┤
│  IOT SCANNING       │  NOTIFICATIONS      │
│  (Bottom Left)      │  (Bottom Right)     │
│                     │                     │
│  • iot_scan_logs    │  • notifications    │
│  • scan_logs        │                     │
│                     │                     │
└─────────────────────┴─────────────────────┘
```

**Tips:**
- Đặt `borrow_cards` ở giữa (junction table)
- Đặt `users` gần `borrow_cards` (nhiều FK)
- Đặt `readers` và `books` hai bên `borrow_cards`
- Đặt IoT tables ở dưới (ít FK hơn)

### Cho GitHub README:

1. Copy code từ `mermaid_erd.md`
2. Paste vào `README.md`
3. Push lên GitHub
4. Done! 🎉

---

## 📝 Chi tiết Relationships

### Foreign Key Constraints

| From Table | Column | To Table | Column | Delete Rule |
|------------|--------|----------|--------|-------------|
| password_reset_tokens | user_id | users | id | CASCADE |
| login_history | user_id | users | id | CASCADE |
| borrow_cards | borrower_student_id | readers | student_id | SET NULL |
| borrow_cards | book_code | books | book_code | SET NULL |
| iot_scan_logs | reader_id | readers | id | SET NULL |
| scan_logs | book_id | books | id | CASCADE |

### Soft References (Optional)

| From Table | Column | To Table | Column | Note |
|------------|--------|----------|--------|------|
| scan_logs | student_id | readers | student_id | Không có FK, linh hoạt |

---

## 🔧 Customize

### Thay đổi màu sắc (dbdiagram.io)

```dbml
Table books [headercolor: #3498db] {
  // Blue color for books
}

Table readers [headercolor: #2ecc71] {
  // Green color for readers
}
```

### Thay đổi layout (PlantUML)

```plantuml
skinparam linetype ortho  // Đường thẳng góc
skinparam linetype polyline  // Đường cong
```

### Thêm notes (DBML)

```dbml
Note: 'Đây là ghi chú cho table'
```

---

## 📚 Tài liệu tham khảo

- **DBML Syntax**: https://dbml.dbdiagram.io/docs/
- **Mermaid Docs**: https://mermaid.js.org/
- **PlantUML Guide**: https://plantuml.com/
- **PostgreSQL ERD**: https://www.postgresql.org/docs/

---

## 💡 Tips & Best Practices

1. **Luôn update ERD khi thay đổi schema**
   - Chạy migration → Update DBML → Commit
   
2. **Commit ERD vào Git** để track changes
   - Dễ review trong Pull Request
   - History của database schema
   
3. **Dùng dbdiagram.io** cho presentation
   - Đẹp, professional
   - Dễ share với team
   
4. **Dùng Mermaid** cho documentation
   - Tích hợp GitHub/GitLab
   - Version control
   
5. **Dùng pgAdmin** để verify với DB thực
   - Đảm bảo đồng bộ
   - Catch missing indexes

6. **Export nhiều format**
   - PNG cho documentation
   - SVG cho website
   - PDF cho báo cáo

---

## 🐛 Troubleshooting

### PlantUML không hiển thị?
```bash
# Kiểm tra Java
java -version

# Cài Java nếu chưa có
# Windows: https://www.java.com/
# Mac: brew install openjdk
# Linux: sudo apt-get install default-jdk

# Cài Graphviz (optional)
# Windows: choco install graphviz
# Mac: brew install graphviz
# Linux: sudo apt-get install graphviz
```

### Mermaid không render trên GitHub?
- Check syntax tại: https://mermaid.live/
- Đảm bảo dùng code block: \`\`\`mermaid
- Kiểm tra indentation (phải đúng)

### dbdiagram.io lỗi syntax?
- Check DBML docs: https://dbml.dbdiagram.io/docs/
- Validate online trước khi paste
- Kiểm tra dấu ngoặc, dấu phẩy

### Database connection failed?
```bash
# Kiểm tra PostgreSQL đang chạy
# Windows:
net start postgresql-x64-14

# Mac:
brew services start postgresql

# Linux:
sudo systemctl start postgresql
```

---

## 📞 Support

Nếu có vấn đề, check:
1. File `../DATABASE_ERD.md` - Tài liệu chi tiết
2. File `../DATABASE_SUMMARY.md` - Tổng hợp database
3. File `sql_create_diagram.sql` - Queries để debug
4. GitHub Issues của các tools

---

## 🎓 Learning Resources

- **Database Design**: https://www.lucidchart.com/pages/database-diagram/database-design
- **ERD Tutorial**: https://www.visual-paradigm.com/guide/data-modeling/what-is-entity-relationship-diagram/
- **Normalization**: https://www.guru99.com/database-normalization.html
- **PostgreSQL Best Practices**: https://wiki.postgresql.org/wiki/Don%27t_Do_This

---

**Happy Diagramming! 🎨**

*Last updated: 2025-01-21*
