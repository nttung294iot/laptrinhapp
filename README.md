# Khởi chạy tất cả
.\start_all_services.ps1

# Hoặc dùng CMD
start_all_services.bat

# Dừng tất cả
.\stop_all_services.ps1







# 📚 Quản Lý Thư Viện - Library Management System

Ứng dụng quản lý thư viện được xây dựng bằng Flutter và PostgreSQL.

## ✨ Tính năng chính

### 🔐 Xác thực & Phân quyền
- Đăng nhập với username/password
- Quên mật khẩu (gửi mã OTP qua email)
- Phân quyền: Admin, Librarian, Member

### 📖 Quản lý sách
- Thêm, sửa, xóa sách
- Tìm kiếm sách theo tên, tác giả, thể loại
- Quản lý thông tin chi tiết sách

### 👥 Quản lý người dùng
- Thêm, sửa, xóa người dùng
- Quản lý thông tin cá nhân
- Xem lịch sử mượn sách

### 📋 Quản lý mượn/trả
- Tạo phiếu mượn sách
- Trả sách và tính phí phạt (nếu quá hạn)
- Xem danh sách sách đang mượn
- Xem lịch sử mượn/trả

### ⚠️ Cảnh báo quá hạn
- Tự động gửi email nhắc nhở sách sắp đến hạn (0-3 ngày)
- Gửi email cảnh báo sách quá hạn (mỗi ngày)
- Tự động gửi vào 8:00 AM hàng ngày

### 📊 Thống kê & Báo cáo
- Thống kê số lượng sách, người dùng, phiếu mượn
- Báo cáo sách được mượn nhiều nhất
- Xuất báo cáo PDF

### 🤖 IoT - Trạm Quét Thẻ & Sách Tự động (NEW!)
- Quét thẻ RFID sinh viên tự động
- Quét barcode sách bằng camera ESP32-CAM
- Hiển thị thông tin realtime trên LCD 16x2
- Tự động điền form mượn sách trên app
- Kết nối WiFi và gửi dữ liệu lên server
- **Chi tiết:** [features/iot/README.md](features/iot/README.md)

## 🛠️ Công nghệ sử dụng

- **Frontend**: Flutter (Dart)
- **Backend**: PostgreSQL
- **State Management**: BLoC Pattern
- **Dependency Injection**: GetIt + Injectable
- **Email Service**: Mailer (SMTP Gmail)

## 📋 Yêu cầu hệ thống

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Android Emulator hoặc thiết bị thật

> **Lưu ý:** Database và Email đã được cấu hình sẵn, bạn chỉ cần chạy app!

## 🚀 Hướng dẫn cài đặt

### 1. Clone project

```bash
git clone https://github.com/nttung294iot/laptrinhapp.git
cd laptrinhapp
```

### 2. Cài đặt dependencies

```bash
flutter pub get
```

### 3. Chạy ứng dụng

```bash
# Kiểm tra devices
flutter devices

# Chạy trên emulator/device
flutter run

# Hoặc chỉ định device cụ thể (chạy ở file main.dart)
flutter run -d <device-id>
```

## 👤 Tài khoản mặc định

Sau khi import database, bạn có thể đăng nhập với:

**Admin:**
- Username: `admin`
- Password: `admin123`

**Librarian:**
- Username: `librarian`
- Password: `admin123`

**Member:**
- Username: `user`
- Password: `user123`

## 📁 Cấu trúc thư mục

