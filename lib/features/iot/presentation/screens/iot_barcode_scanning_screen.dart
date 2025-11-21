import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../tuan_borrow_management/presentation/screens/borrow_form_screen.dart';

class IoTBarcodeScanningScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;

  const IoTBarcodeScanningScreen({
    super.key,
    required this.studentData,
  });

  @override
  State<IoTBarcodeScanningScreen> createState() =>
      _IoTBarcodeScanningScreenState();
}

class _IoTBarcodeScanningScreenState extends State<IoTBarcodeScanningScreen> {
  Map<String, dynamic>? _bookData;
  bool _isScanning = false;
  String _statusMessage = 'Nhấn nút "Quét sách" để bắt đầu';
  int _scanAttempts = 0;

  @override
  void dispose() {
    // Reset session trên ESP32 Hub khi thoát màn hình
    _resetEsp32Session();
    super.dispose();
  }

  Future<void> _resetEsp32Session() async {
    try {
      const String esp32HubIp = '172.20.10.2';
      final resetUrl = 'http://$esp32HubIp/reset-session';
      
      print('[RESET] Resetting ESP32 Hub session...');
      
      await http.post(
        Uri.parse(resetUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      print('[RESET] ESP32 Hub session reset successfully');
    } catch (e) {
      print('[RESET ERROR] $e');
      // Không cần hiển thị lỗi vì đang thoát màn hình
    }
  }

  Future<void> _triggerCameraScan() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Đang kích hoạt camera...';
      _scanAttempts++;
    });

    try {
      // Gửi lệnh trigger trực tiếp đến ESP32 Hub
      const String esp32HubIp = '172.20.10.2'; // IP của ESP32 Hub
      final triggerUrl = 'http://$esp32HubIp/trigger-capture';

      print('[CAMERA TRIGGER] Sending to ESP32 Hub: $triggerUrl');

      final triggerResponse = await http.post(
        Uri.parse(triggerUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'capture',
          'student_id': widget.studentData['studentId'],
        }),
      ).timeout(const Duration(seconds: 5));

      print('[CAMERA TRIGGER] Response: ${triggerResponse.statusCode}');

