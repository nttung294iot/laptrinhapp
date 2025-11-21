/*
 * ESP32-S3 Hub (Master)
 * RFID + LCD + UART Communication với ESP32-CAM
 * 
 * Hardware:
 * - ESP32-S3
 * - RC522 RFID Reader
 * - LCD 16x2 I2C
 * - UART to ESP32-CAM
 */

#include <WiFi.h>
#include <WiFiClient.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <MFRC522.h>
#include <SPI.h>
#include <LiquidCrystal_I2C.h>

// ============================================
// FORWARD DECLARATIONS
// ============================================

void checkBookResult();
void displayBook(String title, String bookCode);

// ============================================
// CONFIGURATION
// ============================================

// WiFi - SỬA CHO ĐÚNG VỚI WIFI CỦA BẠN!
const char* WIFI_SSID = "VDK IOT";  // ← Tên WiFi
const char* WIFI_PASSWORD = "20242025x";  // ← Mật khẩu WiFi

// API - SỬA IP NÀY CHO ĐÚNG VỚI MÁY CHẠY BACKEND!
const char* API_BASE_URL = "http://172.20.10.5:3000";  // ← Kiểm tra IP này!
const char* API_SCAN_STUDENT = "/api/iot/scan-student-card";
const char* API_SCAN_BOOK = "/api/iot/scan-book-barcode";

// ESP32-CAM IP - SỬA IP NÀY CHO ĐÚNG VỚI ESP32-CAM!
const char* ESP32_CAM_IP = "http://172.20.10.3";  // ← IP của ESP32-CAM

// Device
const char* DEVICE_ID = "IOT_STATION_01";

// Pins - RFID (SPI)
#define RFID_CS_PIN 10
#define RFID_RST_PIN 9
#define RFID_SCK_PIN 12
#define RFID_MOSI_PIN 11
#define RFID_MISO_PIN 13

// Pins - LCD (I2C)
#define LCD_ADDRESS 0x27
#define LCD_COLS 16
#define LCD_ROWS 2
#define LCD_SDA_PIN 4
#define LCD_SCL_PIN 5

// Pins - Button
#define BUTTON_PIN 2  // GPIO2 - Nút nhấn reset

// WebSocket
#define WS_PORT 81

// Timing
#define RFID_SCAN_INTERVAL 500
#define LCD_TIMEOUT 5000
#define HEARTBEAT_INTERVAL 60000

// ============================================
// GLOBAL OBJECTS
// ============================================

MFRC522 rfid(RFID_CS_PIN, RFID_RST_PIN);
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLS, LCD_ROWS);
WebServer server(80);
WebSocketsServer webSocket = WebSocketsServer(WS_PORT);
HTTPClient http;

// State
unsigned long lastRFIDCheck = 0;
unsigned long lastDisplayUpdate = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastButtonPress = 0;
bool isProcessing = false;
String lastUID = "";
String currentStudentId = "";
uint8_t wsClientId = 255;
bool buttonPressed = false;