```
lib/
├── config/                      # Cấu hình app
│   ├── database/                # Config kết nối database
│   ├── environment/             # Environment variables
│   ├── injection/               # Dependency injection (GetIt + Injectable)
│   ├── routes/                  # App routes
│   └── themes/                  # App themes (light/dark)
│
├── core/                        # Core utilities dùng chung
│   ├── constants/               # Constants (colors, strings, etc.)
│   ├── errors/                  # Error handling & failures
│   ├── presentation/            # Core screens (splash, main menu)
│   ├── services/                # Core services
│   └── utils/                   # Utility functions
│
├── features/                    # Features (Clean Architecture)
│   │
│   ├── auth/                    # 🔐 Xác thực & Phân quyền
│   │   ├── data/                # Data sources, repositories, models
│   │   ├── domain/              # Entities, repositories interface
│   │   └── presentation/        # Screens (login, forgot password), BLoC
│   │
│   ├── iot/                     # 🤖 IoT - Trạm Quét Tự động (NEW!)
│   │   ├── data/                # WebSocket datasource, models
│   │   └── presentation/        # IoT BLoC, widgets (status, listener)
│   │
│   ├── dashboard/               # 📊 Dashboard & Thống kê tổng quan
│   │   ├── data/                # Dashboard services
│   │   ├── domain/              # Dashboard entities
│   │   └── presentation/        # Dashboard BLoC
│   │
│   ├── user_management/         # 👥 Quản lý người dùng
│   │   └── presentation/        # Screens (user list, create/edit user)
│   │
│   ├── tuan_borrow_management/  # 📋 Quản lý mượn/trả sách
│   │   ├── data/                # Borrow data sources, repositories
│   │   ├── domain/              # Borrow entities
│   │   └── presentation/        # Screens (borrow list, create/return), BLoC
│   │
│   ├── duc_search_functionality/ # 🔍 Tìm kiếm sách
│   │   ├── data/                # Search data sources, repositories
│   │   ├── domain/              # Search entities
│   │   └── presentation/        # Search screen, BLoC, widgets
│   │
│   ├── tung_overdue_alerts/     # ⚠️ Cảnh báo sách quá hạn
│   │   ├── data/                # Overdue services, repositories
│   │   └── presentation/        # Overdue screen, BLoC, widgets
│   │
│   ├── statistics_reports/      # 📈 Thống kê & Báo cáo
│   │   ├── data/                # Statistics services, repositories
│   │   ├── domain/              # Statistics entities
│   │   └── presentation/        # Statistics screen, BLoC, widgets
│   │
│   ├── borrow_return_status/    # 📖 Trạng thái mượn/trả
│   │   ├── data/                # Status services, repositories
│   │   ├── domain/              # Status entities
│   │   └── presentation/        # Status screen, BLoC, widgets
│   │
│   └── user_borrows/            # 📚 Lịch sử mượn sách của user
│       └── presentation/        # User borrows screen
│
├── shared/                      # Shared components dùng chung
│   ├── database/                # 🗄️ Database helper (PostgreSQL connection)
│   ├── events/                  # 📡 Event bus (pub/sub pattern)
│   ├── models/                  # 📦 Shared models (User, Book, BorrowCard)
│   ├── repositories/            # 🔄 Shared repositories
│   ├── services/                # 🛠️ Shared services (Email, Notification)
│   ├── utils/                   # 🔧 Utility functions
│   └── widgets/                 # 🎨 Shared widgets (buttons, cards, etc.)
│
└── main.dart                    # 🚀 Entry point của app

database/
└── setup_postgres.sql           # 📄 SQL script tạo database & dữ liệu mẫu

features/iot/                    # 🤖 IoT Feature (ESP32-CAM + Flutter)
├── esp32_firmware/              # ESP32-CAM firmware (C++)
│   ├── src/                     # Source code (WiFi, RFID, LCD, API)
│   ├── include/                 # Header files
│   └── platformio.ini           # PlatformIO config
├── README.md                    # Tổng quan IoT feature
├── QUICK_START.md               # Bắt đầu nhanh (10 phút)
└── IMPLEMENTATION_STATUS.md     # Trạng thái triển khai

assets/
└── fonts/                       # 🔤 Fonts cho PDF generation
```

### 📝 Giải thích chi tiết

**config/** - Cấu hình toàn bộ app
- `injection/` - Setup dependency injection với GetIt
- `themes/` - Định nghĩa theme sáng/tối

**core/** - Các thành phần core dùng chung
- `presentation/screens/` - Splash screen, Main menu
- `constants/` - App colors, strings, routes

**features/** - Các tính năng chính (Clean Architecture)
- Mỗi feature có 3 layers: `data/`, `domain/`, `presentation/`
- `data/` - Xử lý data từ database/API
- `domain/` - Business logic, entities
- `presentation/` - UI screens, BLoC state management

**shared/** - Components dùng chung giữa các features
- `database/` - Kết nối PostgreSQL
- `models/` - Models dùng chung (User, Book, BorrowCard)
- `services/` - Email service, Notification scheduler
- `repositories/` - Repositories dùng chung
- `widgets/` - UI widgets tái sử dụng

## 🐛 Xử lý lỗi thường gặp

### Lỗi build Android
```
Error: Gradle build failed
```
**Giải pháp:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

## 📧 Liên hệ

Nếu có vấn đề, hãy liên hệ qua:
- GitHub: https://github.com/nttung294iot
- GitHub Issues: https://github.com/nttung294iot/laptrinhapp/issues

---

