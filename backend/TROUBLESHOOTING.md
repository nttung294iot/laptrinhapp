# Troubleshooting - IoT API Connection Issues

## Vấn đề: "Connection Refused" lúc được lúc không

### Nguyên nhân:
1. **Windows Firewall chặn** - Phổ biến nhất
2. **Keep-alive connections** - Server và ESP32 không đồng bộ
3. **WiFi không ổn định** - ESP32 mất kết nối tạm thời
4. **Server quá tải** - Xử lý request chậm

---

## Giải pháp:

### 1. Setup Windows Firewall (QUAN TRỌNG!)

**Chạy PowerShell as Administrator:**

```powershell
# Cách 1: Dùng script có sẵn
cd backend
.\setup_firewall.ps1

# Cách 2: Thủ công
New-NetFirewallRule -DisplayName "IoT API Server - Port 3000" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 3000 `
    -Action Allow `
    -Profile Any `
    -Enabled True
```

**Kiểm tra rule đã tạo:**
```powershell
Get-NetFirewallRule -DisplayName "IoT API Server*"
```

---

### 2. Kiểm tra Server đang chạy

```powershell
# Check process
Get-Process -Name node

# Check port
netstat -ano | findstr ":3000"

# Test từ máy local
curl http://localhost:3000/

# Test từ IP thật (thay YOUR_IP)
curl http://YOUR_IP:3000/
```

---

### 3. Kiểm tra IP Address

```powershell
# Xem tất cả IP
ipconfig

# Xem IP của WiFi adapter
Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.IPAddress -like "172.20.*"}
```

**Lưu ý:** IP có thể thay đổi khi:
- Restart máy
- Reconnect WiFi
- DHCP lease hết hạn

**→ Cần cập nhật IP trong code ESP32 nếu IP thay đổi!**

---

### 4. Sửa code ESP32 (Đã fix)

Code mới có:
- ✅ Retry 3 lần với delay tăng dần
- ✅ Check WiFi trước khi gửi
- ✅ Reconnect WiFi nếu mất kết nối
- ✅ Force close connections (không reuse)
- ✅ Timeout hợp lý (10s)

---

### 5. Sửa Backend (Đã fix)

Backend mới có:
- ✅ Force close connections
- ✅ Keep-alive timeout ngắn (5s)
- ✅ Log rõ hơn (IP client, timestamp)
- ✅ Better error handling

---

## Test Connection

### Từ máy Windows:

```powershell
# Test GET
curl http://172.20.10.5:3000/

# Test POST
$body = @{card_uid="TEST123"} | ConvertTo-Json
Invoke-RestMethod -Uri "http://172.20.10.5:3000/api/iot/scan-student-card" `
    -Method POST `
    -Body $body `
    -ContentType "application/json"
```

### Từ ESP32:

Xem Serial Monitor, sẽ thấy:
```
========== API DEBUG ==========
[API] WiFi Status: Connected
[API] WiFi RSSI: -40
[API] Local IP: 172.20.10.2
[API] Gateway: 172.20.10.1
[API] Calling: http://172.20.10.5:3000/api/iot/scan-student-card
[API] Sending POST...
[API] Response code: 200
[API] Success!
```

---

## Checklist khi gặp lỗi:

- [ ] Windows Firewall rule đã add chưa?
- [ ] Server đang chạy không? (check port 3000)
- [ ] IP trong code ESP32 đúng chưa?
- [ ] ESP32 và máy cùng mạng WiFi không?
- [ ] WiFi signal mạnh không? (RSSI > -70)
- [ ] Backend log có hiện request không?

---

## Lỗi thường gặp:

### "Connection Refused"
→ Firewall chặn hoặc server không chạy

### "Connection Timeout"
→ IP sai hoặc không cùng mạng

### "WiFi Disconnected"
→ Signal yếu hoặc router có vấn đề

### Lúc được lúc không
→ Firewall hoặc keep-alive issues (đã fix)

---

## Contact

Nếu vẫn gặp vấn đề, cung cấp:
1. Serial Monitor log từ ESP32
2. Backend console log
3. Output của: `ipconfig`, `netstat -ano | findstr ":3000"`
