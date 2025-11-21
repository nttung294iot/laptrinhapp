import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/injection/injection.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../shared/models/book.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/domain/entities/user.dart';
import '../../data/services/book_search_service.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/search_result_card_widget.dart';
import '../widgets/search_history_widget.dart';
import '../widgets/book_result_card_widget.dart';
import 'advanced_search_dialog.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchHistory = [];
  User? _currentUser;
  
  // For User book search
  bool _isLoadingBooks = false;
  List<Book> _bookResults = [];
  String _bookSearchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    
    // Get current user
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUser = authState.user;
    }
    
    // Everyone has 2 tabs now
    final tabCount = 2;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Load search history
    if (!PermissionHelper.isRegularUser(_currentUser)) {
      context.read<SearchBloc>().add(const LoadSearchHistoryEvent());
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // Clear search when switching tabs
      _searchController.clear();
      context.read<SearchBloc>().add(const ClearSearchEvent());
      // Force rebuild để cập nhật hint text
      setState(() {});
    }
  }

  void _onSearchChanged(String query) {
    // User always searches books from database
    if (PermissionHelper.isRegularUser(_currentUser)) {
      // Cancel previous timer
      _debounceTimer?.cancel();
      
      if (query.trim().isEmpty) {
        setState(() {
          _bookResults = [];
          _bookSearchQuery = '';
          _isLoadingBooks = false;
        });
        return;
      }
      
      // Show loading immediately
      setState(() {
        _isLoadingBooks = true;
        _bookSearchQuery = query;
      });
      
      // Debounce search - wait 500ms after user stops typing
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        // Search books from database
        final bookSearchService = getIt<BookSearchService>();
        final result = await bookSearchService.searchBooks(query);
        
        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _isLoadingBooks = false;
                _bookResults = [];
              });
            }
          },
          (books) {
            if (mounted) {
              setState(() {
                _isLoadingBooks = false;
                _bookResults = books;
              });
            }
          },
        );
      });
    } else {
      // Admin/Librarian can search by borrower or book
      if (_tabController.index == 0) {
        context.read<SearchBloc>().add(SearchByBorrowerNameEvent(query));
      } else {
        context.read<SearchBloc>().add(SearchByBookNameEvent(query));
      }
    }
  }

  void _onClearSearch() {
    _searchController.clear();
    if (PermissionHelper.isRegularUser(_currentUser)) {
      setState(() {
        _bookResults = [];
        _bookSearchQuery = '';
        _isLoadingBooks = false;
      });
    } else {
      context.read<SearchBloc>().add(const ClearSearchEvent());
    }
  }

  void _onHistoryTap(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  void _onClearHistory() {
    context.read<SearchBloc>().add(const ClearSearchHistoryEvent());
    setState(() {
      _searchHistory = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
            ),
          ),
        ),
        title: const Text('Tìm kiếm'),
        actions: [
          if (!PermissionHelper.isRegularUser(_currentUser))
            IconButton(
              tooltip: 'Tìm kiếm nâng cao',
              icon: const Icon(Icons.filter_alt_outlined),
              onPressed: () {
                // Get the SearchBloc from the current context before opening dialog
                final searchBloc = context.read<SearchBloc>();
                showDialog(
                  context: context,
                  builder: (dialogContext) => BlocProvider<SearchBloc>.value(
                    value: searchBloc,
                    child: const AdvancedSearchDialog(),
                  ),
                );
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: PermissionHelper.isRegularUser(_currentUser)
              ? const [
                  Tab(text: 'Sách'),
                  Tab(text: 'Lịch sử'),
                ]
              : const [
                  Tab(text: 'Người mượn'),
                  Tab(text: 'Sách'),
                ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SearchBarWidget(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: _onClearSearch,
              hintText: PermissionHelper.isRegularUser(_currentUser)
                  ? (_tabController.index == 0
                      ? 'Tìm theo tên sách...'
                      : 'Tìm trong lịch sử...')
                  : (_tabController.index == 0
                      ? 'Tìm theo tên người mượn...'
                      : 'Tìm theo tên sách...'),
            ),
          ),

          // Content
          Expanded(
            child: PermissionHelper.isRegularUser(_currentUser)
                ? _buildBookSearchContent()
                : BlocConsumer<SearchBloc, SearchState>(
                    listener: (context, state) {
                      if (state is SearchHistoryLoaded) {
                        setState(() {
                          _searchHistory = state.history;
                        });
                      }
                    },
                    builder: (context, state) {
                      if (state is SearchInitial) {
                        return _buildInitialState();
                      } else if (state is SearchLoading) {
                        return _buildLoadingState();
                      } else if (state is SearchLoaded) {
                        return _buildResultsList(state);
                      } else if (state is SearchEmpty) {
                        return _buildEmptyState(state.query);
                      } else if (state is SearchError) {
                        return _buildErrorState(state.message);
                      } else if (state is SearchHistoryLoaded) {
                        return _buildInitialState();
                      }
                      return _buildInitialState();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Search history
          if (_searchHistory.isNotEmpty)
            SearchHistoryWidget(
              history: _searchHistory,
              onHistoryTap: _onHistoryTap,
              onClearHistory: _onClearHistory,
            ),

          // Initial message
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Nhập từ khóa để tìm kiếm',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tabController.index == 0
                      ? 'Tìm kiếm theo tên người mượn'
                      : 'Tìm kiếm theo tên sách',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildResultsList(SearchLoaded state) {
    return Column(
      children: [
        // Results header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'Tìm thấy ${state.totalResults} kết quả',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (state.fromCache) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cached,
                        size: 14,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cached',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.results.length,
            itemBuilder: (context, index) {
              return SearchResultCardWidget(
                card: state.results[index],
                query: state.query,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy kết quả',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Không có kết quả cho "$query"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Có lỗi xảy ra',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  _onSearchChanged(_searchController.text);
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // Build book search content for User
  Widget _buildBookSearchContent() {
    if (_isLoadingBooks) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_bookSearchQuery.isEmpty) {
      return _buildBookSearchInitialState();
    }

    if (_bookResults.isEmpty) {
      return _buildBookSearchEmptyState();
    }

    return _buildBookResultsList();
  }

  Widget _buildBookSearchInitialState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Tìm kiếm sách',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nhập tên sách để tìm kiếm',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSearchEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy sách',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Không có kết quả cho "$_bookSearchQuery"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookResults.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Tìm thấy ${_bookResults.length} kết quả',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final book = _bookResults[index - 1];
        return BookResultCardWidget(
          book: book,
          onTap: () {
            // TODO: Navigate to book detail screen
          },
        );
      },
    );
  }
}
