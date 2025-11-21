/*
 * ESP32-S3-CAM IoT Station - Arduino Version
 * Trạm Quét Thẻ & Sách Tự động
 * 
 * Hardware:
 * - ESP32-S3-CAM (with USB-C built-in)
 * - RC522 RFID Reader
 * - LCD 16x2 I2C
 * - Power Bank
 * 
 * Author: Kiro AI Assistant
 * Date: 2024
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <MFRC522.h>
#include <SPI.h>
#include <LiquidCrystal_I2C.h>

// ============================================
// CONFIGURATION - CHỈNH SỬA PHẦN NÀY
// ============================================

// WiFi credentials
const char* WIFI_SSID = "VDK IOT";        // ← Sửa đây
const char* WIFI_PASSWORD = "20242025x"; // ← Sửa đây

// API endpoint
const char* API_BASE_URL = "http://172.20.10.5:3000"; // ← Sửa đây
const char* API_SCAN_STUDENT = "/api/iot/scan-student-card";
const char* API_SCAN_BOOK = "/api/iot/scan-book-barcode";
const char* API_HEARTBEAT = "/api/iot/heartbeat";

// Device info (cố định - chỉ 1 trạm)
const char* DEVICE_ID = "IOT_STATION_01";

// Pin configuration for ESP32-S3-CAM
#define RFID_CS_PIN 10
#define RFID_RST_PIN 9
#define RFID_SCK_PIN 12
#define RFID_MOSI_PIN 11
#define RFID_MISO_PIN 13

#define LCD_ADDRESS 0x27  // I2C Scanner đã tìm thấy 0x27
#define LCD_COLS 16
#define LCD_ROWS 2
#define LCD_SDA_PIN 4     // I2C SDA for ESP32-S3
#define LCD_SCL_PIN 5     // I2C SCL for ESP32-S3

#define SCAN_BUTTON_PIN 0  // Boot button

// Timing
#define RFID_SCAN_INTERVAL 500
#define LCD_DISPLAY_TIMEOUT 5000
#define HEARTBEAT_INTERVAL 60000
#define WIFI_TIMEOUT 20000

// ============================================
// GLOBAL OBJECTS
// ============================================

MFRC522 rfid(RFID_CS_PIN, RFID_RST_PIN);
LiquidCrystal_I2C lcd(LCD_ADDRESS, LCD_COLS, LCD_ROWS);
HTTPClient http;

// State variables
unsigned long lastHeartbeat = 0;
unsigned long lastDisplayUpdate = 0;
unsigned long lastRFIDCheck = 0;
bool isProcessing = false;
String lastUID = "";

// ============================================
// SETUP
// ============================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n\n========================================");
  Serial.println("  ESP32-S3-CAM IoT Station");
  Serial.println("  Tram Quet The & Sach Tu dong");
  Serial.println("========================================");
  Serial.print("Device ID: ");
  Serial.println(DEVICE_ID);
  Serial.println("========================================\n");
  
  // Initialize button
  pinMode(SCAN_BUTTON_PIN, INPUT_PULLUP);
  
  // Initialize LCD (sẽ init lại sau WiFi)
  Serial.println("[INIT] Initializing LCD...");
  Wire.begin(LCD_SDA_PIN, LCD_SCL_PIN);
  delay(500);
  
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Starting...");
  
  Serial.println("[LCD] Initial display");
  delay(1000);
  
  // Connect WiFi
  Serial.println("[INIT] Connecting to WiFi...");
  lcd.clear();
  delay(50);
  lcd.setCursor(0, 0);
  lcd.print("WiFi...");
  delay(50);
  lcd.setCursor(0, 1);
  lcd.print(WIFI_SSID);
  delay(100);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  unsigned long startTime = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - startTime > WIFI_TIMEOUT) {
      Serial.println("[ERROR] WiFi connection timeout!");
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("LOI WiFi!");
      while(true) delay(1000);
    }
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nWiFi connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  
  // Khởi tạo lại LCD sau WiFi (WiFi có thể làm I2C bị lỗi)
  Serial.println("[LCD] Re-initializing after WiFi...");
  Wire.begin(LCD_SDA_PIN, LCD_SCL_PIN);
  delay(100);
  lcd.init();
  lcd.backlight();
  lcd.clear();
  
  lcd.setCursor(0, 0);
  lcd.print("WiFi OK!");
  lcd.setCursor(0, 1);
  lcd.print(WiFi.localIP());
  delay(2000);
  
  // Initialize SPI
  SPI.begin(RFID_SCK_PIN, RFID_MISO_PIN, RFID_MOSI_PIN, RFID_CS_PIN);
  
  // Initialize RFID
  Serial.println("[INIT] Initializing RFID reader...");
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Khoi tao RFID...");
  
  rfid.PCD_Init();
  
  byte version = rfid.PCD_ReadRegister(rfid.VersionReg);
  if (version == 0x00 || version == 0xFF) {
    Serial.println("[ERROR] RFID reader not found!");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("LOI RFID!");
    while(true) delay(1000);
  }
  
  Serial.print("RFID reader initialized. Version: 0x");
  Serial.println(version, HEX);
  
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("RFID OK!");
  delay(1000);
  
  // Send initial heartbeat
  Serial.println("[INIT] Sending initial heartbeat...");
  sendHeartbeat();
  lastHeartbeat = millis();
  
  // Ready
  Serial.println("\n[SYSTEM] System ready!");
  Serial.println("========================================\n");
  displayReady();
}

// ============================================
// MAIN LOOP
// ============================================

void loop() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected! Reconnecting...");
    WiFi.reconnect();
    delay(5000);
    return;
  }
  
  // Send heartbeat
  if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
    Serial.println("[HEARTBEAT] Sending...");
    if (sendHeartbeat()) {
      Serial.println("[HEARTBEAT] OK");
    } else {
      Serial.println("[HEARTBEAT] Failed");
    }
    lastHeartbeat = millis();
  }
  
  // Reset display after timeout
  if (isProcessing && (millis() - lastDisplayUpdate > LCD_DISPLAY_TIMEOUT)) {
    isProcessing = false;
    displayReady();
    Serial.println("[SYSTEM] Ready for next scan");
  }
  
  // Check RFID card
  if (!isProcessing && (millis() - lastRFIDCheck > RFID_SCAN_INTERVAL)) {
    lastRFIDCheck = millis();
    
    if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
      String cardUID = getCardUID();
      
      // Debounce: skip if same card
      if (cardUID == lastUID) {
        rfid.PICC_HaltA();
        rfid.PCD_StopCrypto1();
        return;
      }
      
      lastUID = cardUID;
      isProcessing = true;
      
      Serial.print("[RFID] Card detected: ");
      Serial.println(cardUID);
      
      // Display processing
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Dang xu ly...");
      
      // Send to API
      scanStudentCard(cardUID);
      
      // Halt card
      rfid.PICC_HaltA();
      rfid.PCD_StopCrypto1();
      
      lastDisplayUpdate = millis();
    }
  }
  
  delay(100);
}

// ============================================
// RFID FUNCTIONS
// ============================================

String getCardUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) {
      uid += "0";
    }
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

// ============================================
// API FUNCTIONS
// ============================================

void scanStudentCard(String cardUID) {
  String url = String(API_BASE_URL) + String(API_SCAN_STUDENT);
  
  Serial.print("[API] POST ");
  Serial.println(url);
  
  // Create JSON payload (đơn giản)
  StaticJsonDocument<100> doc;
  doc["card_uid"] = cardUID;
  
  String payload;
  serializeJson(doc, payload);
  
  Serial.print("[API] Payload: ");
  Serial.println(payload);
  
  // Send request
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);
  
  int httpCode = http.POST(payload);
  
  if (httpCode > 0) {
    Serial.print("[API] Response code: ");
    Serial.println(httpCode);
    
    if (httpCode == HTTP_CODE_OK) {
      String response = http.getString();
      Serial.print("[API] Response: ");
      Serial.println(response);
      
      // Parse response
      StaticJsonDocument<512> responseDoc;
      DeserializationError error = deserializeJson(responseDoc, response);
      
      if (!error) {
        bool success = responseDoc["success"];
        
        if (success) {
          // Success - display reader info
          String name = responseDoc["reader"]["name"].as<String>();
          String studentId = responseDoc["reader"]["student_id"].as<String>();
          
          Serial.println("[API] Reader found:");
          Serial.print("  Name: ");
          Serial.println(name);
          Serial.print("  Student ID: ");
          Serial.println(studentId);
          
          displayReader(name, studentId);
        } else {
          // Error
          String error = responseDoc["error"].as<String>();
          Serial.print("[API] Error: ");
          Serial.println(error);
          
          displayError("Khong tim thay");
        }
      }
    }
  } else {
    Serial.print("[API] Error: ");
    Serial.println(http.errorToString(httpCode));
    displayError("Loi ket noi");
  }
  
  http.end();
}

bool sendHeartbeat() {
  String url = String(API_BASE_URL) + String(API_HEARTBEAT);
  
  http.begin(url);
  http.setTimeout(5000);
  
  int httpCode = http.GET();  // Đơn giản hóa - chỉ GET
  bool success = (httpCode == HTTP_CODE_OK);
  
  http.end();
  return success;
}

// ============================================
// LCD DISPLAY FUNCTIONS
// ============================================

void displayReady() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("San sang!");
  lcd.setCursor(0, 1);
  lcd.print("Quet the");
}

void displayReader(String name, String studentId) {
  lcd.clear();
  
  // Chuyển tiếng Việt sang không dấu
  name = removeVietnameseTones(name);
  
  // Truncate if too long
  if (name.length() > LCD_COLS) {
    name = name.substring(0, LCD_COLS);
  }
  
  lcd.setCursor(0, 0);
  lcd.print(name);
  
  lcd.setCursor(0, 1);
  lcd.print("MSSV:");
  lcd.print(studentId);
  
  Serial.println("[LCD] Displaying reader info");
}

// Hàm chuyển tiếng Việt sang không dấu
String removeVietnameseTones(String str) {
  // Chữ thường
  str.replace("á", "a"); str.replace("à", "a"); str.replace("ả", "a"); 
  str.replace("ã", "a"); str.replace("ạ", "a");
  str.replace("ă", "a"); str.replace("ắ", "a"); str.replace("ằ", "a"); 
  str.replace("ẳ", "a"); str.replace("ẵ", "a"); str.replace("ặ", "a");
  str.replace("â", "a"); str.replace("ấ", "a"); str.replace("ầ", "a"); 
  str.replace("ẩ", "a"); str.replace("ẫ", "a"); str.replace("ậ", "a");
  
  str.replace("é", "e"); str.replace("è", "e"); str.replace("ẻ", "e"); 
  str.replace("ẽ", "e"); str.replace("ẹ", "e");
  str.replace("ê", "e"); str.replace("ế", "e"); str.replace("ề", "e"); 
  str.replace("ể", "e"); str.replace("ễ", "e"); str.replace("ệ", "e");
  
  str.replace("í", "i"); str.replace("ì", "i"); str.replace("ỉ", "i"); 
  str.replace("ĩ", "i"); str.replace("ị", "i");
  
  str.replace("ó", "o"); str.replace("ò", "o"); str.replace("ỏ", "o"); 
  str.replace("õ", "o"); str.replace("ọ", "o");
  str.replace("ô", "o"); str.replace("ố", "o"); str.replace("ồ", "o"); 
  str.replace("ổ", "o"); str.replace("ỗ", "o"); str.replace("ộ", "o");
  str.replace("ơ", "o"); str.replace("ớ", "o"); str.replace("ờ", "o"); 
  str.replace("ở", "o"); str.replace("ỡ", "o"); str.replace("ợ", "o");
  
  str.replace("ú", "u"); str.replace("ù", "u"); str.replace("ủ", "u"); 
  str.replace("ũ", "u"); str.replace("ụ", "u");
  str.replace("ư", "u"); str.replace("ứ", "u"); str.replace("ừ", "u"); 
  str.replace("ử", "u"); str.replace("ữ", "u"); str.replace("ự", "u");
  
  str.replace("ý", "y"); str.replace("ỳ", "y"); str.replace("ỷ", "y"); 
  str.replace("ỹ", "y"); str.replace("ỵ", "y");
  
  str.replace("đ", "d");
  
  // Chữ hoa
  str.replace("Á", "A"); str.replace("À", "A"); str.replace("Ả", "A"); 
  str.replace("Ã", "A"); str.replace("Ạ", "A");
  str.replace("Ă", "A"); str.replace("Ắ", "A"); str.replace("Ằ", "A"); 
  str.replace("Ẳ", "A"); str.replace("Ẵ", "A"); str.replace("Ặ", "A");
  str.replace("Â", "A"); str.replace("Ấ", "A"); str.replace("Ầ", "A"); 
  str.replace("Ẩ", "A"); str.replace("Ẫ", "A"); str.replace("Ậ", "A");
  
  str.replace("É", "E"); str.replace("È", "E"); str.replace("Ẻ", "E"); 
  str.replace("Ẽ", "E"); str.replace("Ẹ", "E");
  str.replace("Ê", "E"); str.replace("Ế", "E"); str.replace("Ề", "E"); 
  str.replace("Ể", "E"); str.replace("Ễ", "E"); str.replace("Ệ", "E");
  
  str.replace("Í", "I"); str.replace("Ì", "I"); str.replace("Ỉ", "I"); 
  str.replace("Ĩ", "I"); str.replace("Ị", "I");
  
  str.replace("Ó", "O"); str.replace("Ò", "O"); str.replace("Ỏ", "O"); 
  str.replace("Õ", "O"); str.replace("Ọ", "O");
  str.replace("Ô", "O"); str.replace("Ố", "O"); str.replace("Ồ", "O"); 
  str.replace("Ổ", "O"); str.replace("Ỗ", "O"); str.replace("Ộ", "O");
  str.replace("Ơ", "O"); str.replace("Ớ", "O"); str.replace("Ờ", "O"); 
  str.replace("Ở", "O"); str.replace("Ỡ", "O"); str.replace("Ợ", "O");
  
  str.replace("Ú", "U"); str.replace("Ù", "U"); str.replace("Ủ", "U"); 
  str.replace("Ũ", "U"); str.replace("Ụ", "U");
  str.replace("Ư", "U"); str.replace("Ứ", "U"); str.replace("Ừ", "U"); 
  str.replace("Ử", "U"); str.replace("Ữ", "U"); str.replace("Ự", "U");
  
  str.replace("Ý", "Y"); str.replace("Ỳ", "Y"); str.replace("Ỷ", "Y"); 
  str.replace("Ỹ", "Y"); str.replace("Ỵ", "Y");
  
  str.replace("Đ", "D");
  
  return str;
}

void displayError(String error) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("LOI!");
  lcd.setCursor(0, 1);
  lcd.print("Khong tim thay");
  
  Serial.print("[LCD] Error: ");
  Serial.println(error);
}
