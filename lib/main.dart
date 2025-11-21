import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/injection/injection.dart';
import 'config/themes/app_theme.dart';
import 'features/tung_overdue_alerts/data/services/overdue_service.dart';
import 'shared/repositories/borrow_card_repository.dart';
import 'shared/services/notification_scheduler.dart';
import 'core/presentation/screens/main_menu_screen.dart';
import 'core/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/user_management/presentation/screens/user_management_screen.dart';
import 'features/user_borrows/presentation/screens/user_borrows_screen.dart';
import 'features/ai_chatbot/presentation/screens/ai_chatbot_screen.dart';
import 'config/themes/app_theme.dart';

//           flutter run -d emulator-5554  (thay 5554 bằng id chính xác của máy ảo)

//             .\start_all_services.bat




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupDependencies();
  
  // Khởi tạo email scheduler tự động
  await _initializeEmailScheduler();
  
  runApp(const MyApp());
}

/// Khởi tạo email scheduler tự động
Future<void> _initializeEmailScheduler() async {
  try {
    print('🚀 Initializing Email Scheduler...');
    
    // Lấy services từ dependency injection
    final overdueService = getIt<OverdueService>();
    final borrowRepository = getIt<BorrowCardRepository>();
    
    // Tạo scheduler với config mặc định
    final scheduler = NotificationScheduler.createDefault(
      overdueService,
      borrowRepository,
    );
    
    // Bắt đầu auto schedule
    await scheduler.startAutoSchedule();
    
    print('✅ Email Scheduler started successfully!');
    print('📧 Emails will be sent automatically at 8:00 AM daily');
    print('📧 Email: thanhtungnguyen29122014@gmail.com');
    print('⚠️  Lưu ý: Email chỉ hoạt động khi có kết nối internet thực');
    print('⚠️  Emulator có thể không gửi được email do giới hạn mạng');
  } catch (e) {
    print('❌ Failed to initialize Email Scheduler: $e');
    print('💡 Tip: Email scheduler sẽ tiếp tục thử gửi vào lần chạy tiếp theo');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<AuthBloc>(),
      child: MaterialApp(
        title: 'Quản lý Thư viện',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainMenuScreen(),
          '/user-management': (context) => const UserManagementScreen(),
          '/ai-chatbot': (context) => const AiChatbotScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/user-borrows') {
            final args = settings.arguments as Map<String, dynamic>?;
            final filter = args?['filter'] as String? ?? 'active';
            return MaterialPageRoute(
              builder: (context) => UserBorrowsScreen(filter: filter),
            );
          }
          return null;
        },
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
          Locale('vi', ''),
        ],
      ),
    );
  }
}

