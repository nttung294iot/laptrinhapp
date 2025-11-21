/*
 * ESP32-CAM - HTTP Mode Only
 * Nhận trigger từ ESP32-S3 qua HTTP
 * Chụp ảnh barcode và POST trực tiếp lên backend
 * 
 * Thuật toán Multi-shot:
 * 1. Chụp 3 ảnh với exposure khác nhau
 * 2. Đánh giá độ sắc nét (file size heuristic)
 * 3. Chọn ảnh rõ nhất
 * 4. POST lên backend qua HTTP
 */

#include "esp_camera.h"
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>

// ============================================
// CAMERA PINS (AI-Thinker ESP32-CAM)
// ============================================

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22
#define LED_GPIO_NUM       4

// ============================================
// CONFIGURATION
// ============================================

// WiFi - SỬA CHO ĐÚNG VỚI WIFI CỦA BẠN!
const char* WIFI_SSID = "VDK IOT";
const char* WIFI_PASSWORD = "20242025x";

// Backend API - SỬA IP NÀY CHO ĐÚNG!
const char* BACKEND_URL = "http://172.20.10.5:3000/api/iot/scan-book-image";

// Multi-shot configuration
#define NUM_SHOTS 3

// ============================================
// GLOBAL OBJECTS
// ============================================

WebServer server(80);
HTTPClient http;

bool isCapturing = false;
String lastStudentId = "";

// ============================================
// SETUP
// ============================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n========================================");
  Serial.println("  ESP32-CAM - HTTP Mode");
  Serial.println("========================================\n");
  
  // Initialize LED
  pinMode(LED_GPIO_NUM, OUTPUT);
  digitalWrite(LED_GPIO_NUM, LOW);
  
  // Initialize camera
  Serial.println("[Camera] Initializing...");
  if (!initCamera()) {
    Serial.println("[Camera] Init failed!");
    // Blink nhanh liên tục = Camera error
    while (true) {
      digitalWrite(LED_GPIO_NUM, HIGH);
      delay(100);
      digitalWrite(LED_GPIO_NUM, LOW);
      delay(100);
    }
  }
  Serial.println("[Camera] OK!");
  
  // Connect WiFi
  Serial.println("[WiFi] Connecting...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\n[WiFi] Connected!");
  Serial.print("[WiFi] IP: ");
  Serial.println(WiFi.localIP());
  
  // Setup HTTP server endpoints
  server.on("/capture", HTTP_POST, handleCapture);
  server.on("/status", HTTP_GET, handleStatus);
  
  server.begin();
  Serial.println("[HTTP] Server started on port 80");
  
  Serial.println("\n[SYSTEM] Ready!");
  Serial.println("========================================\n");
  
  // LED sáng 1s = Ready
  digitalWrite(LED_GPIO_NUM, HIGH);
  delay(1000);
  digitalWrite(LED_GPIO_NUM, LOW);
}

// ============================================
// MAIN LOOP
// ============================================

void loop() {
  server.handleClient();
  delay(10);
}

// ============================================
// CAMERA INITIALIZATION
// ============================================

bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.frame_size = FRAMESIZE_XGA;  // 1024x768 for barcode
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode = CAMERA_GRAB_LATEST;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 6;  // High quality
  config.fb_count = 2;
  
  // Init camera
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    return false;
  }
  
  // Configure sensor for barcode reading - OPTIMIZED
  sensor_t* s = esp_camera_sensor_get();
  if (s) {
    s->set_framesize(s, FRAMESIZE_XGA);
    s->set_quality(s, 5);           // Tăng quality (5 = better than 6)
    s->set_brightness(s, 1);        // Tăng brightness
    s->set_contrast(s, 2);          // Tăng contrast
    s->set_saturation(s, -1);       // Giảm saturation (better for barcode)
    s->set_sharpness(s, 2);         // Max sharpness
    s->set_denoise(s, 0);           // No denoise
    s->set_vflip(s, 1);
    s->set_hmirror(s, 1);
    s->set_wb_mode(s, 0);           // Auto white balance
    s->set_awb_gain(s, 1);
    s->set_aec2(s, 0);              // Disable AEC DSP
    s->set_ae_level(s, 1);          // Tăng AE level
    s->set_aec_value(s, 400);       // Tăng exposure
    s->set_gain_ctrl(s, 1);         // Enable AGC
    s->set_agc_gain(s, 5);          // Tăng gain
    s->set_gainceiling(s, (gainceiling_t)2);  // Tăng gain ceiling
    s->set_bpc(s, 0);
    s->set_wpc(s, 1);
    s->set_raw_gma(s, 1);
    s->set_lenc(s, 1);
    s->set_special_effect(s, 0);
  }
  
  return true;
}

