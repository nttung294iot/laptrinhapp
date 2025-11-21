import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../config/injection/injection.dart';
import '../../../features/tuan_borrow_management/presentation/bloc/borrow_bloc.dart';
import '../../../features/tuan_borrow_management/presentation/bloc/borrow_event.dart';
import '../../../features/tuan_borrow_management/presentation/screens/borrow_list_screen.dart';
import '../../../features/tung_overdue_alerts/presentation/screens/overdue_list_screen.dart';
import '../../../features/duc_search_functionality/presentation/screens/search_screen.dart';
import '../../../features/duc_search_functionality/presentation/bloc/search_bloc.dart';
import '../../../features/duc_search_functionality/presentation/bloc/search_event.dart';
import '../../../features/borrow_return_status/presentation/screens/borrow_status_screen.dart';
import '../../../features/borrow_return_status/presentation/bloc/borrow_status_bloc.dart';
import '../../../features/borrow_return_status/presentation/bloc/borrow_status_event.dart';
import '../../../features/borrow_return_status/domain/entities/borrow_status_filter.dart';
import '../../../features/statistics_reports/presentation/screens/statistics_screen.dart';
import '../../../features/statistics_reports/presentation/bloc/statistics_bloc.dart';
import '../../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../features/dashboard/presentation/bloc/dashboard_event.dart';
import '../../../features/dashboard/presentation/bloc/dashboard_state.dart';
import '../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../features/auth/domain/entities/user.dart';
import '../../utils/permission_helper.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;

  List<Widget> _getScreens(User? user) {
    final allScreens = [
      BlocProvider(
        create: (context) {
          final bloc = getIt<DashboardBloc>();
          // Load dashboard data sau khi UI đã render
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!bloc.isClosed) {
              bloc.add(LoadDashboardDataEvent(user: user));
            }
          });
          return bloc;
        },
        child: _buildHomeScreen(),
      ),
      BlocProvider(
        create: (context) {
          final bloc = getIt<BorrowBloc>();
          bloc.add(LoadBorrowsWithPaginationEvent());
          return bloc;
        },
        child: const BorrowListScreen(),
      ),
      const OverdueListScreen(),
      BlocProvider(
        create: (context) {
          final bloc = getIt<SearchBloc>();
          bloc.add(const LoadSearchHistoryEvent());
          return bloc;
        },
        child: const SearchScreen(),
      ),
      BlocProvider(
        create: (context) {
          final bloc = getIt<BorrowStatusBloc>();
          bloc.add(const LoadBorrowStatusEvent(
            BorrowStatusFilter(tab: BorrowStatusTab.active),
          ));
          return bloc;
        },
        child: const BorrowStatusScreen(),
      ),
      BlocProvider(
        create: (context) {
          final bloc = getIt<StatisticsBloc>();
          bloc.add(const LoadAllStatisticsEvent());
          return bloc;
        },
        child: const StatisticsScreen(),
      ),
    ];

    // Filter screens based on user permissions
    final availableIndexes = PermissionHelper.getAvailableMenuIndexes(user);
    return availableIndexes.map((index) => allScreens[index]).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        print('🔍 AuthState type: ${authState.runtimeType}');
        
        // Get current user from AuthBloc state
        User? currentUser;
        if (authState is Authenticated) {
          currentUser = authState.user;
          print('✅ Authenticated - User: ${currentUser.username}, Role: ${currentUser.role}');
        } else {
          print('❌ NOT Authenticated - State: $authState');
        }

        print('👤 Current user: ${currentUser?.username} (${currentUser?.role})');
        print('📋 Available menu indexes: ${PermissionHelper.getAvailableMenuIndexes(currentUser)}');

        final screens = _getScreens(currentUser);
        final menuTitles = PermissionHelper.getMenuTitles(currentUser);
        
        return Scaffold(
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/ai-chatbot');
        },
        icon: const Icon(Icons.smart_toy),
        label: const Text('AI Trợ lý'),
        backgroundColor: Colors.deepPurple,
        tooltip: 'AI Chatbot Trợ lý Thủ thư',
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: _buildBottomNavItems(currentUser),
      ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        User? currentUser;
        if (authState is Authenticated) {
          currentUser = authState.user;
        }

        // Get role display text
        String roleText = 'Hồ sơ người dùng';
        if (currentUser != null) {
          switch (currentUser.role) {
            case UserRole.admin:
              roleText = 'Quản trị viên';
              break;
            case UserRole.librarian:
              roleText = 'Thủ thư';
              break;
            case UserRole.user:
              roleText = 'Độc giả';
              break;
          }
        }

        return Drawer(
          child: Container(
            color: Colors.white,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // User Profile Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E3A8A),
                        Color(0xFF3B82F6),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white,
                            child: Text(
                              currentUser?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUser?.fullName.toUpperCase() ?? 'NGƯỜI DÙNG',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  roleText,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

            // Menu Items
            if (currentUser != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentUser.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const Divider(height: 20),

            // Quản lý người dùng - Chỉ cho Admin/Librarian
            if (currentUser != null && (currentUser.role == UserRole.admin || currentUser.role == UserRole.librarian))
              _buildDrawerItem(
                icon: Icons.people_outline,
                title: 'Quản lý người dùng',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/user-management');
                },
              ),

            _buildDrawerItem(
              icon: Icons.person_outline,
              title: 'Cấu hình',
              onTap: () {},
            ),
            _buildDrawerItem(
              icon: Icons.settings_outlined,
              title: 'Cài đặt',
              onTap: () {},
            ),

            const Divider(height: 40),

            _buildDrawerItem(
              icon: Icons.language_outlined,
              title: 'Ngôn ngữ',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tiếng Việt',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Center(
                      child: Text(
                        '🇻🇳',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () {},
            ),
            _buildDrawerItem(
              icon: Icons.logout_outlined,
              title: 'Đăng xuất',
              onTap: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),

            const SizedBox(height: 20),

            // Version Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'v1.0.0 (1)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Cập nhật',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? badge,
    Color? badgeColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildHomeScreen() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        User? currentUser;
        if (authState is Authenticated) {
          currentUser = authState.user;
        }

        return BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          context.read<DashboardBloc>().add(RefreshDashboardDataEvent(user: currentUser));
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: _buildDashboardContent(context, state, currentUser),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardState state, User? currentUser) {
    if (state is DashboardLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state is DashboardError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<DashboardBloc>().add(LoadDashboardDataEvent(user: currentUser));
              },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (state is DashboardLoaded) {
      return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Welcome Card
                  _buildWelcomeCard(),
                  const SizedBox(height: 20),

                  // Notifications - Show based on role
                  if (state.stats.overdueBorrows > 0)
                    _buildNotificationCard(
                      title: 'Cảnh báo quá hạn',
                      message: PermissionHelper.isRegularUser(currentUser)
                          ? 'Bạn có ${state.stats.overdueBorrows} cuốn sách đã quá hạn. Vui lòng trả sớm!'
                          : 'Có ${state.stats.overdueBorrows} cuốn sách đã quá hạn trong hệ thống',
                      icon: Icons.error_outline,
                      color: Colors.red,
                      onTap: () {
                        setState(() {
                          _selectedIndex = 2; // Go to Overdue screen
                        });
                      },
                    ),
                  if (state.stats.overdueBorrows > 0) const SizedBox(height: 12),
                  
                  if (state.stats.upcomingDueBorrows > 0)
                    _buildNotificationCard(
                      title: 'Nhắc nhở trả sách',
                      message: PermissionHelper.isRegularUser(currentUser)
                          ? 'Bạn có ${state.stats.upcomingDueBorrows} cuốn sách sắp đến hạn trong 3 ngày tới'
                          : 'Có ${state.stats.upcomingDueBorrows} cuốn sách sắp đến hạn trong 3 ngày tới',
                      icon: Icons.notifications_active,
                      color: Colors.orange,
                      onTap: () {
                        setState(() {
                          _selectedIndex = 4; // Go to Borrow Status (Mượn/Trả) screen
                        });
                      },
                    ),
                  if (state.stats.upcomingDueBorrows > 0) const SizedBox(height: 20),

                  // Statistics Overview
                  const Text(
                    'Tổng quan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Show different stats based on user role
                  if (PermissionHelper.isRegularUser(currentUser)) ...[
                    // User: Show only personal stats in 2 rows
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Đang mượn',
                            value: state.stats.activeBorrows.toString(),
                            icon: Icons.book_outlined,
                            color: Colors.blue,
                            onTap: () {
                              Navigator.pushNamed(context, '/user-borrows', arguments: {'filter': 'active'});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Quá hạn',
                            value: state.stats.overdueBorrows.toString(),
                            icon: Icons.warning_amber_rounded,
                            color: Colors.red,
                            onTap: () {
                              Navigator.pushNamed(context, '/user-borrows', arguments: {'filter': 'overdue'});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Đã trả',
                            value: state.stats.returnedBorrows.toString(),
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            onTap: () {
                              Navigator.pushNamed(context, '/user-borrows', arguments: {'filter': 'returned'});
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Empty space for symmetry
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ] else ...[
                    // Admin & Librarian: Show all stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Đang mượn',
                            value: state.stats.activeBorrows.toString(),
                            icon: Icons.book_outlined,
                            color: Colors.blue,
                            onTap: () {
                              setState(() {
                                _selectedIndex = 4;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Quá hạn',
                            value: state.stats.overdueBorrows.toString(),
                            icon: Icons.warning_amber_rounded,
                            color: Colors.red,
                            onTap: () {
                              setState(() {
                                _selectedIndex = 2;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'Sắp đến hạn',
                            value: state.stats.upcomingDueBorrows.toString(),
                            icon: Icons.schedule_rounded,
                            color: Colors.orange,
                            onTap: () {
                              setState(() {
                                _selectedIndex = 2;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            title: 'Tổng sách',
                            value: state.stats.totalBooks.toString(),
                            icon: Icons.library_books_rounded,
                            color: Colors.green,
                            onTap: () {
                              setState(() {
                                _selectedIndex = 5;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                    const SizedBox(height: 24),

                    // Quick Actions or Popular Books based on role
                    if (PermissionHelper.isRegularUser(currentUser)) ...[
                      // User: Show Random Books
                      const Text(
                        'Gợi ý sách',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (state.stats.popularBooks.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Chưa có dữ liệu sách được mượn',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ...state.stats.popularBooks.map((book) {
                          return _buildPopularBookItem(
                            bookName: book.bookName,
                            borrowCount: book.borrowCount,
                            availableCopies: book.availableCopies,
                          );
                        }).toList(),
                    ] else ...[
                      // Admin/Librarian: Show Quick Actions
                      const Text(
                        'Thao tác nhanh',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'Mượn sách',
                            color: Colors.blue,
                            onTap: () {
                              setState(() {
                                _selectedIndex = 1;
                              });
                            },
                          ),
                          _buildQuickActionButton(
                            icon: Icons.search,
                            label: 'Tìm kiếm',
                            color: Colors.cyan,
                            onTap: () {
                              setState(() {
                                _selectedIndex = 3;
                              });
                            },
                          ),
                          _buildQuickActionButton(
                            icon: Icons.qr_code_scanner,
                            label: 'Quét QR',
                            color: Colors.purple,
                            onTap: () => _showComingSoon(context),
                          ),
                          _buildQuickActionButton(
                            icon: Icons.assessment,
                            label: 'Báo cáo',
                            color: Colors.orange,
                            onTap: () {
                              setState(() {
                                _selectedIndex = 5;
                              });
                            },
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Recent Activities - Only for Admin/Librarian
                    if (!PermissionHelper.isRegularUser(currentUser)) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hoạt động gần đây',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedIndex = 4;
                              });
                            },
                            child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...state.recentActivities.take(3).map((activity) {
                      IconData icon;
                      Color color;
                      String subtitle;

                      switch (activity.action) {
                        case 'returned':
                          icon = Icons.check_circle;
                          color = Colors.green;
                          subtitle = '${activity.borrowerName} - Trả ${_formatDate(activity.date)}';
                          break;
                        case 'overdue':
                          icon = Icons.warning;
                          color = Colors.red;
                          final daysOverdue = DateTime.now().difference(activity.date).inDays;
                          subtitle = '${activity.borrowerName} - Quá hạn $daysOverdue ngày';
                          break;
                        default:
                          icon = Icons.book;
                          color = Colors.blue;
                          subtitle = '${activity.borrowerName} - Mượn ${_formatDate(activity.date)}';
                      }

                        return _buildActivityItem(
                          title: activity.bookTitle,
                          subtitle: subtitle,
                          icon: icon,
                          color: color,
                        );
                      }).toList(),
                      const SizedBox(height: 20),
                    ],

                    const SizedBox(height: 20),
                  ],
                );
    }

    // Default empty state
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildWelcomeCard(),
        const SizedBox(height: 20),
        const Center(
          child: Text('Không có dữ liệu'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'hôm nay';
    } else if (difference == 1) {
      return 'hôm qua';
    } else if (difference < 7) {
      return '$difference ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  Widget _buildWelcomeCard() {
    final hour = DateTime.now().hour;
    String greeting = 'Chào buổi sáng';
    if (hour >= 12 && hour < 18) {
      greeting = 'Chào buổi chiều';
    } else if (hour >= 18) {
      greeting = 'Chào buổi tối';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quản lý Thư viện',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hôm nay: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_library_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: color,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, size: 28),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_library_rounded,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản lý Thư viện',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<BottomNavigationBarItem> _buildBottomNavItems(User? user) {
    const allItems = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_rounded),
        label: 'Trang chủ',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.book_rounded),
        label: 'Mượn sách',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications_active_rounded),
        label: 'Quá hạn',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.search_rounded),
        label: 'Tìm kiếm',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.list_alt_rounded),
        label: 'Mượn/Trả',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.analytics_rounded),
        label: 'Thống kê',
      ),
    ];

    final availableIndexes = PermissionHelper.getAvailableMenuIndexes(user);
    return availableIndexes.map((index) => allItems[index]).toList();
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sắp ra mắt'),
        content: const Text('Tính năng đang được phát triển!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularBookItem({
    required String bookName,
    required int borrowCount,
    int availableCopies = 0,
  }) {
    // Determine color based on availability
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (availableCopies == 0) {
      statusColor = Colors.red;
      statusText = 'Hết sách';
      statusIcon = Icons.block_rounded;
    } else if (availableCopies <= 2) {
      statusColor = Colors.orange;
      statusText = 'Còn $availableCopies cuốn';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = Colors.green;
      statusText = 'Còn $availableCopies cuốn';
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.book_rounded,
              color: Colors.blue.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      statusIcon,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey[400],
            size: 24,
          ),
        ],
      ),
    );
  }
}