// ============================================
// SETUP
// ============================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n========================================");
  Serial.println("  ESP32-S3 Hub - Master Station");
  Serial.println("========================================\n");
  
  // In ra nguyên nhân reset
  esp_reset_reason_t reason = esp_reset_reason();
  Serial.print("[SYSTEM] Reset reason: ");
  switch(reason) {
    case ESP_RST_POWERON: Serial.println("Power on"); break;
    case ESP_RST_SW: Serial.println("Software reset"); break;
    case ESP_RST_PANIC: Serial.println("Exception/panic"); break;
    case ESP_RST_INT_WDT: Serial.println("Interrupt watchdog"); break;
    case ESP_RST_TASK_WDT: Serial.println("Task watchdog"); break;
    case ESP_RST_WDT: Serial.println("Other watchdog"); break;
    case ESP_RST_BROWNOUT: Serial.println("Brownout (low voltage)"); break;
    default: Serial.println("Unknown"); break;
  }
  Serial.println();
  
  // Initialize Button
  pinMode(BUTTON_PIN, INPUT_PULLUP);  // Nút nhấn với pull-up
  
  // Initialize LCD
  Wire.begin(LCD_SDA_PIN, LCD_SCL_PIN);
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.print("Starting...");
  
  // Connect WiFi
  Serial.println("[WiFi] Connecting...");
  lcd.clear();
  lcd.print("WiFi...");
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\n[WiFi] Connected!");
  Serial.print("[WiFi] IP: ");
  Serial.println(WiFi.localIP());
  
  lcd.clear();
  lcd.print("WiFi OK!");
  lcd.setCursor(0, 1);
  lcd.print(WiFi.localIP());
  delay(2000);
  
  // Skip API test to avoid watchdog timeout
  Serial.println("[TEST] Skipping API test (will test on first scan)");
  Serial.print("[TEST] API URL: ");
  Serial.println(API_BASE_URL);
  
  lcd.clear();
  lcd.print("API Ready");
  delay(1000);
  
  // Test ESP32-CAM connection via HTTP
  Serial.println("[Camera] Testing HTTP connection...");
  lcd.clear();
  lcd.print("Test Camera...");
  
  bool cameraOK = testCameraConnection();
  
  if (cameraOK) {
    Serial.println("[Camera] ESP32-CAM connected via HTTP!");
    lcd.clear();
    lcd.print("Camera OK!");
    delay(1000);
  } else {
    Serial.println("[Camera] ESP32-CAM not responding!");
    Serial.println("[Camera] System will continue without camera");
    lcd.clear();
    lcd.print("Camera OFFLINE");
    lcd.setCursor(0, 1);
    lcd.print("RFID only mode");
    delay(2000);
  }
  
  // Initialize SPI for RFID
  SPI.begin(RFID_SCK_PIN, RFID_MISO_PIN, RFID_MOSI_PIN, RFID_CS_PIN);
  
  // Initialize RFID
  Serial.println("[RFID] Initializing...");
  lcd.clear();
  lcd.print("Init RFID...");
  
  rfid.PCD_Init();
  byte version = rfid.PCD_ReadRegister(rfid.VersionReg);
  
  if (version == 0x00 || version == 0xFF) {
    Serial.println("[RFID] ERROR!");
    lcd.clear();
    lcd.print("RFID ERROR!");
    while(true) delay(1000);
  }
  
  Serial.print("[RFID] OK! Version: 0x");
  Serial.println(version, HEX);
  lcd.clear();
  lcd.print("RFID OK!");
  delay(1000);
  
  // Start WebSocket server
  Serial.println("[WebSocket] Starting...");
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  Serial.print("[WebSocket] Server started on port ");
  Serial.println(WS_PORT);
  
  // Setup HTTP endpoints
  Serial.println("[HTTP] Setting up endpoints...");
  
  server.on("/trigger-capture", HTTP_POST, []() {
    Serial.println("[HTTP] Received /trigger-capture request");
    
    // Đọc student_id từ request body
    if (server.hasArg("plain")) {
      String body = server.arg("plain");
      Serial.print("[HTTP] Body: ");
      Serial.println(body);
      
      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, body);
      
      if (!error && doc.containsKey("student_id")) {
        currentStudentId = doc["student_id"].as<String>();
        Serial.print("[HTTP] Student ID from app: ");
        Serial.println(currentStudentId);
      }
    }
    
    // Kiểm tra có student_id không
    if (currentStudentId.length() == 0) {
      Serial.println("[HTTP] No student_id provided");
      server.send(400, "application/json", "{\"error\":\"No student_id provided\"}");
      return;
    }
    
    server.send(200, "application/json", "{\"success\":true}");
    
    // Trigger camera capture
    captureBarcode();
  });
  
  server.on("/status", HTTP_GET, []() {
    StaticJsonDocument<200> doc;
    doc["status"] = "online";
    doc["device_id"] = DEVICE_ID;
    doc["student_id"] = currentStudentId;
    doc["is_processing"] = isProcessing;
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
  });
  
  server.on("/reset-session", HTTP_POST, []() {
    Serial.println("[HTTP] Received /reset-session request");
    
    // Reset state
    isProcessing = false;
    lastUID = "";
    currentStudentId = "";
    
    // Display ready
    displayReady();
    
    server.send(200, "application/json", "{\"success\":true}");
    Serial.println("[HTTP] Session reset complete");
  });
  
  server.begin();
  Serial.println("[HTTP] Server started on port 80");
  
  // Ready
  Serial.println("\n[SYSTEM] Ready!");
  Serial.println("========================================\n");
  
  // Debug info
  Serial.print("[DEBUG] ESP32 IP: ");
  Serial.println(WiFi.localIP());
  Serial.print("[DEBUG] Gateway: ");
  Serial.println(WiFi.gatewayIP());
  Serial.print("[DEBUG] Subnet: ");
  Serial.println(WiFi.subnetMask());
  Serial.print("[DEBUG] DNS: ");
  Serial.println(WiFi.dnsIP());
  Serial.println();
  
  displayReady();
  
  lastHeartbeat = millis();
}

