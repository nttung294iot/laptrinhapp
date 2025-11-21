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
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:3000/api/iot/scan-session'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Có cả thẻ và sách rồi!
          setState(() {
            _studentData = data['data']['student'];
            _bookData = data['data']['book'];
            _currentStep = 'Hoàn tất! Đang chuyển đến form...';
          });
          
          _pollingTimer?.cancel();
          _showSuccess('Quét thành công!');
          
          // Chờ 1 giây rồi chuyển sang form
          Future.delayed(const Duration(seconds: 1), () {
            _navigateToForm();
          });
        } else if (data['status'] == 'waiting_book') {
          // Đã có thẻ, chờ sách
          setState(() {
            _studentData = data['student'];
            _currentStep = 'Đã quét thẻ sinh viên. Vui lòng quét mã sách...';
          });
          _showSuccess('Đã quét thẻ: ${_studentData?['name']}');
        }
      }
    } catch (e) {
      print('[POLLING ERROR] $e');
    }
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
        ],
      ),
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
