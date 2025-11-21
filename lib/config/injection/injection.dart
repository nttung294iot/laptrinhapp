import 'package:get_it/get_it.dart';
import '../../shared/database/database_helper.dart';
import '../../shared/repositories/borrow_card_repository.dart';
import '../../features/tuan_borrow_management/data/datasources/borrow_local_data_source.dart';
import '../../features/tuan_borrow_management/data/datasources/borrow_remote_data_source.dart';
import '../../features/tuan_borrow_management/data/repositories/borrow_repository_impl.dart';
import '../../features/tuan_borrow_management/presentation/bloc/borrow_bloc.dart';
import '../../features/tung_overdue_alerts/data/services/overdue_service.dart';
import '../../features/tung_overdue_alerts/data/repositories/overdue_repository.dart';
import '../../features/tung_overdue_alerts/presentation/bloc/overdue_bloc.dart';
import '../../features/duc_search_functionality/data/services/search_service.dart';
import '../../features/duc_search_functionality/data/services/search_cache_service.dart';
import '../../features/duc_search_functionality/data/services/search_history_service.dart';
import '../../features/duc_search_functionality/data/services/book_search_service.dart';
import '../../features/duc_search_functionality/data/repositories/search_repository_impl.dart';
import '../../features/duc_search_functionality/domain/repositories/search_repository.dart';
import '../../features/duc_search_functionality/presentation/bloc/search_bloc.dart';
import '../../features/borrow_return_status/domain/repositories/borrow_status_repository.dart';
import '../../features/borrow_return_status/data/repositories/borrow_status_repository_impl.dart';
import '../../features/borrow_return_status/presentation/bloc/borrow_status_bloc.dart';
import '../../features/statistics_reports/domain/repositories/statistics_repository.dart';
import '../../features/statistics_reports/data/repositories/statistics_repository_impl.dart';
import '../../features/statistics_reports/data/services/chart_data_service.dart';
import '../../features/statistics_reports/data/services/report_generator_service.dart';
import '../../features/statistics_reports/data/services/book_category_stats_service.dart';
import '../../features/statistics_reports/data/services/borrower_statistics_service.dart';
import '../../features/statistics_reports/presentation/bloc/statistics_bloc.dart';
import '../../features/statistics_reports/presentation/bloc/borrower_statistics_bloc.dart';
import '../../features/dashboard/data/services/dashboard_service.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/services/password_service.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/iot/data/datasources/iot_websocket_datasource.dart';
import '../../features/iot/presentation/bloc/iot_bloc.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // Database Helper
  getIt.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
  
  // Data Sources
  getIt.registerLazySingleton<BorrowLocalDataSource>(
    () => BorrowLocalDataSourceImpl(databaseHelper: getIt()),
  );
  
  getIt.registerLazySingleton<BorrowRemoteDataSource>(
    () => BorrowRemoteDataSourceImpl(databaseHelper: getIt()),
  );
  
  // Repository
  getIt.registerLazySingleton<BorrowCardRepository>(
    () => BorrowRepositoryImpl(
      localDataSource: getIt(),
      remoteDataSource: getIt(),
    ),
  );
  
  // BLoC
  getIt.registerFactory<BorrowBloc>(
    () => BorrowBloc(repository: getIt()),
  );
  
  // Module Tùng - Overdue Alerts
  getIt.registerLazySingleton<OverdueService>(
    () => OverdueService(borrowRepository: getIt()),
  );
  
  getIt.registerLazySingleton<OverdueRepository>(
    () => OverdueRepositoryImpl(overdueService: getIt()),
  );
  
  getIt.registerFactory<OverdueBloc>(
    () => OverdueBloc(repository: getIt()),
  );
  
  // Module Đức - Search Functionality
  getIt.registerLazySingleton<SearchService>(
    () => SearchService(getIt()),
  );
  
  getIt.registerLazySingleton<SearchCacheService>(
    () => SearchCacheService(),
  );
  
  getIt.registerLazySingleton<SearchHistoryService>(
    () => SearchHistoryService(),
  );
  
  getIt.registerLazySingleton<BookSearchService>(
    () => BookSearchService(getIt()),
  );
  
  getIt.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(
      searchService: getIt(),
      historyService: getIt(),
    ),
  );
  
  getIt.registerFactory<SearchBloc>(
    () => SearchBloc(
      repository: getIt(),
      cacheService: getIt(),
    ),
  );
  
  // Module Borrow Return Status
  getIt.registerLazySingleton<BorrowStatusRepository>(
    () => BorrowStatusRepositoryImpl(
      borrowRepository: getIt(),
    ),
  );
  
  getIt.registerFactory<BorrowStatusBloc>(
    () => BorrowStatusBloc(
      repository: getIt(),
    ),
  );
  
  // Module Statistics Reports
  getIt.registerLazySingleton<StatisticsRepository>(
    () => StatisticsRepositoryImpl(
      borrowCardRepository: getIt(),
    ),
  );
  
  getIt.registerLazySingleton<ChartDataService>(
    () => ChartDataService(),
  );
  
  getIt.registerLazySingleton<ReportGeneratorService>(
    () => ReportGeneratorService(),
  );
  
  getIt.registerLazySingleton<BookCategoryStatsService>(
    () => BookCategoryStatsService(getIt()),
  );
  
  getIt.registerLazySingleton<BorrowerStatisticsService>(
    () => BorrowerStatisticsService(
      borrowCardRepository: getIt(),
    ),
  );
  
  getIt.registerFactory<StatisticsBloc>(
    () => StatisticsBloc(
      statisticsRepository: getIt(),
      reportGeneratorService: getIt(),
    ),
  );
  
  getIt.registerFactory<BorrowerStatisticsBloc>(
    () => BorrowerStatisticsBloc(
      statisticsService: getIt(),
    ),
  );
  
  // Module Dashboard
  getIt.registerLazySingleton<DashboardService>(
    () => DashboardService(getIt(), getIt()),
  );
  
  getIt.registerFactory<DashboardBloc>(
    () => DashboardBloc(getIt()),
  );
  
  // Module Auth
  getIt.registerLazySingleton<PasswordService>(
    () => PasswordService(),
  );
  
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt(), getIt()),
  );
  
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(getIt()),
  );
  
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt(),
      localDataSource: getIt(),
      passwordService: getIt(),
      overdueService: getIt(),
    ),
  );
  
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(getIt()),
  );
  
  // Module IoT
  getIt.registerLazySingleton<IoTWebSocketDataSource>(
    () => IoTWebSocketDataSource(
      wsUrl: 'ws://10.0.2.2:3000/ws', // 10.0.2.2 = localhost của máy host trong Android emulator
    ),
  );
  
  getIt.registerFactory<IoTBloc>(
    () => IoTBloc(webSocketDataSource: getIt()),
  );
}