// ============================================
// MAIN LOOP
// ============================================

void loop() {
  server.handleClient();
  webSocket.loop();
  
  // Check Button (debounce 500ms)
  if (digitalRead(BUTTON_PIN) == LOW && !buttonPressed && (millis() - lastButtonPress > 500)) {
    buttonPressed = true;
    lastButtonPress = millis();
    
    Serial.println("[BUTTON] Reset button pressed!");
    
    // Reset state
    isProcessing = false;
    lastUID = "";
    currentStudentId = "";
    
    // Display ready
    lcd.clear();
    lcd.print("Reset!");
    delay(500);
    displayReady();
  }
  
  if (digitalRead(BUTTON_PIN) == HIGH) {
    buttonPressed = false;
  }
  
  // Check WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Disconnected! Reconnecting...");
    WiFi.reconnect();
    delay(5000);
    return;
  }
  
  // Debug: In IP mỗi 30s
  static unsigned long lastIPPrint = 0;
  if (millis() - lastIPPrint > 30000) {
    Serial.print("[DEBUG] ESP32 IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("[DEBUG] Gateway: ");
    Serial.println(WiFi.gatewayIP());
    lastIPPrint = millis();
  }
  
  // Heartbeat
  if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }
  
  // KHÔNG tự động reset timeout nữa
  // Chỉ reset khi app gọi /reset-session hoặc nhấn nút reset
  
  // Check RFID
  if (!isProcessing && (millis() - lastRFIDCheck > RFID_SCAN_INTERVAL)) {
    lastRFIDCheck = millis();
    
    if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
      String cardUID = getCardUID();
      
      if (cardUID == lastUID) {
        rfid.PICC_HaltA();
        rfid.PCD_StopCrypto1();
        return;
      }
      
      lastUID = cardUID;
      isProcessing = true;
      
      Serial.print("[RFID] Card: ");
      Serial.println(cardUID);
      
      lcd.clear();
      lcd.print("Processing...");
      
      // Scan student card
      scanStudentCard(cardUID);
      
      rfid.PICC_HaltA();
      rfid.PCD_StopCrypto1();
      
      lastDisplayUpdate = millis();
    }
  }
  
  delay(10);
}

// ============================================
// RFID FUNCTIONS
// ============================================

String getCardUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// ============================================
// CAMERA HTTP FUNCTIONS
// ============================================

bool testCameraConnection() {
  String url = String(ESP32_CAM_IP) + "/status";
  
  WiFiClient client;
  http.begin(client, url);
  http.addHeader("Connection", "close");
  http.setReuse(false);
  http.setTimeout(3000);
  
  int httpCode = http.GET();
  http.end();
  
  return (httpCode == 200);
}

void captureBarcode() {
  Serial.println("[Camera] Triggering barcode capture via HTTP...");
  
  lcd.clear();
  lcd.print("Chup barcode...");
  
  // Gửi HTTP request tới ESP32-CAM để trigger chụp
  String url = String(ESP32_CAM_IP) + "/capture";
  
  WiFiClient client;
  http.begin(client, url);
  http.addHeader("Connection", "close");
  http.setReuse(false);
  http.setTimeout(5000);
  
  // Gửi student_id trong body
  StaticJsonDocument<100> doc;
  doc["student_id"] = currentStudentId;
  
  String payload;
  serializeJson(doc, payload);
  
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.POST(payload);
  
  if (httpCode == 200) {
    Serial.println("[Camera] Capture triggered successfully!");
    
    lcd.clear();
    lcd.print("Dang xu ly...");
    lcd.setCursor(0, 1);
    lcd.print("Vui long doi");
    
    // Đợi ESP32-CAM chụp, decode và backend lưu vào DB (8-10 giây)
    delay(8000);
    
    // Poll backend để lấy kết quả
    checkBookResult();
  } else {
    Serial.print("[Camera] Failed to trigger capture: ");
    Serial.println(httpCode);
    
    lcd.clear();
    lcd.print("Camera Error");
    lcd.setCursor(0, 1);
    lcd.print("Try again");
    delay(1500);
    
    // Reset về ready để có thể thử lại
    displayReady();
    isProcessing = false;
  }
  
  http.end();
}