// ============================================
// HTTP HANDLERS
// ============================================

void handleCapture() {
  if (isCapturing) {
    server.send(503, "text/plain", "Busy");
    return;
  }
  
  // Lấy student_id từ JSON body
  if (server.hasArg("plain")) {
    String body = server.arg("plain");
    // Parse JSON đơn giản
    int idx = body.indexOf("\"student_id\"");
    if (idx >= 0) {
      int start = body.indexOf("\"", idx + 13) + 1;
      int end = body.indexOf("\"", start);
      if (start > 0 && end > start) {
        lastStudentId = body.substring(start, end);
      }
    }
  }
  
  server.send(200, "text/plain", "Capturing...");
  
  // Chụp và gửi ảnh (async)
  captureBarcodeOptimized();
}

void handleStatus() {
  String status = "{\"status\":\"ok\",\"capturing\":" + String(isCapturing ? "true" : "false") + "}";
  server.send(200, "application/json", status);
}

// ============================================
// BARCODE CAPTURE - OPTIMIZED ALGORITHM
// ============================================

void captureBarcodeOptimized() {
  isCapturing = true;
  
  Serial.println("[Capture] Starting multi-shot...");
  
  // LED tắt - dùng ánh sáng tự nhiên
  digitalWrite(LED_GPIO_NUM, LOW);
  
  // Multi-shot with different exposures
  camera_fb_t* frames[NUM_SHOTS];
  float sharpness[NUM_SHOTS];
  int bestIndex = 0;
  float bestSharpness = 0;
  
  sensor_t* s = esp_camera_sensor_get();
  
  // Capture multiple shots with different AEC values (tăng exposure)
  int aecValues[] = {300, 450, 600};
  
  for (int i = 0; i < NUM_SHOTS; i++) {
    s->set_aec_value(s, aecValues[i]);
    delay(50);
    
    frames[i] = esp_camera_fb_get();
    
    if (frames[i]) {
      sharpness[i] = calculateSharpness(frames[i]);
      
      Serial.print("[Capture] Shot ");
      Serial.print(i + 1);
      Serial.print(": ");
      Serial.print(frames[i]->len);
      Serial.print(" bytes, sharpness: ");
      Serial.println(sharpness[i]);
      
      if (sharpness[i] > bestSharpness) {
        bestSharpness = sharpness[i];
        bestIndex = i;
      }
    } else {
      sharpness[i] = 0;
      Serial.print("[Capture] Shot ");
      Serial.print(i + 1);
      Serial.println(": FAILED");
    }
    
    delay(50);
  }
  
  // Check if we got any frames
  if (!frames[bestIndex]) {
    Serial.println("[Capture] All shots failed!");
    isCapturing = false;
    return;
  }
  
  Serial.print("[Capture] Best shot: ");
  Serial.print(bestIndex + 1);
  Serial.print(" (sharpness: ");
  Serial.print(bestSharpness);
  Serial.println(")");
  
  // Send best frame to backend
  sendImageToBackend(frames[bestIndex]);
  
  // Free all frames
  for (int i = 0; i < NUM_SHOTS; i++) {
    if (frames[i]) {
      esp_camera_fb_return(frames[i]);
    }
  }
  
  isCapturing = false;
}

