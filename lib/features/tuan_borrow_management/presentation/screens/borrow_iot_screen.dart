import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:async';
import '../../domain/entities/borrow_form_data.dart';
import 'borrow_form_screen.dart';

/// Màn hình quét IoT để tạo thẻ mượn
class BorrowIoTScreen extends StatefulWidget {
  const BorrowIoTScreen({Key? key}) : super(key: key);

  @override
  State<BorrowIoTScreen> createState() => _BorrowIoTScreenState();
}

class _BorrowIoTScreenState extends State<BorrowIoTScreen> {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  
  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionStatus = 'Đang kết nối...';
  
  // Scanned data
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _bookData;
  
  // ESP32 IP - SỬA CHO ĐÚNG VỚI IP CỦA BẠN!
  static const String ESP32_IP = '172.20.10.2';
  static const int WS_PORT = 81;

  @override
  void initState() {
    super.initState();
    _connectToESP32();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _connectToESP32() {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Đang kết nối tới ESP32...';
    });

    try {
      final wsUrl = Uri.parse('ws://$ESP32_IP:$WS_PORT');
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('⚠️ WebSocket closed');
          _handleDisconnect();
        },
      );

      // Set connected after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isConnected = true;
            _isConnecting = false;
            _connectionStatus = 'Đã kết nối';
          });
        }
      });
    } catch (e) {
      print('❌ Connection error: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectionStatus = 'Mất kết nối';
      });
    }

    // Auto reconnect after 3 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isConnected) {
        _connectToESP32();
      }
    });
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = json.decode(message);
      print('📨 Received: $data');

      final type = data['type'];
      
      if (type == 'student_scanned') {
        // Nhận thông tin sinh viên từ ESP32
        setState(() {
          _studentData = {
            'name': data['data']['reader']['name'],
            'student_id': data['data']['reader']['student_id'],
            'class': data['data']['reader']['class'],
            'phone': data['data']['reader']['phone'],
            'email': data['data']['reader']['email'],
          };
        });
        
        _showSnackBar('✅ Đã quét thẻ sinh viên: ${_studentData!['name']}', Colors.green);
      } else if (type == 'book_scanned') {
        // Nhận thông tin sách từ ESP32
        setState(() {
          _bookData = {
            'book_code': data['data']['book']['book_code'],
            'title': data['data']['book']['title'],
            'author': data['data']['book']['author'],
            'category': data['data']['book']['category'],
          };
        });
        
        _showSnackBar('✅ Đã quét sách: ${_bookData!['title']}', Colors.green);
      }
    } catch (e) {
      print('❌ Parse error: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _continueToForm() {
    if (_studentData == null) {
      _showSnackBar('⚠️ Vui lòng quét thẻ sinh viên trước', Colors.orange);
      return;
    }

    if (_bookData == null) {
      _showSnackBar('⚠️ Vui lòng quét sách trước', Colors.orange);
      return;
    }

    // Navigate to form with pre-filled data
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => BorrowFormScreen(
          prefilledData: BorrowFormData(
            borrowerName: _studentData!['name'] ?? '',
            borrowerClass: _studentData!['class'],
            borrowerStudentId: _studentData!['student_id'],
            borrowerPhone: _studentData!['phone'],
            borrowerEmail: _studentData!['email'],
            bookName: _bookData!['title'] ?? '',
            bookCode: _bookData!['book_code'],
            borrowDate: DateTime.now(),
            expectedReturnDate: DateTime.now().add(const Duration(days: 14)),
          ),
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
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
          ),
        ),
        title: const Text('Quét IoT'),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isConnected 
                      ? Colors.white.withOpacity(0.2)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.greenAccent : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isConnected ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            _buildConnectionCard(),
            
            const SizedBox(height: 24),
            
            // Instructions
            _buildInstructionsCard(),
            
            const SizedBox(height: 24),
            
            // Student Data Card
            _buildDataCard(
              title: 'Thông tin sinh viên',
              icon: Icons.person_rounded,
              data: _studentData,
              fields: [
                {'label': 'Tên', 'key': 'name'},
                {'label': 'MSSV', 'key': 'student_id'},
                {'label': 'Lớp', 'key': 'class'},
              ],
              gradient: const LinearGradient(
                colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Book Data Card
            _buildDataCard(
              title: 'Thông tin sách',
              icon: Icons.book_rounded,
              data: _bookData,
              fields: [
                {'label': 'Tên sách', 'key': 'title'},
                {'label': 'Mã sách', 'key': 'book_code'},
                {'label': 'Tác giả', 'key': 'author'},
              ],
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Continue Button
            if (_studentData != null && _bookData != null)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _continueToForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Tiếp tục tạo thẻ mượn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.error,
            color: _isConnected ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectionStatus,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.green[900] : Colors.red[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isConnected 
                      ? 'ESP32 đã sẵn sàng nhận quét'
                      : 'Đang thử kết nối lại...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_rounded, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Text(
                'Hướng dẫn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep('1', 'Quét thẻ RFID của sinh viên'),
          const SizedBox(height: 8),
          _buildInstructionStep('2', 'Quét barcode trên sách'),
          const SizedBox(height: 8),
          _buildInstructionStep('3', 'Nhấn "Tiếp tục" để hoàn tất'),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue[700],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic>? data,
    required List<Map<String, String>> fields,
    required Gradient gradient,
  }) {
    final hasData = data != null;
    
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
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (hasData)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, 
                        size: 48, 
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Chưa quét',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...fields.map((field) {
                final value = data[field['key']] ?? '-';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${field['label']}:',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
