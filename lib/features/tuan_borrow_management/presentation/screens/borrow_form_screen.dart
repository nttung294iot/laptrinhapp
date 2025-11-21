import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/injection/injection.dart';
import '../../../../shared/database/database_helper.dart';
import '../../domain/entities/borrow_form_data.dart';
import '../bloc/borrow_bloc.dart';
import '../bloc/borrow_event.dart';
import '../bloc/borrow_state.dart';
import '../widgets/date_picker_widget.dart';

class BorrowFormScreen extends StatelessWidget {
  final int? borrowId;
  final Map<String, dynamic>? iotStudentData;
  final Map<String, dynamic>? iotBookData;

  const BorrowFormScreen({
    Key? key,
    this.borrowId,
    this.iotStudentData,
    this.iotBookData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<BorrowBloc>(),
      child: _BorrowFormScreenContent(
        borrowId: borrowId,
        iotStudentData: iotStudentData,
        iotBookData: iotBookData,
      ),
    );
  }
}

class _BorrowFormScreenContent extends StatefulWidget {
  final int? borrowId;
  final Map<String, dynamic>? iotStudentData;
  final Map<String, dynamic>? iotBookData;

  const _BorrowFormScreenContent({
    Key? key,
    this.borrowId,
    this.iotStudentData,
    this.iotBookData,
  }) : super(key: key);

  @override
  State<_BorrowFormScreenContent> createState() => _BorrowFormScreenState();
}

class _BorrowFormScreenState extends State<_BorrowFormScreenContent> {
  final _formKey = GlobalKey<FormState>();
  final _borrowerNameController = TextEditingController();
  final _borrowerClassController = TextEditingController();
  final _borrowerStudentIdController = TextEditingController();
  final _borrowerPhoneController = TextEditingController();
  final _borrowerEmailController = TextEditingController();
  final _bookNameController = TextEditingController();
  final _bookCodeController = TextEditingController();

  DateTime? _borrowDate;
  DateTime? _expectedReturnDate;
  DateTime? _actualReturnDate;

  bool _isEditing = false;
  Map<String, String> _validationErrors = {};

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.borrowId != null;
    
    // Initialize dates
    final now = DateTime.now();
    _borrowDate = now;
    _expectedReturnDate = now.add(const Duration(days: 14)); // Default 2 weeks
    
    // Điền dữ liệu từ IoT nếu có
    print('[FORM] IoT Student Data: ${widget.iotStudentData}');
    print('[FORM] IoT Book Data: ${widget.iotBookData}');
    
    if (widget.iotStudentData != null) {
      _borrowerNameController.text = widget.iotStudentData!['name'] ?? '';
      _borrowerStudentIdController.text = widget.iotStudentData!['student_id'] ?? '';
      _borrowerClassController.text = widget.iotStudentData!['class'] ?? '';
      _borrowerPhoneController.text = widget.iotStudentData!['phone'] ?? '';
      _borrowerEmailController.text = widget.iotStudentData!['email'] ?? '';
      print('[FORM] Filled student data: ${_borrowerNameController.text}');
    }
    
    if (widget.iotBookData != null) {
      _bookNameController.text = widget.iotBookData!['title'] ?? '';
      _bookCodeController.text = widget.iotBookData!['book_code'] ?? '';
      print('[FORM] Filled book data: ${_bookNameController.text}');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Load form data after widget is built and BlocProvider is available
    if (!_hasInitialized) {
      _hasInitialized = true;
      
      if (_isEditing) {
        context.read<BorrowBloc>().add(LoadFormDataEvent(borrowId: widget.borrowId));
      } else if (widget.iotStudentData == null && widget.iotBookData == null) {
        // Chỉ reset form nếu KHÔNG có dữ liệu IoT
        context.read<BorrowBloc>().add(const ResetFormEvent());
      }
    }
  }

