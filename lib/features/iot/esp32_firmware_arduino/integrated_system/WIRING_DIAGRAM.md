# 🔌 Sơ Đồ Đấu Nối Phần Cứng - IoT Library System

## 📋 Tổng quan hệ thống

```
┌─────────────────────────────────────────────────────────────┐
│                    HỆ THỐNG IOT ĐỘC LẬP                     │
│                                                             │
│  ESP32-S3 (RFID Station)        ESP32-CAM (Camera)        │
│  ┌──────────────────┐           ┌──────────────────┐      │
│  │  - RFID Reader   │           │  - Camera OV2640 │      │
│  │  - LCD 16x2      │           │  - Barcode Scan  │      │
│  │  - Button Reset  │           │                  │      │
│  │  - WiFi          │           │  - WiFi          │      │
│  └──────────────────┘           └──────────────────┘      │
│         │                                │                 │
│         │         WiFi Network           │                 │
│         └────────────┬───────────────────┘                 │
│                      │                                     │
│                      ▼                                     │
│           Backend API Server (Node.js)                     │
│                   Port 3000                                │
│                      │                                     │
│                      ▼                                     │
│              Flutter App (Polling)                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎛️ ESP32-S3 Hub (Master) - Kết nối

### 1. RC522 RFID Reader (SPI)

```
RC522 Pin    →    ESP32-S3 Pin    →    Chức năng
─────────────────────────────────────────────────
SDA (SS)     →    GPIO 10          →    Chip Select
SCK          →    GPIO 12          →    SPI Clock
MOSI         →    GPIO 11          →    Master Out Slave In
MISO         →    GPIO 13          →    Master In Slave Out
RST          →    GPIO 9           →    Reset
GND          →    GND              →    Ground
3.3V         →    3.3V             →    Power
```

**Lưu ý:**
- ✅ Dùng 3.3V, KHÔNG dùng 5V (sẽ hỏng module)
- ✅ Khoảng cách quét tối đa: 3-5cm
- ✅ Thẻ RFID 13.56MHz (Mifare)

---

### 2. LCD 16x2 I2C

```
LCD Pin      →    ESP32-S3 Pin    →    Chức năng
─────────────────────────────────────────────────
SDA          →    GPIO 4           →    I2C Data
SCL          →    GPIO 5           →    I2C Clock
GND          →    GND              →    Ground
VCC          →    5V               →    Power
```

**Lưu ý:**
- ✅ LCD I2C address: `0x27` hoặc `0x3F` (kiểm tra bằng I2C scanner)
- ✅ Dùng 5V cho LCD (có IC chuyển đổi mức logic)
- ✅ Nếu không hiển thị, xoay biến trở sau LCD để chỉnh độ tương phản

---

### 3. Nút Reset

```
Button Pin   →    ESP32-S3 Pin    →    Chức năng
─────────────────────────────────────────────────
Pin 1        →    GPIO 2           →    Input (Pull-up internal)
Pin 2        →    GND              →    Ground
```

**Lưu ý:**
- ✅ Nút nhấn 4 chân: Chỉ dùng 2 chân đối diện
- ✅ Không cần điện trở pull-up (dùng internal pull-up)
- ✅ Nhấn để hủy thao tác, reset về màn hình "Ready"

---

### 4. WiFi

```
ESP32-S3 kết nối WiFi độc lập
Không cần dây nối với ESP32-CAM
```

**Cấu hình trong code:**
```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* apiServer = "http://192.168.1.100:3000";
```

**API Endpoints:**
- `POST /api/iot/scan-student-card` - Gửi UID thẻ RFID
- `GET /api/iot/heartbeat` - Kiểm tra kết nối

---

## 📷 ESP32-CAM (Độc lập) - Kết nối

### 1. Camera OV2640

```
Camera đã hàn sẵn trên board ESP32-CAM
Không cần đấu nối thêm
```

**Cấu hình:**
- Resolution: XGA (1024x768) cho barcode
- Quality: 6 (cao)
- Frame rate: ~5 FPS

---

### 2. WiFi

```
ESP32-CAM kết nối WiFi độc lập
Không cần dây nối với ESP32-S3
```

**Cấu hình trong code:**
```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* apiServer = "http://192.168.1.100:3000";
const char* barcodeDecoder = "http://192.168.1.100:5000";
```

**API Endpoints:**
- `POST /api/iot/scan-book-image` - Gửi ảnh barcode
- `POST /decode-barcode` - Decode barcode (Python service)

---

### 3. Nguồn điện

```
ESP32-CAM Pin    →    Nguồn
─────────────────────────────
5V               →    5V (USB hoặc adapter)
GND              →    GND
```

**Lưu ý:**
- ✅ ESP32-CAM cần nguồn 5V ổn định (tối thiểu 500mA)
- ⚠️ Không dùng nguồn từ USB máy tính (yếu, camera không hoạt động)
- ✅ Khuyến nghị: Adapter 5V/1A hoặc power bank

---

## 🔋 Nguồn điện tổng thể

### 2 thiết bị độc lập - 2 nguồn riêng

```
ESP32-S3:   USB 5V (từ máy tính hoặc adapter)
ESP32-CAM:  Adapter 5V/1A riêng (hoặc USB)
```

**Ưu điểm:**
- ✅ Hoàn toàn độc lập
- ✅ Không cần dây nối giữa 2 board
- ✅ Dễ bố trí vị trí
- ✅ Dễ debug

**Lưu ý:**
- ⚠️ ESP32-CAM cần nguồn ổn định (tối thiểu 500mA)
- ⚠️ Không dùng nguồn USB máy tính cho ESP32-CAM (yếu)

---

## 📐 Sơ đồ tổng thể

```
   ┌─────────────────────────────┐         ┌──────────────────┐
   │   ESP32-S3 (RFID Station)   │         │   ESP32-CAM      │
   │                             │         │                  │
   │  RC522 ──► GPIO 10,11,12,13 │         │   Camera         │
   │  LCD   ──► GPIO 4,5         │         │   OV2640         │
   │  Button ─► GPIO 2           │         │                  │
   │                             │         │                  │
   │  WiFi Module                │         │  WiFi Module     │
   └──────────┬──────────────────┘         └────────┬─────────┘
              │                                     │
              │         WiFi Network                │
              │      (192.168.1.x)                  │
              │                                     │
              └──────────────┬──────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │  Backend API Server  │
                  │    (Node.js)         │
                  │    Port 3000         │
                  │                      │
                  │  + Barcode Decoder   │
                  │    (Python)          │
                  │    Port 5000         │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │    Flutter App       │
                  │   (Polling API)      │
                  └──────────────────────┘