void checkBookResult() {
  Serial.println("[Backend] Checking for book scan result...");
  
  lcd.clear();
  lcd.print("Kiem tra...");
  
  // Gọi API để lấy kết quả scan gần nhất
  String url = String(API_BASE_URL) + "/api/iot/last-scan-result?student_id=" + currentStudentId;
  
  Serial.print("[Backend] URL: ");
  Serial.println(url);
  
  // Tạo HTTPClient mới
  HTTPClient httpClient;
  WiFiClient client;
  
  if (!httpClient.begin(client, url)) {
    Serial.println("[Backend] http.begin() failed!");
    displayError("Loi ket noi");
    delay(2000);
    displayReady();
    isProcessing = false;
    return;
  }
  
  httpClient.setTimeout(10000);
  
  int httpCode = httpClient.GET();
  
  Serial.print("[Backend] HTTP code: ");
  Serial.println(httpCode);
  
  if (httpCode == HTTP_CODE_OK) {
    String response = httpClient.getString();
    
    Serial.print("[Backend] Response length: ");
    Serial.println(response.length());
    Serial.print("[Backend] Response: ");
    Serial.println(response);
    
    httpClient.end();
    
    // Check response length
    if (response.length() == 0) {
      Serial.println("[Backend] Empty response!");
      displayError("Loi du lieu");
      delay(2000);
      displayReady();
      isProcessing = false;
      return;
    }
    
    StaticJsonDocument<512> responseDoc;
    DeserializationError error = deserializeJson(responseDoc, response);
    
    if (error) {
      Serial.print("[Backend] JSON parse error: ");
      Serial.println(error.c_str());
      displayError("Loi du lieu");
      delay(2000);
      displayReady();
      isProcessing = false;
      return;
    }
    
    if (responseDoc["success"]) {
      String bookCode = responseDoc["book"]["book_code"].as<String>();
      String title = responseDoc["book"]["title"].as<String>();
      
      Serial.print("[Backend] Book: ");
      Serial.print(bookCode);
      Serial.print(" - ");
      Serial.println(title);
      
      displayBook(title, bookCode);
      
      // Send to app
      sendToApp("book_scanned", responseDoc);
      
      delay(5000);
      
      // Reset về ready sau khi quét sách thành công
      displayReady();
      isProcessing = false;
      currentStudentId = "";
      lastUID = "";
    } else {
      Serial.println("[Backend] No book found in response");
      displayError("Chua co sach");
      delay(2000);
      
      // Quay lại trạng thái chờ quét sách
      lcd.clear();
      lcd.print("Cho quet sach");
    }
  } else {
    Serial.print("[Backend] Error: ");
    Serial.println(httpClient.errorToString(httpCode));
    displayError("Loi ket noi");
    delay(2000);
    
    // Quay lại trạng thái chờ quét sách
    lcd.clear();
    lcd.print("Cho quet sach");
  }
  
  httpClient.end();
}

// ============================================
// API FUNCTIONS
// ============================================

