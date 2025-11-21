import 'package:flutter/material.dart';
import '../../features/ai_chatbot/presentation/screens/ai_chatbot_screen.dart';

class AppRouter {
  static const String home = '/';
  static const String bookList = '/books';
  static const String bookDetail = '/book-detail';
  static const String addBook = '/add-book';
  static const String readerList = '/readers';
  static const String readerDetail = '/reader-detail';
  static const String addReader = '/add-reader';
  static const String borrowingList = '/borrowings';
  static const String addBorrowing = '/add-borrowing';
  static const String returnBook = '/return-book';
  static const String statistics = '/statistics';
  static const String qrScanner = '/qr-scanner';
  static const String settings = '/settings';
  static const String aiChatbot = '/ai-chatbot';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRouter.home:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Trang chủ - Sẽ được implement sau'),
            ),
          ),
        );
      
      case AppRouter.bookList:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Danh sách sách - Sẽ được implement sau'),
            ),
          ),
        );
      
      case AppRouter.readerList:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Danh sách độc giả - Sẽ được implement sau'),
            ),
          ),
        );
      
      case AppRouter.borrowingList:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Danh sách mượn trả - Sẽ được implement sau'),
            ),
          ),
        );
      
      case AppRouter.statistics:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Thống kê - Sẽ được implement sau'),
            ),
          ),
        );
      
      case AppRouter.qrScanner:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Quét QR - Sẽ được implement sau'),
            ),
          ),
        );
      
      case AppRouter.settings:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Cài đặt - Sẽ được implement sau'),
            ),
          ),
        );
      
      case AppRouter.aiChatbot:
        return MaterialPageRoute(
          builder: (_) => const AiChatbotScreen(),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Trang không tìm thấy'),
            ),
          ),
        );
    }
  }
}