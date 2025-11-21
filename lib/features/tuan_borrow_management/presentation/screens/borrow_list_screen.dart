import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/injection/injection.dart';
import '../../../../shared/models/borrow_card.dart';
import '../bloc/borrow_bloc.dart';
import '../bloc/borrow_event.dart';
import '../bloc/borrow_state.dart';
import '../widgets/borrow_card_widget.dart';
import 'borrow_detail_screen.dart';
import 'borrow_form_screen.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../../features/iot/presentation/screens/iot_scanning_screen.dart';
import '../../../../features/iot/presentation/bloc/iot_bloc.dart';

class BorrowListScreen extends StatefulWidget {
  const BorrowListScreen({Key? key}) : super(key: key);

  @override
  State<BorrowListScreen> createState() => _BorrowListScreenState();
}

class _BorrowListScreenState extends State<BorrowListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _canDelete() {
    final authBloc = context.read<AuthBloc>();
    if (authBloc.state is Authenticated) {
      final user = (authBloc.state as Authenticated).user;
      return PermissionHelper.canDeleteBorrowCards(user);
    }
    return false;
  }
  
  BorrowStatus? _selectedStatus;
  bool _showOverdueOnly = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBorrows();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadBorrows() {
    if (_showOverdueOnly) {
      context.read<BorrowBloc>().add(const LoadOverdueBorrowsEvent());
    } else if (_selectedStatus != null) {
      context.read<BorrowBloc>().add(LoadBorrowsByStatusEvent(status: _selectedStatus!));
    } else if (_searchQuery.isNotEmpty) {
      context.read<BorrowBloc>().add(SearchBorrowsEvent(query: _searchQuery));
    } else {
      context.read<BorrowBloc>().add(const LoadBorrowsWithPaginationEvent());
    }
  }

  void _onScroll() {
    if (_isBottom) {
      final currentState = context.read<BorrowBloc>().state;
      if (currentState is BorrowsLoaded && !currentState.hasReachedMax) {
        if (_searchQuery.isNotEmpty) {
          context.read<BorrowBloc>().add(SearchBorrowsEvent(
            query: _searchQuery,
            page: currentState.currentPage + 1,
          ));
        } else {
          context.read<BorrowBloc>().add(LoadBorrowsWithPaginationEvent(
            page: currentState.currentPage + 1,
          ));
        }
      }
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
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
              colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
            ),
          ),
        ),
        title: const Text('Danh sách thẻ mượn'),
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Bộ lọc',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: BlocConsumer<BorrowBloc, BorrowState>(
              listener: (context, state) {
                if (state is BorrowError) {
                  _showErrorMessage(state.message);
                } else if (state is BorrowOperationSuccess) {
                  _showSuccessMessage(state.message);
                  _loadBorrows(); // Refresh list
                } else if (state is BorrowCardCreated) {
                  _showSuccessMessage('Đã tạo thẻ mượn thành công');
                  _loadBorrows(); // Refresh list
                } else if (state is BorrowCardUpdated) {
                  _showSuccessMessage('Đã cập nhật thẻ mượn thành công');
                  _loadBorrows(); // Refresh list
                } else if (state is BorrowCardDeleted) {
                  _showSuccessMessage('Đã xóa thẻ mượn thành công');
                  // Không cần reload vì Bloc đã xử lý việc xóa item
                }
              },
              builder: (context, state) {
                return _buildBody(state);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4E9AF1).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _navigateToForm(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 32),
          tooltip: 'Thêm thẻ mượn',
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên sách hoặc người mượn...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: Icon(Icons.clear_rounded, color: Colors.grey[600]),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: _onSearchChanged,
        onSubmitted: _onSearchSubmitted,
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip(
            label: 'Tất cả',
            icon: Icons.apps_rounded,
            isSelected: _selectedStatus == null && !_showOverdueOnly,
            onTap: () {
              setState(() {
                _selectedStatus = null;
                _showOverdueOnly = false;
              });
              _loadBorrows();
            },
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Đang mượn',
            icon: Icons.book_rounded,
            isSelected: _selectedStatus == BorrowStatus.borrowed && !_showOverdueOnly,
            onTap: () {
              setState(() {
                _selectedStatus = BorrowStatus.borrowed;
                _showOverdueOnly = false;
              });
              _loadBorrows();
            },
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Đã trả',
            icon: Icons.check_circle_rounded,
            isSelected: _selectedStatus == BorrowStatus.returned,
            onTap: () {
              setState(() {
                _selectedStatus = BorrowStatus.returned;
                _showOverdueOnly = false;
              });
              _loadBorrows();
            },
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Quá hạn',
            icon: Icons.warning_rounded,
            isSelected: _showOverdueOnly,
            onTap: () {
              setState(() {
                _showOverdueOnly = true;
                _selectedStatus = null;
              });
              _loadBorrows();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
                )
              : null,
          color: isSelected ? null : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BorrowState state) {
    if (state is BorrowLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is BorrowEmpty) {
      return _buildEmptyState(state.message);
    }

    if (state is BorrowsLoaded) {
      return _buildBorrowsList(state.borrowCards, state.hasReachedMax);
    }

    if (state is BorrowSearchResults) {
      return _buildBorrowsList(state.searchResults, state.hasReachedMax);
    }

    if (state is BorrowRefreshing) {
      return _buildBorrowsList(state.currentBorrowCards, false, isRefreshing: true);
    }

    if (state is BorrowLoadingMore) {
      return _buildBorrowsList(state.currentBorrowCards, false, isLoadingMore: true);
    }

    return _buildEmptyState('Không có dữ liệu');
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea).withOpacity(0.1), Color(0xFF764ba2).withOpacity(0.1)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.book_outlined,
              size: 80,
              color: Color(0xFF4E9AF1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Bắt đầu bằng cách tạo thẻ mượn đầu tiên',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF667eea).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToForm(),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Tạo thẻ mượn đầu tiên', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowsList(
    List<BorrowCard> borrowCards,
    bool hasReachedMax, {
    bool isRefreshing = false,
    bool isLoadingMore = false,
  }) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: borrowCards.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= borrowCards.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final borrowCard = borrowCards[index];
          return BorrowCardWidget(
            borrowCard: borrowCard,
            onTap: () => _navigateToDetail(borrowCard),
            onEdit: () => _navigateToForm(borrowCard.id),
            onDelete: _canDelete() ? () => _confirmDelete(borrowCard) : null,
            onMarkAsReturned: borrowCard.status == BorrowStatus.borrowed
                ? () => _markAsReturned(borrowCard.id!)
                : null,
          );
        },
      ),
    );
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isNotEmpty) {
      context.read<BorrowBloc>().add(SearchBorrowsEvent(query: query.trim()));
    } else {
      _loadBorrows();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _loadBorrows();
  }

  Future<void> _onRefresh() async {
    context.read<BorrowBloc>().add(const RefreshBorrowsEvent());
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bộ lọc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Tất cả'),
              leading: Radio<BorrowStatus?>(
                value: null,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                    _showOverdueOnly = false;
                  });
                  Navigator.of(context).pop();
                  _loadBorrows();
                },
              ),
            ),
            ListTile(
              title: const Text('Đang mượn'),
              leading: Radio<BorrowStatus?>(
                value: BorrowStatus.borrowed,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                    _showOverdueOnly = false;
                  });
                  Navigator.of(context).pop();
                  _loadBorrows();
                },
              ),
            ),
            ListTile(
              title: const Text('Đã trả'),
              leading: Radio<BorrowStatus?>(
                value: BorrowStatus.returned,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                    _showOverdueOnly = false;
                  });
                  Navigator.of(context).pop();
                  _loadBorrows();
                },
              ),
            ),
            CheckboxListTile(
              title: const Text('Chỉ hiển thị quá hạn'),
              value: _showOverdueOnly,
              onChanged: (value) {
                setState(() {
                  _showOverdueOnly = value ?? false;
                  if (_showOverdueOnly) {
                    _selectedStatus = null;
                  }
                });
                Navigator.of(context).pop();
                _loadBorrows();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _navigateToForm([int? borrowId]) async {
    // Nếu đang edit thì vào form trực tiếp
    if (borrowId != null) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => BorrowFormScreen(borrowId: borrowId),
        ),
      );

      if (result == true) {
        _loadBorrows();
      }
      return;
    }

    // Nếu tạo mới thì hiển thị dialog chọn phương thức
    final method = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn phương thức tạo thẻ mượn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
              ),
              title: const Text('Quét bằng IoT'),
              subtitle: const Text('Sử dụng RFID + Camera'),
              onTap: () => Navigator.of(context).pop('iot'),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_rounded, color: Colors.grey[700]),
              ),
              title: const Text('Nhập thủ công'),
              subtitle: const Text('Điền form truyền thống'),
              onTap: () => Navigator.of(context).pop('manual'),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    if (method == 'iot') {
      // Navigate to IoT scanning screen
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => getIt<IoTBloc>(),
            child: const IoTScanningScreen(),
          ),
        ),
      );
      if (result == true) {
        _loadBorrows();
      }
    } else {
      // Manual input
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => BorrowFormScreen(borrowId: null),
        ),
      );
      if (result == true) {
        _loadBorrows();
      }
    }
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _navigateToDetail(BorrowCard borrowCard) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => getIt<BorrowBloc>(),
          child: BorrowDetailScreen(borrowCard: borrowCard),
        ),
      ),
    );

    // Reload nếu có thay đổi (edit hoặc delete)
    if (result == true) {
      _loadBorrows();
    }
  }

  void _markAsReturned(int borrowId) {
    final bloc = context.read<BorrowBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc chắn muốn đánh dấu sách này đã được trả?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              bloc.add(MarkAsReturnedEvent(borrowId: borrowId));
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BorrowCard borrowCard) {
    final bloc = context.read<BorrowBloc>();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa thẻ mượn "${borrowCard.bookName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              bloc.add(DeleteBorrowEvent(borrowId: borrowCard.id!));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}