      if (triggerResponse.statusCode == 200) {
        setState(() {
          _statusMessage = 'Camera đang quét... Đưa sách vào khung hình';
        });

        // Chờ 10 giây để camera quét và xử lý
        await Future.delayed(const Duration(seconds: 10));

        // Kiểm tra kết quả
        await _checkScanResult();
      } else {
        _showError('Không thể kích hoạt camera (${triggerResponse.statusCode})');
        setState(() {
          _isScanning = false;
          _statusMessage = 'Lỗi kết nối. Nhấn "Quét lại" để thử lại';
        });
      }
    } catch (e) {
      print('[CAMERA TRIGGER ERROR] $e');
      _showError('Lỗi: $e');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Lỗi kết nối. Nhấn "Quét lại" để thử lại';
      });
    }
  }

  Future<void> _checkScanResult() async {
    try {
      const String apiUrl = 'http://172.20.10.5:3000/api/iot/scan-session';

      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        print('[CHECK RESULT] Full response: $data');

        if (data['success'] == true && data['data']['book'] != null) {
          // Quét thành công!
          final bookData = data['data']['book'];
          print('[CHECK RESULT] Book data: $bookData');
          
          setState(() {
            _bookData = bookData;
            _statusMessage = 'Quét thành công!';
            _isScanning = false;
          });

          _showSuccessDialog();
        } else {
          // Chưa quét được
          setState(() {
            _isScanning = false;
            _statusMessage =
                'Không quét được barcode. Nhấn "Quét lại" để thử lại';
          });

          _showRetrySnackbar();
        }
      }
    } catch (e) {
      print('[CHECK RESULT ERROR] $e');
      setState(() {
        _isScanning = false;
        _statusMessage = 'Lỗi kiểm tra kết quả. Nhấn "Quét lại" để thử lại';
      });
    }
  }

  void _showSuccessDialog() {
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
                Colors.green.withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 500),
                tween: Tween<double>(begin: 0, end: 1),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 60,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Quét sách thành công!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _bookData?['title'] ?? 'N/A',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _navigateToForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Tiếp tục',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRetrySnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Lần thử ${_scanAttempts}: Không quét được. Thử lại',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToForm() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BorrowFormScreen(
          borrowId: null,
          iotStudentData: widget.studentData,
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
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            ),
          ),
        ),
        title: const Text('Quét mã sách'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
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
          const SizedBox(height: 20),
          _buildStudentCard(),
          const SizedBox(height: 32),
          _buildStatusCard(),
          const SizedBox(height: 32),
          _buildScanButton(),
          const SizedBox(height: 24),
          if (_bookData != null) _buildBookCard(),
          if (_scanAttempts > 0 && _bookData == null) _buildTipsCard(),
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    // Debug: In ra studentData để kiểm tra
    print('[STUDENT CARD] studentData: ${widget.studentData}');
    print('[STUDENT CARD] Keys: ${widget.studentData.keys.toList()}');
    
    // Lấy MSSV từ nhiều key có thể - thử tất cả các biến thể
    String studentId = 'N/A';
    String className = 'N/A';
    String name = 'N/A';
    
    // Thử tất cả các key có thể cho student_id
    for (var key in ['studentId', 'student_id', 'borrowerStudentId', 'borrower_student_id', 'id']) {
      if (widget.studentData.containsKey(key) && widget.studentData[key] != null && widget.studentData[key].toString().isNotEmpty) {
        studentId = widget.studentData[key].toString();
        break;
      }
    }
    
    // Thử tất cả các key có thể cho class
    for (var key in ['class', 'class_name', 'borrowerClass', 'borrower_class', 'className']) {
      if (widget.studentData.containsKey(key) && widget.studentData[key] != null && widget.studentData[key].toString().isNotEmpty) {
        className = widget.studentData[key].toString();
        break;
      }
    }
    
    // Thử tất cả các key có thể cho name
    for (var key in ['name', 'borrowerName', 'borrower_name', 'fullName', 'full_name']) {
      if (widget.studentData.containsKey(key) && widget.studentData[key] != null && widget.studentData[key].toString().isNotEmpty) {
        name = widget.studentData[key].toString();
        break;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4E9AF1).withOpacity(0.1),
            const Color(0xFF7C3AED).withOpacity(0.1)
          ],
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 20),
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
          _buildInfoRow('Họ tên', name),
          _buildInfoRow('MSSV', studentId),
          _buildInfoRow('Lớp', className),
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
    } else if (_isScanning) {
      icon = Icons.camera_alt_rounded;
      color = Colors.orange;
      status = 'Đang quét...';
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
          if (_isScanning)
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          else
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
            _statusMessage,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (_scanAttempts > 0 && !_isScanning && _bookData == null) ...[
            const SizedBox(height: 12),
            Text(
              'Số lần thử: $_scanAttempts',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _isScanning || _bookData != null ? null : _triggerCameraScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: _isScanning || _bookData != null ? 0 : 4,
            ),
            icon: Icon(
              _bookData != null
                  ? Icons.check_circle
                  : (_isScanning ? Icons.camera_alt : Icons.qr_code_scanner),
              size: 28,
              color: _isScanning || _bookData != null ? Colors.grey : Colors.white,
            ),
            label: Text(
              _bookData != null
                  ? 'Đã quét xong'
                  : (_isScanning ? 'Đang quét...' : 'Quét sách'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _isScanning || _bookData != null ? Colors.grey : Colors.white,
              ),
            ),
          ),
        ),
        if (_scanAttempts > 0 && _bookData == null && !_isScanning) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _triggerCameraScan,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.orange, size: 24),
              label: const Text(
                'Quét lại',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBookCard() {
    // Debug: In ra bookData để kiểm tra
    print('[BOOK CARD] bookData: $_bookData');
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.1),
            Colors.teal.withOpacity(0.1)
          ],
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
                child: const Icon(Icons.book_rounded,
                    color: Colors.white, size: 20),
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
          _buildInfoRow('Mã sách', _bookData?['bookCode'] ?? _bookData?['book_code'] ?? 'N/A'),
          _buildInfoRow('Tác giả', _bookData?['author'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Mẹo quét barcode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('Đặt sách cách camera 15-20cm'),
          _buildTipItem('Đảm bảo barcode rõ nét, không bị mờ'),
          _buildTipItem('Ánh sáng đủ, không quá tối hoặc quá sáng'),
          _buildTipItem('Giữ sách thẳng, không bị nghiêng'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline,
              size: 14, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
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
