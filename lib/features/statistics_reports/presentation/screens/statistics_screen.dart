import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/injection/injection.dart';
import '../bloc/statistics_bloc.dart';
import '../widgets/date_range_picker_widget.dart';
import '../widgets/statistics_summary_widget.dart';
import '../widgets/book_category_list_widget.dart';
import '../widgets/user_statistics_tab.dart';
import '../../data/services/report_generator_service.dart';
import '../../data/services/book_category_stats_service.dart';
import '../../domain/entities/book_category_stats.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/auth/domain/entities/user.dart';
import '../../../../core/utils/permission_helper.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<BookCategoryStats> _categoryStats = [];
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    
    // Load initial statistics
    context.read<StatisticsBloc>().add(const LoadAllStatisticsEvent());
    
    // Load category stats
    _loadCategoryStats();
  }
  
  Future<void> _loadCategoryStats() async {
    setState(() {
      _isLoadingCategories = true;
    });
    
    final service = getIt<BookCategoryStatsService>();
    final result = await service.getCategoryStats();
    
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoadingCategories = false;
          });
        }
      },
      (stats) {
        if (mounted) {
          setState(() {
            _categoryStats = stats;
            _isLoadingCategories = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StatisticsBloc, StatisticsState>(
      listener: (context, state) {
        if (state is ReportGenerated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Đã xuất báo cáo thành công!\nĐường dẫn: ${state.filePath}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
          // Reload statistics to return to normal state
          context.read<StatisticsBloc>().add(const LoadAllStatisticsEvent());
          _loadCategoryStats(); // Reload category stats
        } else if (state is StatisticsError && state.message.contains('báo cáo')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${state.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          // Reload statistics to return to normal state
          context.read<StatisticsBloc>().add(const LoadAllStatisticsEvent());
        } else if (state is StatisticsLoaded || state is StatisticsSummaryLoaded) {
          // Reload category stats when statistics are loaded
          _loadCategoryStats();
        }
      },
      child: WillPopScope(
        onWillPop: () async {
          // Prevent back navigation, let MainMenuScreen handle it
          return false;
        },
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildDateFilter(),
              _buildExportButton(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Hide back button since we're in bottom navigation
          const SizedBox(width: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thống kê & Báo cáo',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Phân tích dữ liệu thư viện',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              context.read<StatisticsBloc>().add(const RefreshStatisticsEvent());
              _loadCategoryStats(); // Reload category stats
            },
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: DateRangePickerWidget(
        startDate: _startDate,
        endDate: _endDate,
        onDateRangeChanged: (start, end) {
          setState(() {
            _startDate = start;
            _endDate = end;
          });
          
          if (start != null && end != null) {
            context.read<StatisticsBloc>().add(
              ApplyDateFilterEvent(startDate: start, endDate: end),
            );
          } else {
            context.read<StatisticsBloc>().add(const ClearDateFilterEvent());
          }
        },
      ),
    );
  }

  Widget _buildExportButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        // Check if user can export (Admin only)
        User? currentUser;
        if (authState is Authenticated) {
          currentUser = authState.user;
        }
        
        if (!PermissionHelper.canExportReports(currentUser)) {
          return const SizedBox.shrink(); // Hide button for non-admin
        }
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: BlocBuilder<StatisticsBloc, StatisticsState>(
            builder: (context, state) {
              final canExport = state is StatisticsLoaded || state is StatisticsSummaryLoaded;
          
          return ElevatedButton.icon(
            onPressed: canExport ? () => _showExportDialog(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6A11CB),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.download_rounded, size: 24),
            label: const Text(
              'Xuất báo cáo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
        );
      },
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xuất báo cáo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Xuất PDF'),
              onTap: () {
                Navigator.pop(dialogContext);
                context.read<StatisticsBloc>().add(
                  GenerateReportEvent(
                    format: ReportFormat.pdf,
                    fileName: 'bao_cao_thu_vien',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang xuất báo cáo PDF...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Xuất Excel'),
              onTap: () {
                Navigator.pop(dialogContext);
                context.read<StatisticsBloc>().add(
                  GenerateReportEvent(
                    format: ReportFormat.excel,
                    fileName: 'bao_cao_thu_vien',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang xuất báo cáo Excel...')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) {
        if (state is ReportGenerating) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Đang tạo báo cáo...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        } else if (state is StatisticsLoaded) {
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  labelColor: Color(0xFF6A11CB),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF6A11CB),
                  tabs: [
                    Tab(text: 'Tổng quan'),
                    Tab(text: 'Người mượn'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSummaryTab(state),
                      _buildBorrowerTab(state),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else if (state is StatisticsSummaryLoaded) {
          return SingleChildScrollView(
            child: Column(
              children: [
                StatisticsSummaryWidget(summary: state.summary),
                const SizedBox(height: 24),
                if (_isLoadingCategories)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )
                else
                  BookCategoryListWidget(categoryStats: _categoryStats),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Widget _buildSummaryTab(StatisticsLoaded state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          StatisticsSummaryWidget(summary: state.summary),
          const SizedBox(height: 24),
          if (_isLoadingCategories)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else
            BookCategoryListWidget(categoryStats: _categoryStats),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBorrowerTab(StatisticsLoaded state) {
    return UserStatisticsTab();
  }
}