void scanStudentCard(String cardUID) {
  String url = String(API_BASE_URL) + String(API_SCAN_STUDENT);
  
  Serial.println("\n========== API DEBUG ==========");
  Serial.print("[API] WiFi Status: ");
  Serial.println(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected");
  Serial.print("[API] WiFi RSSI: ");
  Serial.println(WiFi.RSSI());
  Serial.print("[API] Local IP: ");
  Serial.println(WiFi.localIP());
  Serial.print("[API] Gateway: ");
  Serial.println(WiFi.gatewayIP());
  Serial.print("[API] Calling: ");
  Serial.println(url);
  
  // Check WiFi trước khi gửi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[API] WiFi disconnected! Reconnecting...");
    WiFi.reconnect();
    delay(2000);
    
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[API] WiFi reconnect failed!");
      displayError("WiFi Error");
      delay(2000);
      displayReady();
      isProcessing = false;
      return;
    }
  }
  
  StaticJsonDocument<100> doc;
  doc["card_uid"] = cardUID;
  
  String payload;
  serializeJson(doc, payload);
  
  Serial.print("[API] Payload: ");
  Serial.println(payload);
  Serial.print("[API] Free Heap: ");
  Serial.println(ESP.getFreeHeap());
  
  // Retry với delay tăng dần
  int httpCode = -1;
  int maxRetries = 3;
  
  for (int retry = 0; retry < maxRetries; retry++) {
    if (retry > 0) {
      Serial.print("[API] Retry ");
      Serial.print(retry + 1);
      Serial.print("/");
      Serial.println(maxRetries);
      
      // Delay tăng dần: 500ms, 1000ms, 2000ms
      int delayMs = 500 * (1 << retry);
      delay(delayMs);
    }
    
    // Tạo HTTPClient mới mỗi lần retry
    HTTPClient httpClient;
    WiFiClient client;
    
    if (!httpClient.begin(client, url)) {
      Serial.println("[API] http.begin() failed!");
      continue;
    }
    
    httpClient.addHeader("Content-Type", "application/json");
    httpClient.setTimeout(10000);
    
    Serial.println("[API] Sending POST...");
    httpCode = httpClient.POST(payload);
    
    Serial.print("[API] Response code: ");
    Serial.println(httpCode);
    
    if (httpCode > 0) {
      Serial.println("[API] Success!");
      
      // Đọc response ngay lập tức
      if (httpCode == HTTP_CODE_OK) {
        String response = httpClient.getString();
        
        Serial.print("[API] Response length: ");
        Serial.println(response.length());
        Serial.print("[API] Response: ");
        Serial.println(response);
        
        httpClient.end();
        
        if (response.length() > 0) {
          // Parse JSON
          StaticJsonDocument<512> responseDoc;
          DeserializationError error = deserializeJson(responseDoc, response);
          
          if (!error && responseDoc["success"]) {
            String name = responseDoc["reader"]["name"].as<String>();
            currentStudentId = responseDoc["reader"]["student_id"].as<String>();
            
            Serial.print("[API] Student: ");
            Serial.println(name);
            
            // Hiển thị "Đang chờ quét sách" trên LCD
            lcd.clear();
            lcd.print(removeVietnameseTones(name).substring(0, LCD_COLS));
            lcd.setCursor(0, 1);
            lcd.print("Cho quet sach");
            
            sendToApp("student_scanned", responseDoc);
            
            // GIỮ isProcessing = true để không cho quét thẻ khác
            // Chỉ reset khi app gọi /reset-session
            Serial.println("[API] Waiting for book scan...");
            
            return;  // Success, exit function
          } else {
            Serial.println("[API] Card not found");
            displayError("Not found");
            delay(2000);
            displayReady();
            isProcessing = false;
            return;
          }
        } else {
          Serial.println("[API] Empty response!");
        }
      }
      
      httpClient.end();
      break;
    } else {
      Serial.print("[API] Error: ");
      Serial.println(httpClient.errorToString(httpCode));
      httpClient.end();
      
      // Nếu là lỗi connection, check WiFi
      if (httpCode == HTTPC_ERROR_CONNECTION_REFUSED || 
          httpCode == HTTPC_ERROR_CONNECTION_LOST) {
        Serial.println("[API] Checking WiFi...");
        if (WiFi.status() != WL_CONNECTED) {
          Serial.println("[API] WiFi lost! Reconnecting...");
          WiFi.reconnect();
          delay(2000);
        }
      }
    }
  }
  
  Serial.println("==============================\n");
  
  // If we reach here, all retries failed
  Serial.println("[API] All retries failed!");
  lcd.clear();
  lcd.print("Connection fail");
  lcd.setCursor(0, 1);
  lcd.print("Check network");
  delay(2000);
  displayReady();
  isProcessing = false;
}

