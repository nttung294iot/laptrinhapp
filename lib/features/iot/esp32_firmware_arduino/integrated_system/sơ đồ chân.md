# Hệ thống IoT Tích hợp - ESP32-S3 Hub + ESP32-CAM

## Kiến trúc

```
App (Flutter)
    ↕️ WebSocket/HTTP
ESP32-S3 Hub (Master)
    ├─ RFID Reader (RC522)
    ├─ LCD Display (16x2 I2C)
    └─ ↔️ UART → ESP32-CAM (Slave)
                    └─ Camera OV2640
```

## Kết nối phần cứng

### ESP32-S3 ↔ ESP32-CAM (UART)
- ESP32-S3 TX (GPIO17) → ESP32-CAM RX (GPIO3/U0RXD)
- ESP32-S3 RX (GPIO18) → ESP32-CAM TX (GPIO1/U0TXD)
- GND chung

### ESP32-S3 ↔ RC522 (SPI)
- SCK: GPIO12
- MISO: GPIO13
- MOSI: GPIO11
- CS: GPIO10
- RST: GPIO9

### ESP32-S3 ↔ LCD (I2C)
- SDA: GPIO4
- SCL: GPIO5

### Nút nhấn Reset
- Button Pin 1 → ESP32-S3 GPIO2
- Button Pin 2 → GND
- (Nút nhấn 4 chân: chỉ dùng 2 chân đối diện)

**Chức năng:**
- Nhấn để hủy thao tác đang xử lý
- Reset về màn hình "Ready"
- Không reset ESP32 (giữ kết nối WiFi)
- SCL: GPIO5

## Files

1. **esp32_s3_hub.ino** - ESP32-S3 Master (RFID + LCD + UART)
2. **esp32_cam_slave.ino** - ESP32-CAM Slave (Camera + Barcode)
3. **protocol.h** - Protocol truyền dữ liệu UART

## Thuật toán chụp Barcode tối ưu

### Multi-shot với Auto-focus simulation:
1. Chụp 3 ảnh với exposure khác nhau
2. Đánh giá độ sắc nét (Laplacian variance)
3. Chọn ảnh rõ nhất
4. Gửi về ESP32-S3

### Tối ưu hóa:
- Độ phân giải: XGA (1024x768)
- Quality: 6 (cao)
- Sharpness: Max
- Contrast: Tăng
- Auto white balance

## Cài đặt

1. Upload `esp32_s3_hub.ino` lên ESP32-S3
2. Upload `esp32_cam_slave.ino` lên ESP32-CAM
3. Kết nối dây UART
4. Cấp nguồn và test

## Độ trễ dự kiến

- RFID scan → LCD: ~10ms
- RFID → App: ~30ms
- Trigger camera: ~5ms
- Chụp 3 ảnh: ~600ms
- Truyền ảnh UART: ~100ms
- **Tổng: ~750ms** (từ quét RFID đến có ảnh)
