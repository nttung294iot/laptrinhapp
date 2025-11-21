import 'dart:io';

class ApiConfig {
  // Tự động chọn base URL phù hợp với platform
  static String get baseUrl {
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
  static const String realDeviceIp = '192.168.1.100'; // TODO: Thay bằng IP thật
  
  static String get realDeviceUrl => 'http://$realDeviceIp:3000';
  static String get realDeviceWsUrl => 'ws://$realDeviceIp:3000/ws';
}