// ============================================
// SHARPNESS CALCULATION
// ============================================

float calculateSharpness(camera_fb_t* fb) {
  if (!fb || fb->len == 0) return 0;
  
  // Heuristic: larger file size = more detail = sharper
  float expectedSize = 100000;  // ~100KB for XGA
  float sizeRatio = (float)fb->len / expectedSize;
  
  if (sizeRatio > 1.0) sizeRatio = 1.0;
  if (sizeRatio < 0.1) sizeRatio = 0.1;
  
  return sizeRatio;
}

// ============================================
// SEND IMAGE TO BACKEND
// ============================================

void sendImageToBackend(camera_fb_t* fb) {
  if (!fb || fb->len == 0) {
    Serial.println("[Backend] No image to send");
    return;
  }
  
  Serial.print("[Backend] Sending image (");
  Serial.print(fb->len);
  Serial.println(" bytes)...");
  
  // Create boundary
  String boundary = "----ESP32CAMBoundary";
  
  // Build multipart body parts
  String header = "--" + boundary + "\r\n";
  header += "Content-Disposition: form-data; name=\"student_id\"\r\n\r\n";
  header += lastStudentId + "\r\n";
  header += "--" + boundary + "\r\n";
  header += "Content-Disposition: form-data; name=\"image\"; filename=\"barcode.jpg\"\r\n";
  header += "Content-Type: image/jpeg\r\n\r\n";
  
  String footer = "\r\n--" + boundary + "--\r\n";
  
  uint32_t totalLength = header.length() + fb->len + footer.length();
  
  Serial.print("[Backend] Total size: ");
  Serial.println(totalLength);
  
  // Connect to server
  WiFiClient client;
  
  if (!client.connect("172.20.10.5", 3000)) {
    Serial.println("[Backend] Connection failed!");
    return;
  }
  
  Serial.println("[Backend] Connected!");
  
  // Send HTTP headers
  client.print("POST /api/iot/scan-book-image HTTP/1.1\r\n");
  client.print("Host: 172.20.10.5:3000\r\n");
  client.print("Content-Type: multipart/form-data; boundary=" + boundary + "\r\n");
  client.print("Content-Length: " + String(totalLength) + "\r\n");
  client.print("Connection: close\r\n\r\n");
  
  // Send multipart header
  client.print(header);
  
  // Send image data in chunks
  Serial.println("[Backend] Sending image data...");
  const size_t chunkSize = 512;
  size_t sent = 0;
  
  while (sent < fb->len) {
    size_t toSend = min(chunkSize, fb->len - sent);
    size_t written = client.write(fb->buf + sent, toSend);
    
    if (written == 0) {
      Serial.println("[Backend] Write failed!");
      break;
    }
    
    sent += written;
    
    // Progress indicator
    if (sent % 10240 == 0) {  // Every 10KB
      Serial.print(".");
      digitalWrite(LED_GPIO_NUM, !digitalRead(LED_GPIO_NUM));
    }
  }
  
  Serial.println();
  digitalWrite(LED_GPIO_NUM, LOW);
  
  // Send multipart footer
  client.print(footer);
  client.flush();
  
  Serial.print("[Backend] Sent ");
  Serial.print(sent);
  Serial.println(" bytes");
  
  // Wait for response
  Serial.println("[Backend] Waiting for response...");
  unsigned long timeout = millis();
  
  while (!client.available()) {
    if (millis() - timeout > 15000) {
      Serial.println("[Backend] Response timeout!");
      client.stop();
      return;
    }
    delay(10);
  }
  
  // Read response
  Serial.println("[Backend] Reading response...");
  
  // Skip HTTP headers
  while (client.available()) {
    String line = client.readStringUntil('\n');
    if (line == "\r") break;  // Empty line = end of headers
  }
  
  // Read JSON body
  String response = "";
  while (client.available()) {
    response += (char)client.read();
  }
  
  Serial.print("[Backend] Response: ");
  Serial.println(response);
  
  client.stop();
  Serial.println("[Backend] Done!");
}
