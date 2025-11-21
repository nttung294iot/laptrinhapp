import 'dart:io';

class ApiConfig {
  // Chế độ: 'emulator', 'real_device', 'auto'
  static const String mode = 'auto'; // Thay bằng 'real_device' nếu build APK cho thiết bị thật
  
  // Tự động chọn base URL phù hợp với platform
  static String get baseUrl {
    // Nếu force real device mode
    if (mode == 'real_device') {
      return realDeviceUrl;
    }
    
    if (Platform.isAndroid) {
      // Android emulator: 10.0.2.2 trỏ đến localhost của máy host
      return 'http://10.0.2.2:3000';
    } else if (Platform.isIOS) {
      // iOS simulator có thể dùng localhost
      return 'http://localhost:3000';
    } else {
      // Desktop hoặc web
      return 'http://localhost:3000';
    }
  }

  static String get wsUrl {
    if (Platform.isAndroid) {
      return 'ws://10.0.2.2:3000/ws';
    } else if (Platform.isIOS) {
      return 'ws://localhost:3000/ws';
    } else {
      return 'ws://localhost:3000/ws';
    }
  }

  // Nếu dùng thiết bị thật, set IP thật của máy host
  // Tìm IP bằng: ipconfig (Windows) hoặc ifconfig (Mac/Linux)
  static const String realDeviceIp = '192.168.1.100'; // TODO: Thay bằng IP WiFi của máy bạn
  
  static String get realDeviceUrl => 'http://$realDeviceIp:3000';
  static String get realDeviceWsUrl => 'ws://$realDeviceIp:3000/ws';
}
