# Hướng dẫn tích hợp tính năng IoT vào App

## Đã tạo các file mới:

1. `presentation/screens/borrow_method_selection_screen.dart` - Màn hình chọn phương thức
2. `presentation/screens/borrow_iot_screen.dart` - Màn hình quét IoT

## Cần cập nhật:

### 1. Thêm dependency vào `pubspec.yaml`:

```yaml
dependencies:
  web_socket_channel: ^2.4.0
```

Chạy: `flutter pub get`

### 2. Sửa navigation trong file nơi tạo thẻ mượn mới

Tìm nơi navigate tới `BorrowFormScreen()` (thường trong `borrow_list_screen.dart` hoặc nút FAB)

**Thay đổi từ:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const BorrowFormScreen(),
  ),
);
```

**Thành:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const BorrowMethodSelectionScreen(),
  ),
);
```

### 3. Sửa `BorrowFormScreen` để nhận prefilled data

Thêm parameter `prefilledData` vào constructor:

```dart
class BorrowFormScreen extends StatelessWidget {
  final int? borrowId;
  final BorrowFormData? prefilledData;  // ← THÊM DÒNG NÀY

  const BorrowFormScreen({
    Key? key,
    this.borrowId,
    this.prefilledData,  // ← THÊM DÒNG NÀY
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<BorrowBloc>(),
      child: _BorrowFormScreenContent(
        borrowId: borrowId,
        prefilledData: prefilledData,  // ← THÊM DÒNG NÀY
      ),
    );
  }
}
```

Và trong `_BorrowFormScreenContent`:

```dart
class _BorrowFormScreenContent extends StatefulWidget {
  final int? borrowId;
  final BorrowFormData? prefilledData;  // ← THÊM DÒNG NÀY

  const _BorrowFormScreenContent({
    Key? key,
    this.borrowId,
    this.prefilledData,  // ← THÊM DÒNG NÀY
  }) : super(key: key);

  @override
  State<_BorrowFormScreenContent> createState() => _BorrowFormScreenState();
}
```

Trong `initState()` của `_BorrowFormScreenState`, thêm:

```dart
@override
void initState() {
  super.initState();
  _isEditing = widget.borrowId != null;
  
  // Initialize dates
  final now = DateTime.now();
  _borrowDate = now;
  _expectedReturnDate = now.add(const Duration(days: 14));
  
  // ← THÊM ĐOẠN NÀY
  // Load prefilled data from IoT
  if (widget.prefilledData != null) {
    _loadFormData(widget.prefilledData!);
  }
}
```

### 4. Cập nhật IP của ESP32

Trong file `borrow_iot_screen.dart`, dòng 22:

```dart
static const String ESP32_IP = '172.20.10.2';  // ← SỬA IP NÀY
```

Thay bằng IP thực tế của ESP32-S3 của bạn.

### 5. Import các file mới

Thêm import vào file cần thiết:

```dart
import 'package:your_app/features/tuan_borrow_management/presentation/screens/borrow_method_selection_screen.dart';
```

## Cách hoạt động:

1. User nhấn "Tạo thẻ mượn" → Hiển thị màn hình chọn phương thức
2. Chọn "Nhập thủ công" → Vào form như cũ
3. Chọn "Quét bằng IoT" → Vào màn hình IoT:
   - Kết nối WebSocket tới ESP32 (ws://ESP32_IP:81)
   - Đợi quét thẻ RFID → Nhận thông tin sinh viên
   - Đợi quét barcode → Nhận thông tin sách
   - Nhấn "Tiếp tục" → Vào form với data đã điền sẵn

## Test:

1. Đảm bảo ESP32 đang chạy và kết nối WiFi
2. Đảm bảo máy chạy app và ESP32 cùng mạng
3. Mở app → Tạo thẻ mượn → Chọn "Quét bằng IoT"
4. Kiểm tra connection status (phải hiện "Online")
5. Quét thẻ RFID trên ESP32
6. Quét barcode sách trên ESP32
7. Nhấn "Tiếp tục tạo thẻ mượn"

## Troubleshooting:

- **Không kết nối được**: Kiểm tra IP ESP32, đảm bảo cùng mạng WiFi
- **Không nhận được data**: Kiểm tra Serial Monitor của ESP32, xem có gửi WebSocket không
- **App crash**: Chạy `flutter pub get` để cài web_socket_channel

## Demo UI:

Màn hình chọn phương thức có 2 card:
- 📝 Nhập thủ công (màu xanh dương)
- 📱 Quét bằng IoT (màu xanh lá, có badge "MỚI")

Màn hình IoT có:
- Connection status indicator (Online/Offline)
- Hướng dẫn 3 bước
- Card thông tin sinh viên (chưa quét / đã quét)
- Card thông tin sách (chưa quét / đã quét)
- Nút "Tiếp tục" (chỉ hiện khi đã quét đủ)
