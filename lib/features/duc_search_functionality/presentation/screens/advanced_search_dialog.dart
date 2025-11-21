import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/borrow_card.dart';
import '../../domain/entities/search_query.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';

class AdvancedSearchDialog extends StatefulWidget {
  const AdvancedSearchDialog({super.key});

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _borrowerNameController = TextEditingController();
  final _bookNameController = TextEditingController();
  final _classController = TextEditingController();
  
  BorrowStatus? _selectedStatus;
  DateTime? _borrowDateFrom;
  DateTime? _borrowDateTo;
  DateTime? _returnDateFrom;
  DateTime? _returnDateTo;

  @override
  void dispose() {
    _borrowerNameController.dispose();
    _bookNameController.dispose();
    _classController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _borrowerNameController.clear();
      _bookNameController.clear();
      _classController.clear();
      _selectedStatus = null;
      _borrowDateFrom = null;
      _borrowDateTo = null;
      _returnDateFrom = null;
      _returnDateTo = null;
    });
  }

  void _applySearch() {
    final query = SearchQuery(
      borrowerName: _borrowerNameController.text.isNotEmpty
          ? _borrowerNameController.text
          : null,
      bookName: _bookNameController.text.isNotEmpty
          ? _bookNameController.text
          : null,
      borrowerClass: _classController.text.isNotEmpty
          ? _classController.text
          : null,
      status: _selectedStatus,
      borrowDateFrom: _borrowDateFrom,
      borrowDateTo: _borrowDateTo,
      returnDateFrom: _returnDateFrom,
      returnDateTo: _returnDateTo,
      type: SearchType.advanced,
    );

    if (!query.isEmpty) {
      context.read<SearchBloc>().add(ApplyAdvancedSearchEvent(query));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ít nhất một tiêu chí tìm kiếm'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    ValueChanged<DateTime?> onDateSelected,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      onDateSelected(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Tìm kiếm nâng cao',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Helper text: not all fields required
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '*Chỉ cần nhập ít nhất một tiêu chí để tìm kiếm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                      // Borrower name
                      TextField(
                        controller: _borrowerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên người mượn',
                          hintText: 'Nhập tên người mượn',
                          prefixIcon: Icon(Icons.person_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Book name
                      TextField(
                        controller: _bookNameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên sách',
                          hintText: 'Nhập tên sách',
                          prefixIcon: Icon(Icons.book_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Class
                      TextField(
                        controller: _classController,
                        decoration: const InputDecoration(
                          labelText: 'Lớp',
                          hintText: 'Nhập lớp',
                          prefixIcon: Icon(Icons.school_rounded),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status
                      DropdownButtonFormField<BorrowStatus>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái',
                          prefixIcon: Icon(Icons.info_rounded),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          ...BorrowStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusText(status)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Borrow date range
                      const Text(
                        'Ngày mượn',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(
                                context,
                                _borrowDateFrom,
                                (date) => setState(() => _borrowDateFrom = date),
                              ),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _borrowDateFrom != null
                                    ? dateFormat.format(_borrowDateFrom!)
                                    : 'Từ ngày',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(
                                context,
                                _borrowDateTo,
                                (date) => setState(() => _borrowDateTo = date),
                              ),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _borrowDateTo != null
                                    ? dateFormat.format(_borrowDateTo!)
                                    : 'Đến ngày',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Return date range
                      const Text(
                        'Ngày trả dự kiến',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(
                                context,
                                _returnDateFrom,
                                (date) => setState(() => _returnDateFrom = date),
                              ),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _returnDateFrom != null
                                    ? dateFormat.format(_returnDateFrom!)
                                    : 'Từ ngày',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _selectDate(
                                context,
                                _returnDateTo,
                                (date) => setState(() => _returnDateTo = date),
                              ),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                _returnDateTo != null
                                    ? dateFormat.format(_returnDateTo!)
                                    : 'Đến ngày',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearFilters,
                      child: const Text('Xóa bộ lọc'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applySearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                      ),
                      child: const Text('Tìm kiếm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(BorrowStatus status) {
    switch (status) {
      case BorrowStatus.borrowed:
        return 'Đang mượn';
      case BorrowStatus.returned:
        return 'Đã trả';
      case BorrowStatus.overdue:
        return 'Quá hạn';
    }
  }
}