// Không cần hàm này nữa vì ESP32-CAM tự POST lên backend

void sendHeartbeat() {
  String url = String(API_BASE_URL) + "/api/iot/heartbeat";
  WiFiClient client;
  http.begin(client, url);
  http.addHeader("Connection", "close");
  http.setReuse(false);
  http.setTimeout(5000);
  http.GET();
  http.end();
}

// ============================================
// WEBSOCKET FUNCTIONS
// ============================================

void webSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_DISCONNECTED:
      Serial.printf("[WS] Client %u disconnected\n", num);
      if (wsClientId == num) wsClientId = 255;
      break;
      
    case WStype_CONNECTED: {
      IPAddress ip = webSocket.remoteIP(num);
      Serial.printf("[WS] Client %u connected from %s\n", num, ip.toString().c_str());
      wsClientId = num;
      
      // Send welcome message
      StaticJsonDocument<100> doc;
      doc["type"] = "connected";
      doc["device_id"] = DEVICE_ID;
      String msg;
      serializeJson(doc, msg);
      webSocket.sendTXT(num, msg);
      break;
    }
    
    case WStype_TEXT:
      Serial.printf("[WS] Message from %u: %s\n", num, payload);
      handleWebSocketMessage(num, (char*)payload);
      break;
  }
}

void handleWebSocketMessage(uint8_t num, char* payload) {
  StaticJsonDocument<512> doc;
  DeserializationError error = deserializeJson(doc, payload);
  
  if (error) return;
  
  String type = doc["type"].as<String>();
  
  if (type == "trigger_capture") {
    captureBarcode();
  }
}

void sendToApp(const char* eventType, JsonDocument& data) {
  if (wsClientId == 255) return;
  
  StaticJsonDocument<1024> doc;
  doc["type"] = eventType;
  doc["data"] = data;
  
  String msg;
  serializeJson(doc, msg);
  webSocket.sendTXT(wsClientId, msg);
}

// Không cần hàm này nữa vì không nhận ảnh qua UART

// ============================================
// LCD FUNCTIONS
// ============================================

void displayReady() {
  lcd.clear();
  lcd.print("Ready!");
  lcd.setCursor(0, 1);
  lcd.print("Scan card");
}

