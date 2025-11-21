import 'package:flutter/material.dart';
import 'borrow_form_screen.dart';
import 'borrow_iot_screen.dart';

/// Màn hình chọn phương thức tạo thẻ mượn
class BorrowMethodSelectionScreen extends StatelessWidget {
  const BorrowMethodSelectionScreen({Key? key}) : super(key: key);

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
        title: const Text('Chọn phương thức'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title
            Text(
              'Chọn cách tạo thẻ mượn',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Bạn muốn nhập thông tin thủ công hay sử dụng thiết bị IoT?',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Manual Method Card
            _MethodCard(
              icon: Icons.edit_rounded,
              title: 'Nhập thủ công',
              description: 'Nhập thông tin người mượn và sách bằng tay',
              gradient: const LinearGradient(
                colors: [Color(0xFF4E9AF1), Color(0xFF7C3AED)],
              ),
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const BorrowFormScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // IoT Method Card
            _MethodCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Quét bằng IoT',
              description: 'Quét thẻ RFID và barcode sách tự động',
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              badge: 'MỚI',
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const BorrowIoTScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;
  final String? badge;
  final VoidCallback onTap;

  const _MethodCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    this.badge,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon with gradient background
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Arrow icon
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
