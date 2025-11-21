# Tính năng Thống kê theo Người mượn

## Mô tả
Tính năng mới cho phép xem thống kê chi tiết theo từng người mượn sách, bao gồm:
- Thống kê tổng quan (tổng mượn, đang mượn, đã trả, quá hạn)
- Biểu đồ mượn sách theo thời gian (tuần/tháng/quý/năm)
- Danh sách sách đã mượn

## Cách sử dụng

### 1. Truy cập từ màn hình Thống kê & Báo cáo
- Mở tab "Thống kê & Báo cáo" từ menu chính
- Chọn tab "Người mượn" để xem danh sách người mượn

### 2. Xem chi tiết người mượn
Có 3 cách để xem chi tiết:

#### a. Nhấn vào biểu đồ
- Trong tab "Người mượn", nhấn vào cột biểu đồ của người mượn
- Màn hình chi tiết sẽ hiển thị

#### b. Nhấn vào bảng thống kê
- Cuộn xuống bảng "Chi tiết thống kê người dùng"
- Nhấn vào dòng của người mượn muốn xem

#### c. Nhấn vào card người mượn
- Trong danh sách người mượn (nếu có widget BorrowerListWidget)
- Nhấn vào card của người mượn

### 3. Chọn khoảng thời gian
Trong màn hình chi tiết người mượn, chọn một trong các khoảng thời gian:
- **Tuần**: Xem thống kê 12 tuần gần nhất
- **Tháng**: Xem thống kê 12 tháng gần nhất
- **Quý**: Xem thống kê 8 quý gần nhất
- **Năm**: Xem thống kê 5 năm gần nhất

## Thông tin hiển thị

### Thẻ thống kê
- **Tổng mượn**: Tổng số lần người này đã mượn sách
- **Đang mượn**: Số sách đang mượn (chưa trả và chưa quá hạn)
- **Đã trả**: Số sách đã trả
- **Quá hạn**: Số sách đang quá hạn

### Biểu đồ
- Hiển thị số lần mượn sách theo từng khoảng thời gian
- Trục X: Nhãn thời gian (T1, T2,... cho tuần/tháng, Q1, Q2,... cho quý, năm)
- Trục Y: Số lần mượn

### Danh sách sách đã mượn
- Tên sách
- Số lần mượn sách đó
- Sắp xếp theo số lần mượn giảm dần

## Cấu trúc code

### Models
- `BorrowerStatisticsData`: Model chính chứa thống kê người mượn
- `PeriodData`: Dữ liệu theo khoảng thời gian
- `BorrowedBookInfo`: Thông tin sách đã mượn
- `TimePeriod`: Enum cho các loại khoảng thời gian

### Services
- `BorrowerStatisticsService`: Service xử lý logic tính toán thống kê
  - `getBorrowerStatistics()`: Lấy thống kê cho một người mượn
  - `_calculatePeriodData()`: Tính toán dữ liệu theo khoảng thời gian
  - `_calculateBorrowedBooks()`: Tính toán danh sách sách đã mượn

### BLoC
- `BorrowerStatisticsBloc`: Quản lý state cho tính năng
  - Events: `LoadBorrowerStatisticsEvent`
  - States: `BorrowerStatisticsLoading`, `BorrowerStatisticsLoaded`, `BorrowerStatisticsError`

### Screens
- `BorrowerDetailStatisticsScreen`: Màn hình chi tiết thống kê người mượn

### Widgets
- `BorrowerListWidget`: Widget hiển thị danh sách người mượn dạng card
- `UserStatisticsTab`: Tab hiển thị thống kê người dùng (đã cập nhật để hỗ trợ navigation)

## Dependency Injection
Service và BLoC đã được đăng ký trong `injection.dart`:
```dart
getIt.registerLazySingleton<BorrowerStatisticsService>(
  () => BorrowerStatisticsService(
    borrowCardRepository: getIt(),
  ),
);

getIt.registerFactory<BorrowerStatisticsBloc>(
  () => BorrowerStatisticsBloc(
    statisticsService: getIt(),
  ),
);
```

## Lưu ý kỹ thuật
- Sử dụng `fl_chart` package để vẽ biểu đồ
- Dữ liệu được lấy từ `BorrowCardRepository`
- Hỗ trợ navigation với BLoC provider
- UI responsive và thân thiện với người dùng