// Hàm bỏ dấu tiếng Việt
String removeVietnameseTones(String str) {
  // Chuyển UTF-8 Vietnamese sang ASCII
  str.replace("á", "a"); str.replace("à", "a"); str.replace("ả", "a"); 
  str.replace("ã", "a"); str.replace("ạ", "a");
  str.replace("ă", "a"); str.replace("ắ", "a"); str.replace("ằ", "a"); 
  str.replace("ẳ", "a"); str.replace("ẵ", "a"); str.replace("ặ", "a");
  str.replace("â", "a"); str.replace("ấ", "a"); str.replace("ầ", "a"); 
  str.replace("ẩ", "a"); str.replace("ẫ", "a"); str.replace("ậ", "a");
  
  str.replace("Á", "A"); str.replace("À", "A"); str.replace("Ả", "A"); 
  str.replace("Ã", "A"); str.replace("Ạ", "A");
  str.replace("Ă", "A"); str.replace("Ắ", "A"); str.replace("Ằ", "A"); 
  str.replace("Ẳ", "A"); str.replace("Ẵ", "A"); str.replace("Ặ", "A");
  str.replace("Â", "A"); str.replace("Ấ", "A"); str.replace("Ầ", "A"); 
  str.replace("Ẩ", "A"); str.replace("Ẫ", "A"); str.replace("Ậ", "A");
  
  str.replace("đ", "d"); str.replace("Đ", "D");
  
  str.replace("é", "e"); str.replace("è", "e"); str.replace("ẻ", "e"); 
  str.replace("ẽ", "e"); str.replace("ẹ", "e");
  str.replace("ê", "e"); str.replace("ế", "e"); str.replace("ề", "e"); 
  str.replace("ể", "e"); str.replace("ễ", "e"); str.replace("ệ", "e");
  
  str.replace("É", "E"); str.replace("È", "E"); str.replace("Ẻ", "E"); 
  str.replace("Ẽ", "E"); str.replace("Ẹ", "E");
  str.replace("Ê", "E"); str.replace("Ế", "E"); str.replace("Ề", "E"); 
  str.replace("Ể", "E"); str.replace("Ễ", "E"); str.replace("Ệ", "E");
  
  str.replace("í", "i"); str.replace("ì", "i"); str.replace("ỉ", "i"); 
  str.replace("ĩ", "i"); str.replace("ị", "i");
  str.replace("Í", "I"); str.replace("Ì", "I"); str.replace("Ỉ", "I"); 
  str.replace("Ĩ", "I"); str.replace("Ị", "I");
  
  str.replace("ó", "o"); str.replace("ò", "o"); str.replace("ỏ", "o"); 
  str.replace("õ", "o"); str.replace("ọ", "o");
  str.replace("ô", "o"); str.replace("ố", "o"); str.replace("ồ", "o"); 
  str.replace("ổ", "o"); str.replace("ỗ", "o"); str.replace("ộ", "o");
  str.replace("ơ", "o"); str.replace("ớ", "o"); str.replace("ờ", "o"); 
  str.replace("ở", "o"); str.replace("ỡ", "o"); str.replace("ợ", "o");
  
  str.replace("Ó", "O"); str.replace("Ò", "O"); str.replace("Ỏ", "O"); 
  str.replace("Õ", "O"); str.replace("Ọ", "O");
  str.replace("Ô", "O"); str.replace("Ố", "O"); str.replace("Ồ", "O"); 
  str.replace("Ổ", "O"); str.replace("Ỗ", "O"); str.replace("Ộ", "O");
  str.replace("Ơ", "O"); str.replace("Ớ", "O"); str.replace("Ờ", "O"); 
  str.replace("Ở", "O"); str.replace("Ỡ", "O"); str.replace("Ợ", "O");
  
  str.replace("ú", "u"); str.replace("ù", "u"); str.replace("ủ", "u"); 
  str.replace("ũ", "u"); str.replace("ụ", "u");
  str.replace("ư", "u"); str.replace("ứ", "u"); str.replace("ừ", "u"); 
  str.replace("ử", "u"); str.replace("ữ", "u"); str.replace("ự", "u");
  
  str.replace("Ú", "U"); str.replace("Ù", "U"); str.replace("Ủ", "U"); 
  str.replace("Ũ", "U"); str.replace("Ụ", "U");
  str.replace("Ư", "U"); str.replace("Ứ", "U"); str.replace("Ừ", "U"); 
  str.replace("Ử", "U"); str.replace("Ữ", "U"); str.replace("Ự", "U");
  
  str.replace("ý", "y"); str.replace("ỳ", "y"); str.replace("ỷ", "y"); 
  str.replace("ỹ", "y"); str.replace("ỵ", "y");
  str.replace("Ý", "Y"); str.replace("Ỳ", "Y"); str.replace("Ỷ", "Y"); 
  str.replace("Ỹ", "Y"); str.replace("Ỵ", "Y");
  
  return str;
}

void displayReader(String name, String studentId) {
  lcd.clear();
  
  // Bỏ dấu tiếng Việt
  name = removeVietnameseTones(name);
  
  // Cắt tên nếu quá dài (LCD 16 ký tự)
  if (name.length() > LCD_COLS) {
    name = name.substring(0, LCD_COLS);
  }
  
  lcd.print(name);
  lcd.setCursor(0, 1);
  lcd.print("MSSV:");  // Đổi từ "ID:" thành "MSSV:"
  lcd.print(studentId);
}

void displayBook(String title, String bookCode) {
  lcd.clear();
  
  // Bỏ dấu tiếng Việt
  title = removeVietnameseTones(title);
  
  // Cắt tên nếu quá dài (LCD 16 ký tự)
  if (title.length() > LCD_COLS) {
    title = title.substring(0, LCD_COLS);
  }
  
  lcd.print(title);
  lcd.setCursor(0, 1);
  lcd.print("Ma:");
  lcd.print(bookCode);
}

void displayError(String error) {
  lcd.clear();
  lcd.print("ERROR!");
  lcd.setCursor(0, 1);
  lcd.print(error);
}
