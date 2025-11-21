import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../../config/injection/injection.dart';
import '../../../tuan_borrow_management/presentation/screens/borrow_form_screen.dart';
import '../bloc/iot_bloc.dart';
import '../bloc/iot_event.dart';
import '../bloc/iot_state.dart';
import '../../data/models/iot_scan_event_model.dart';
import 'iot_barcode_scanning_screen.dart';

class IoTScanningScreen extends StatefulWidget {
  const IoTScanningScreen({Key? key}) : super(key: key);

  @override
  State<IoTScanningScreen> createState() => _IoTScanningScreenState();
}

class _IoTScanningScreenState extends State<IoTScanningScreen> {
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _bookData;
  bool _isScanning = false;
  String _currentStep = 'Đang kết nối...';
  Timer? _pollingTimer;
  bool _hasShownStudentSuccess = false;
  bool _hasShownBookSuccess = false;
  bool _waitingForUserConfirmation = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    setState(() {
      _isScanning = true;
      _currentStep = 'Vui lòng quét thẻ sinh viên...';
    });
    
    // Poll API mỗi 2 giây
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkScanSession();
    });
  }

  Future<void> _checkScanSession() async {
    // Nếu đang chờ user xác nhận, không poll nữa
    if (_waitingForUserConfirmation) return;
    
    try {
      const String apiUrl = 'http://172.20.10.5:3000/api/iot/scan-session';
      
      final response = await http.get(
        Uri.parse(apiUrl),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Có cả thẻ và sách rồi!
          if (!_hasShownBookSuccess) {
            // Map dữ liệu sinh viên
            final studentFromApi = data['data']['student'];
            final bookFromApi = data['data']['book'];
            
            print('[IOT] Full data from API: $data');
            print('[IOT] Student: $studentFromApi');
            print('[IOT] Book: $bookFromApi');
            
            setState(() {
              _studentData = {
                'name': studentFromApi['name'] ?? studentFromApi['reader_name'] ?? 'N/A',
                'studentId': studentFromApi['studentId'] ?? studentFromApi['student_id'] ?? studentFromApi['reader_id'] ?? 'N/A',
                'student_id': studentFromApi['student_id'] ?? studentFromApi['studentId'] ?? studentFromApi['reader_id'] ?? 'N/A',
                'class': studentFromApi['class'] ?? studentFromApi['class_name'] ?? 'N/A',
                'phone': studentFromApi['phone'] ?? studentFromApi['phone_number'] ?? '',
                'email': studentFromApi['email'] ?? '',
              };
              _bookData = {
                'title': bookFromApi['title'] ?? bookFromApi['book_name'] ?? 'N/A',
                'bookCode': bookFromApi['bookCode'] ?? bookFromApi['book_code'] ?? 'N/A',
                'book_code': bookFromApi['book_code'] ?? bookFromApi['bookCode'] ?? 'N/A',
                'author': bookFromApi['author'] ?? 'N/A',
                'category': bookFromApi['category'] ?? '',
              };
              _currentStep = 'Hoàn tất! Đang chuyển đến form...';
              _hasShownBookSuccess = true;
            });
            
            _pollingTimer?.cancel();
            _showSuccessDialog(
              title: 'Quét sách thành công!',
              message: 'Đã quét: ${_bookData?['title']}',
              icon: Icons.book_rounded,
              color: Colors.green,
            );
            
            // Chờ 2 giây rồi chuyển sang form
            Future.delayed(const Duration(seconds: 2), () {
              _navigateToForm();
            });
          }
        } else if (data['status'] == 'waiting_book') {
          // Đã có thẻ, chờ user xác nhận
          if (!_hasShownStudentSuccess) {
            // Map dữ liệu từ API response - đảm bảo có đầy đủ thông tin
            final studentFromApi = data['student'];
            print('[IOT] Student data from API: $studentFromApi');
            
            setState(() {
              _studentData = {
                'name': studentFromApi['name'] ?? studentFromApi['reader_name'] ?? 'N/A',
                'studentId': studentFromApi['studentId'] ?? studentFromApi['student_id'] ?? studentFromApi['reader_id'] ?? 'N/A',
                'student_id': studentFromApi['student_id'] ?? studentFromApi['studentId'] ?? studentFromApi['reader_id'] ?? 'N/A',
                'class': studentFromApi['class'] ?? studentFromApi['class_name'] ?? 'N/A',
                'phone': studentFromApi['phone'] ?? studentFromApi['phone_number'] ?? '',
                'email': studentFromApi['email'] ?? '',
              };
              _currentStep = 'Đã quét thẻ sinh viên thành công!';
              _hasShownStudentSuccess = true;
              _waitingForUserConfirmation = true;
            });
            
            _pollingTimer?.cancel();
            
            _showSuccessDialog(
              title: 'Quét thẻ thành công!',
              message: 'Sinh viên: ${_studentData?['name']}\nMSSV: ${_studentData?['studentId'] ?? _studentData?['student_id']}',
              icon: Icons.person_rounded,
              color: const Color(0xFF4E9AF1),
              showContinueButton: true,
            );
          }
        }
      }
    } catch (e) {
      print('[POLLING ERROR] $e');
    }
  }
  
  void _continueToBookScan() {
    // Chuyển sang màn hình quét barcode với control chủ động
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => IoTBarcodeScanningScreen(
          studentData: _studentData!,
        ),
      ),
    );
  }
  
  void _resetScan() {
    setState(() {
      _studentData = null;
      _bookData = null;
      _hasShownStudentSuccess = false;
      _hasShownBookSuccess = false;
      _waitingForUserConfirmation = false;
      _currentStep = 'Vui lòng quét thẻ sinh viên...';
    });
    
    _pollingTimer?.cancel();
    _startPolling();
  }

  void _connectToIoT() {
    setState(() {
      _isScanning = true;
      _currentStep = 'Đang kết nối với thiết bị IoT...';
    });
    context.read<IoTBloc>().add(IoTConnectRequested());
  }



  void _navigateToForm() {
    print('[IOT] Navigating to form with:');
    print('[IOT] Student: $_studentData');
    print('[IOT] Book: $_bookData');
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BorrowFormScreen(
          borrowId: null,
          iotStudentData: _studentData,
          iotBookData: _bookData,
        ),
      ),
    );
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
        title: const Text('Quét IoT'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildStatusCard(),
          const SizedBox(height: 32),
          _buildProgressIndicator(),
          const SizedBox(height: 32),
          _buildInstructions(),
          const SizedBox(height: 32),
          if (_studentData != null) _buildStudentCard(),
          if (_bookData != null) ...[
            const SizedBox(height: 16),
            _buildBookCard(),
          ],
          
          // Nút quét lại khi đang ở bước quét sách
          if (_studentData != null && _bookData == null && !_waitingForUserConfirmation) ...[
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text(
              'Quét lại từ đầu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Nếu không quét được barcode, hãy thử quét lại',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    IconData icon;
    Color color;
    String status;

    if (_bookData != null) {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
      status = 'Hoàn tất';
    } else if (_studentData != null) {
      icon = Icons.sync_rounded;
      color = Colors.orange;
      status = 'Đang chờ quét sách';
    } else {
      icon = Icons.qr_code_scanner_rounded;
      color = Colors.blue;
      status = 'Sẵn sàng';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            status,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        _buildStepIndicator(
          number: '1',
          label: 'Quét thẻ',
          isCompleted: _studentData != null,
          isActive: _studentData == null,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _studentData != null ? Colors.green : Colors.grey[300],
          ),
        ),
        _buildStepIndicator(
          number: '2',
          label: 'Quét sách',
          isCompleted: _bookData != null,
          isActive: _studentData != null && _bookData == null,
        ),
      ],
    );
  }

  Widget _buildStepIndicator({
    required String number,
    required String label,
    required bool isCompleted,
    required bool isActive,
  }) {
    Color color;
    if (isCompleted) {
      color = Colors.green;
    } else if (isActive) {
      color = const Color(0xFF4E9AF1);
    } else {
      color = Colors.grey;
    }

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : Colors.white,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    number,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Hướng dẫn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1. Đặt thẻ sinh viên lên đầu đọc RFID'),
          _buildInstructionItem('2. Chờ hệ thống xác nhận thông tin'),
          _buildInstructionItem('3. Đưa sách vào trước camera để quét barcode'),
          _buildInstructionItem('4. Hệ thống sẽ tự động điền form'),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4E9AF1).withOpacity(0.1), Color(0xFF7C3AED).withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4E9AF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thông tin sinh viên',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Họ tên', _studentData?['name'] ?? 'N/A'),
          _buildInfoRow('MSSV', _studentData?['studentId'] ?? 'N/A'),
          _buildInfoRow('Lớp', _studentData?['class'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildBookCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.withOpacity(0.1), Colors.teal.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.book_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Thông tin sách',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Tên sách', _bookData?['title'] ?? 'N/A'),
          _buildInfoRow('Mã sách', _bookData?['bookCode'] ?? 'N/A'),
          _buildInfoRow('Tác giả', _bookData?['author'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    bool showContinueButton = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon với animation
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 60,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Buttons
              if (showContinueButton) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _continueToBookScan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Tiếp tục quét sách',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetScan();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: color),
                    ),
                    child: Text(
                      'Quét lại thẻ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Auto close after showing book success
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
