# Màn hình Quét IoT - IoT Scanning Screen

## Tổng quan

Màn hình này cho phép người dùng tạo thẻ mượn sách bằng cách quét RFID và barcode thông qua thiết bị IoT (ESP32).

## Luồng hoạt động

```
1. Người dùng nhấn nút "+" ở màn hình danh sách thẻ mượn
   ↓
2. Dialog hiển thị 2 lựa chọn:
   - Quét bằng IoT (RFID + Camera)
   - Nhập thủ công
   ↓
3. Nếu chọn "Quét bằng IoT":
   ↓
4. Màn hình IoT Scanning mở ra
   ↓
5. Kết nối với WebSocket server (ws://localhost:3000/ws)
   ↓
6. Bước 1: Quét thẻ RFID sinh viên
   - Đặt thẻ lên đầu đọc RC522
   - Nhận thông tin: Tên, MSSV, Lớp, SĐT, Email
   ↓
7. Bước 2: Quét barcode sách
   - Đưa sách vào trước camera ESP32-CAM
   - Nhận thông tin: Tên sách, Mã sách, Tác giả
   ↓
8. Tự động chuyển sang form mượn sách với dữ liệu đã điền sẵn
```

## Giao diện

### Các thành phần chính:

1. **Status Card** - Hiển thị trạng thái kết nối
   - Đang kết nối (màu cam)
   - Đã kết nối (màu xanh)
   - Lỗi kết nối (màu đỏ)

2. **Progress Indicator** - Hiển thị tiến trình 2 bước
   - Bước 1: Quét thẻ sinh viên
   - Bước 2: Quét mã sách

3. **Instructions Card** - Hướng dẫn sử dụng
   - Các bước thực hiện
   - Lưu ý quan trọng

4. **Student Card** - Hiển thị thông tin sinh viên đã quét
   - Họ tên
   - MSSV
   - Lớp

5. **Book Card** - Hiển thị thông tin sách đã quét
   - Tên sách
   - Mã sách
   - Tác giả

## Kết nối Backend

### API Polling (HTTP)
App sẽ polling API mỗi 2 giây để lấy dữ liệu quét:

```
GET http://localhost:3000/api/iot/scan-session
```

### Response Format

**Chưa có quét:**
```json
{
  "success": false,
  "status": "no_session",
  "message": "Chưa có quét nào. Vui lòng quét thẻ sinh viên."
}
```

**Đã quét thẻ, chờ sách:**
```json
{
  "success": false,
  "status": "waiting_book",
  "message": "Đã quét thẻ, đang chờ quét sách...",
  "student": {
    "student_id": "B20DCCN001",
    "name": "Nguyễn Văn A",
    "class": "D20CQCN01-B",
    "phone": "0123456789",
    "email": "student@example.com"
  }
}
```

**Hoàn tất (cả thẻ + sách):**
```json
{
  "success": true,
  "data": {
    "student": {
      "student_id": "B20DCCN001",
      "name": "Nguyễn Văn A",
      "class": "D20CQCN01-B",
      "phone": "0123456789",
      "email": "student@example.com"
    },
    "book": {
      "book_code": "BOOK001",
      "title": "Clean Code",
      "author": "Robert C. Martin",
      "category": "Programming",
      "available_copies": 5,
      "total_copies": 10
    },
    "scanned_at": "2025-11-21T10:30:30Z"
  }
}
```

### Cơ chế hoạt động

1. **ESP32 quét thẻ RFID** → POST `/api/iot/scan-student-card`
   - Backend lưu thông tin sinh viên vào session (in-memory)
   
2. **ESP32 chụp ảnh barcode** → POST `/api/iot/scan-book-image`
   - Backend decode barcode, tìm sách, cập nhật session
   
3. **App polling** → GET `/api/iot/scan-session` (mỗi 2 giây)
   - Nếu có cả thẻ + sách: Trả về data và xóa session
   - Nếu chỉ có thẻ: Trả về status "waiting_book"
   - Nếu chưa có gì: Trả về status "no_session"

### Session Timeout
- Session tự động xóa sau 60 giây nếu không hoàn tất

## Files liên quan

- `iot_scanning_screen.dart` - Màn hình chính
- `iot_bloc.dart` - Business logic
- `iot_websocket_datasource.dart` - Kết nối WebSocket
- `iot_scan_event_model.dart` - Model dữ liệu scan
- `borrow_list_screen.dart` - Màn hình gọi IoT scanning

## TODO

- [ ] Truyền dữ liệu đã quét vào BorrowFormScreen
- [ ] Thêm timeout cho mỗi bước quét
- [ ] Thêm nút "Quét lại" nếu quét sai
- [ ] Lưu lịch sử quét vào database
- [ ] Thêm âm thanh/rung khi quét thành công
- [ ] Hỗ trợ quét offline (cache data)

## Cấu hình

WebSocket URL có thể được cấu hình trong `injection.dart`:

```dart
getIt.registerLazySingleton<IoTWebSocketDataSource>(
  () => IoTWebSocketDataSource(
    wsUrl: 'ws://localhost:3000/ws', // Thay đổi URL tại đây
  ),
);
```

## Testing

Để test màn hình này:

1. Chạy backend services:
   ```bash
   .\start_all_services.ps1
   ```

2. Đảm bảo WebSocket server đang chạy ở port 3000

3. Mở app và nhấn nút "+" → Chọn "Quét bằng IoT"

4. Kiểm tra kết nối và quét thử