  @override
  void dispose() {
    _borrowerNameController.dispose();
    _borrowerClassController.dispose();
    _borrowerStudentIdController.dispose();
    _borrowerPhoneController.dispose();
    _borrowerEmailController.dispose();
    _bookNameController.dispose();
    _bookCodeController.dispose();
    super.dispose();
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
        title: Text(_isEditing ? 'Sửa thẻ mượn' : 'Tạo thẻ mượn mới'),
        actions: [
          IconButton(
            onPressed: _scanQRCode,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Quét mã QR',
          ),
        ],
      ),
      body: BlocListener<BorrowBloc, BorrowState>(
        listener: (context, state) {
          if (state is BorrowCardCreated) {
            _showSuccessMessage('Tạo thẻ mượn thành công');
            Navigator.of(context).pop(true);
          } else if (state is BorrowCardUpdated) {
            _showSuccessMessage('Cập nhật thẻ mượn thành công');
            Navigator.of(context).pop(true);
          } else if (state is BorrowError) {
            _showErrorMessage(state.message);
          } else if (state is BorrowFormDataLoaded) {
            _loadFormData(state.formData);
          } else if (state is BorrowFormValidated) {
            setState(() {
              _validationErrors = state.validationErrors;
            });
          } else if (state is ScannerInputProcessed) {
            _handleScannerInput(state);
          }
        },
        child: BlocBuilder<BorrowBloc, BorrowState>(
          builder: (context, state) {
            if (state is BorrowLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBorrowerSection(),
                    const SizedBox(height: 24),
                    _buildBookSection(),
                    const SizedBox(height: 24),
                    _buildDateSection(),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBorrowerSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thông tin người mượn',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E9AF1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: _scanReaderCard,
                    icon: const Icon(Icons.qr_code_rounded, color: Color(0xFF4E9AF1)),
                    tooltip: 'Quét thẻ độc giả',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _borrowerNameController,
              decoration: InputDecoration(
                labelText: 'Tên người mượn *',
                border: const OutlineInputBorder(),
                errorText: _validationErrors['borrowerName'],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên người mượn';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _borrowerClassController,
                    decoration: InputDecoration(
                      labelText: 'Lớp',
                      border: const OutlineInputBorder(),
                      errorText: _validationErrors['borrowerClass'],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _borrowerStudentIdController,
                    decoration: InputDecoration(
                      labelText: 'MSSV',
                      border: const OutlineInputBorder(),
                      errorText: _validationErrors['borrowerStudentId'],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _borrowerPhoneController,
              decoration: InputDecoration(
                labelText: 'Số điện thoại',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_rounded),
                errorText: _validationErrors['borrowerPhone'],
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _borrowerEmailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'example@email.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_rounded),
                errorText: _validationErrors['borrowerEmail'],
                helperText: 'Email để nhận thông báo quá hạn',
                helperStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  // Email validation regex
                  final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Email không hợp lệ';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thông tin sách',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E9AF1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: _scanBookCode,
                    icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF4E9AF1)),
                    tooltip: 'Quét mã sách',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bookNameController,
              decoration: InputDecoration(
                labelText: 'Tên sách *',
                border: const OutlineInputBorder(),
                errorText: _validationErrors['bookName'],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên sách';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bookCodeController,
              decoration: InputDecoration(
                labelText: 'Mã sách',
                border: const OutlineInputBorder(),
                errorText: _validationErrors['bookCode'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thông tin ngày tháng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DatePickerWidget(
              selectedDate: _borrowDate,
              label: 'Ngày mượn',
              isRequired: true,
              onDateSelected: (date) {
                setState(() {
                  _borrowDate = date;
                  // Auto-adjust expected return date if needed
                  if (_expectedReturnDate != null && _expectedReturnDate!.isBefore(date)) {
                    _expectedReturnDate = date.add(const Duration(days: 14));
                  }
                });
              },
              errorText: _validationErrors['borrowDate'],
              lastDate: DateTime.now(),
            ),
            const SizedBox(height: 16),
            DatePickerWidget(
              selectedDate: _expectedReturnDate,
              label: 'Ngày trả dự kiến',
              isRequired: true,
              onDateSelected: (date) {
                setState(() {
                  _expectedReturnDate = date;
                });
              },
              errorText: _validationErrors['expectedReturnDate'],
              firstDate: _borrowDate ?? DateTime.now(),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              DatePickerWidget(
                selectedDate: _actualReturnDate,
                label: 'Ngày trả thực tế',
                onDateSelected: (date) {
                  setState(() {
                    _actualReturnDate = date;
                  });
                },
                errorText: _validationErrors['actualReturnDate'],
                firstDate: _borrowDate ?? DateTime.now(),
                lastDate: DateTime.now(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4E9AF1).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              _isEditing ? 'Cập nhật' : 'Tạo thẻ mượn',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Hủy',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _loadFormData(BorrowFormData formData) {
    setState(() {
      _borrowerNameController.text = formData.borrowerName;
      _borrowerClassController.text = formData.borrowerClass ?? '';
      _borrowerStudentIdController.text = formData.borrowerStudentId ?? '';
      _borrowerPhoneController.text = formData.borrowerPhone ?? '';
      _borrowerEmailController.text = formData.borrowerEmail ?? '';
      _bookNameController.text = formData.bookName;
      _bookCodeController.text = formData.bookCode ?? '';
      _borrowDate = formData.borrowDate;
      _expectedReturnDate = formData.expectedReturnDate;
      _actualReturnDate = formData.actualReturnDate;
    });
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_borrowDate == null || _expectedReturnDate == null) {
        _showErrorMessage('Vui lòng chọn ngày mượn và ngày trả dự kiến');
        return;
      }

      final formData = BorrowFormData(
        borrowerName: _borrowerNameController.text.trim(),
        borrowerClass: _borrowerClassController.text.trim().isEmpty 
            ? null 
            : _borrowerClassController.text.trim(),
        borrowerStudentId: _borrowerStudentIdController.text.trim().isEmpty 
            ? null 
            : _borrowerStudentIdController.text.trim(),
        borrowerPhone: _borrowerPhoneController.text.trim().isEmpty 
            ? null 
            : _borrowerPhoneController.text.trim(),
        borrowerEmail: _borrowerEmailController.text.trim().isEmpty 
            ? null 
            : _borrowerEmailController.text.trim(),
        bookName: _bookNameController.text.trim(),
        bookCode: _bookCodeController.text.trim().isEmpty 
            ? null 
            : _bookCodeController.text.trim(),
        borrowDate: _borrowDate!,
        expectedReturnDate: _expectedReturnDate!,
        actualReturnDate: _actualReturnDate,
      );

      if (_isEditing) {
        context.read<BorrowBloc>().add(UpdateBorrowEvent(
          borrowId: widget.borrowId!,
          formData: formData,
        ));
      } else {
        context.read<BorrowBloc>().add(CreateBorrowEvent(formData: formData));
      }
    }
  }

  void _scanQRCode() {
    // This would integrate with the scanner module
    // For now, show a placeholder
    _showInfoMessage('Chức năng quét mã QR sẽ được tích hợp với module Scanner');
  }

  void _scanReaderCard() async {
    // Show dialog to select reader from database
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _ReaderSelectionDialog(),
    );
    
    if (result != null) {
      // Format: name|studentId|class|phone|email
      final scannedData = '${result['name']}|${result['studentId']}|${result['class']}|${result['phone']}|${result['email']}';
      context.read<BorrowBloc>().add(HandleScannerInputEvent(
        scannedData: scannedData,
        inputType: ScannerInputType.readerCard,
      ));
    }
  }

  void _scanBookCode() async {
    // Show dialog to select book from database
    final book = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _BookSelectionDialog(),
    );
    
    if (book != null) {
      // Điền cả mã sách và tên sách
      _bookCodeController.text = book['bookCode'] ?? '';
      _bookNameController.text = book['title'] ?? '';
      
      // Trigger validation
      context.read<BorrowBloc>().add(HandleScannerInputEvent(
        scannedData: book['bookCode'] ?? '',
        inputType: ScannerInputType.bookCode,
      ));
      
      // Show thông báo
      _showSuccessMessage('Đã chọn: ${book['title']}');
    }
  }

  void _handleScannerInput(ScannerInputProcessed state) {
    if (state.isValid) {
      switch (state.extractedData.keys.first) {
        case 'bookCode':
          _bookCodeController.text = state.extractedData['bookCode'] ?? '';
          break;
        case 'name':
          _borrowerNameController.text = state.extractedData['name'] ?? '';
          _borrowerStudentIdController.text = state.extractedData['studentId'] ?? '';
          _borrowerClassController.text = state.extractedData['class'] ?? '';
          _borrowerPhoneController.text = state.extractedData['phone'] ?? '';
          _borrowerEmailController.text = state.extractedData['email'] ?? '';
          break;
        case 'studentId':
          _borrowerStudentIdController.text = state.extractedData['studentId'] ?? '';
          break;
      }
      _showSuccessMessage('Đã quét thành công');
    } else {
      _showErrorMessage('Không thể đọc mã QR/Barcode');
    }
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

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
}


// Dialog để chọn người mượn từ database
class _ReaderSelectionDialog extends StatefulWidget {
  const _ReaderSelectionDialog();

  @override
  State<_ReaderSelectionDialog> createState() => _ReaderSelectionDialogState();
}

class _ReaderSelectionDialogState extends State<_ReaderSelectionDialog> {
  List<Map<String, dynamic>> _readers = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _loadReaders();
  }

  Future<void> _loadReaders() async {
    try {
      final dbHelper = DatabaseHelper();
      final result = await dbHelper.executeRemoteQuery(
        'SELECT id, name, student_id, class, phone, email FROM readers ORDER BY name LIMIT 50',
      );
      
      result.fold(
        (failure) {
          print('❌ Lỗi load readers: ${failure.message}');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = failure.message;
            });
          }
        },
        (rows) {
          print('✅ Loaded ${rows.length} readers');
          if (mounted) {
            setState(() {
              _readers = rows.map((row) => {
                'id': row['id'],
                'name': row['name'],
                'student_id': row['student_id'],
                'class': row['class'],
                'phone': row['phone'],
                'email': row['email'],
              }).toList();
              _isLoading = false;
              _errorMessage = null;
            });
          }
        },
      );
    } catch (e) {
      print('❌ Exception load readers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn người mượn'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Lỗi: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  )
                : _readers.isEmpty
                    ? const Center(child: Text('Không có dữ liệu'))
                    : ListView.builder(
                    itemCount: _readers.length,
                    itemBuilder: (context, index) {
                      final reader = _readers[index];
                      return ListTile(
                        title: Text(reader['name'] ?? ''),
                        subtitle: Text('MSSV: ${reader['student_id'] ?? ''} - ${reader['class'] ?? ''}'),
                        onTap: () {
                          if (_isClosing) return;
                          _isClosing = true;
                          
                          final data = {
                            'name': reader['name']?.toString() ?? '',
                            'studentId': reader['student_id']?.toString() ?? '',
                            'class': reader['class']?.toString() ?? '',
                            'phone': reader['phone']?.toString() ?? '',
                            'email': reader['email']?.toString() ?? '',
                          };
                          
                          // Pop immediately - the type error was the real issue
                          Navigator.of(context).pop(data);
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_isClosing) return;
            _isClosing = true;
            Navigator.of(context).pop();
          },
          child: const Text('Hủy'),
        ),
      ],
    );
  }
}

// Dialog để chọn sách từ database
class _BookSelectionDialog extends StatefulWidget {
  const _BookSelectionDialog();

  @override
  State<_BookSelectionDialog> createState() => _BookSelectionDialogState();
}

class _BookSelectionDialogState extends State<_BookSelectionDialog> {
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    try {
      final dbHelper = DatabaseHelper();
      final result = await dbHelper.executeRemoteQuery(
        'SELECT id, book_code, title, author, publisher, available_copies FROM books WHERE available_copies > 0 ORDER BY title LIMIT 50',
      );
      
      result.fold(
        (failure) {
          print('❌ Lỗi load books: ${failure.message}');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = failure.message;
            });
          }
        },
        (rows) {
          print('✅ Loaded ${rows.length} books');
          if (mounted) {
            setState(() {
              _books = rows.map((row) => {
                'id': row['id'],
                'book_code': row['book_code'],
                'title': row['title'],
                'author': row['author'],
                'publisher': row['publisher'],
                'available_quantity': row['available_copies'],
              }).toList();
              _isLoading = false;
              _errorMessage = null;
            });
          }
        },
      );
    } catch (e) {
      print('❌ Exception load books: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn sách'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Lỗi: $_errorMessage',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  )
                : _books.isEmpty
                    ? const Center(child: Text('Không có sách khả dụng'))
                    : ListView.builder(
                    itemCount: _books.length,
                    itemBuilder: (context, index) {
                      final book = _books[index];
                      return ListTile(
                        title: Text(book['title'] ?? ''),
                        subtitle: Text('Mã: ${book['book_code'] ?? ''} - Còn: ${book['available_quantity'] ?? 0}'),
                        onTap: () {
                          if (_isClosing) return;
                          _isClosing = true;
                          
                          final data = {
                            'bookCode': book['book_code']?.toString() ?? '',
                            'title': book['title']?.toString() ?? '',
                            'author': book['author']?.toString() ?? '',
                            'publisher': book['publisher']?.toString() ?? '',
                          };
                          
                          // Pop immediately - the type error was the real issue
                          Navigator.of(context).pop(data);
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_isClosing) return;
            _isClosing = true;
            Navigator.of(context).pop();
          },
          child: const Text('Hủy'),
        ),
      ],
    );
  }
}