```

**Luồng dữ liệu:**
1. ESP32-S3 quét thẻ RFID → POST `/api/iot/scan-student-card`
2. ESP32-CAM chụp ảnh → POST `/api/iot/scan-book-image`
3. Backend lưu session (in-memory)
4. App polling → GET `/api/iot/scan-session` (mỗi 2 giây)
5. App nhận dữ liệu → Hiển thị và điền form

---

## ✅ Checklist trước khi test

### Phần cứng:
- [ ] **ESP32-S3:** RC522 đấu đúng chân SPI (10,11,12,13,9)
- [ ] **ESP32-S3:** LCD đấu đúng chân I2C (4,5)
- [ ] **ESP32-S3:** Button đấu GPIO 2 và GND
- [ ] **ESP32-CAM:** Camera OV2640 hoạt động tốt
- [ ] **Cả 2:** Nguồn 5V đủ mạnh (ESP32-CAM cần >500mA)
- [ ] **Cả 2:** Kết nối cùng mạng WiFi

### Firmware:
- [ ] Upload `esp32_s3_hub.ino` lên ESP32-S3
- [ ] Upload `esp32_cam_slave.ino` lên ESP32-CAM
- [ ] **Cả 2:** Cấu hình WiFi SSID và password giống nhau
- [ ] **Cả 2:** Cấu hình API server URL (IP máy chạy backend)
- [ ] **ESP32-S3:** Cấu hình endpoint `/api/iot/scan-student-card`
- [ ] **ESP32-CAM:** Cấu hình endpoint `/api/iot/scan-book-image`

### Backend:
- [ ] Node.js server đang chạy (port 3000)
- [ ] Python barcode decoder đang chạy (port 5000)
- [ ] Database PostgreSQL đang chạy

---

## 🐛 Troubleshooting

### LCD không hiển thị:
1. Kiểm tra I2C address: `0x27` hoặc `0x3F`
2. Xoay biến trở sau LCD
3. Kiểm tra nguồn 5V

### RFID không đọc được thẻ:
1. Kiểm tra kết nối SPI
2. Đảm bảo dùng 3.3V (không phải 5V)
3. Khoảng cách thẻ < 5cm

### ESP32-CAM không chụp ảnh:
1. Kiểm tra nguồn 5V đủ mạnh (>500mA)
2. Kiểm tra kết nối WiFi
3. Kiểm tra API server URL đúng
4. Xem Serial Monitor để debug

### Không kết nối WiFi:
1. Kiểm tra SSID và password
2. Đảm bảo WiFi 2.4GHz (không phải 5GHz)
3. Kiểm tra tín hiệu WiFi đủ mạnh

---

## 📸 Hình ảnh tham khảo

### Pinout ESP32-S3:
```
                    ┌─────────────┐
                    │   ESP32-S3  │
                    │             │
         GPIO 2 ────┤ 2       3V3 ├──── 3.3V
         GPIO 4 ────┤ 4        EN ├──── Enable
         GPIO 5 ────┤ 5       GND ├──── GND
         GPIO 9 ────┤ 9        5V ├──── 5V
        GPIO 10 ────┤ 10      GND ├──── GND
        GPIO 11 ────┤ 11      TX0 ├──── GPIO 43
        GPIO 12 ────┤ 12      RX0 ├──── GPIO 44
        GPIO 13 ────┤ 13      IO0 ├──── GPIO 0
        GPIO 17 ────┤ 17      IO1 ├──── GPIO 1
        GPIO 18 ────┤ 18      IO2 ├──── GPIO 2
                    └─────────────┘
```

### Pinout ESP32-CAM:
```
                    ┌─────────────┐
                    │  ESP32-CAM  │
                    │             │
         GPIO 1 ────┤ TX      GND ├──── GND
         GPIO 3 ────┤ RX       5V ├──── 5V
                    │             │
                    │   Camera    │
                    │   OV2640    │
                    └─────────────┘
```

---

**Tạo bởi:** IoT Library Management System
**Ngày cập nhật:** 21/11/2025
