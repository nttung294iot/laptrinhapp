import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/statistics_data.dart';
import '../bloc/borrower_statistics_bloc.dart';
import '../screens/borrower_detail_statistics_screen.dart';
import '../../data/services/borrower_statistics_service.dart';
import '../../../../config/injection/injection.dart';

class BorrowerListWidget extends StatelessWidget {
  final List<UserStatistics> userStatistics;

  const BorrowerListWidget({
    super.key,
    required this.userStatistics,
  });

  @override
  Widget build(BuildContext context) {
    if (userStatistics.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Không có dữ liệu người mượn',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userStatistics.length,
      itemBuilder: (context, index) {
        final borrower = userStatistics[index];
        return _buildBorrowerCard(context, borrower);
      },
    );
  }

  Widget _buildBorrowerCard(BuildContext context, UserStatistics borrower) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToBorrowerDetail(context, borrower.borrowerName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A11CB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Color(0xFF6A11CB),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          borrower.borrowerName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tổng: ${borrower.totalBorrows} lần mượn',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatChip(
                    'Đang mượn',
                    borrower.activeBorrows.toString(),
                    const Color(0xFF38A169),
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    'Đã trả',
                    borrower.returnedBorrows.toString(),
                    const Color(0xFF3182CE),
                  ),
                  const SizedBox(width: 8),
                  _buildStatChip(
                    'Quá hạn',
                    borrower.overdueBorrows.toString(),
                    const Color(0xFFE53E3E),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBorrowerDetail(BuildContext context, String borrowerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => BorrowerStatisticsBloc(
            statisticsService: getIt<BorrowerStatisticsService>(),
          ),
          child: BorrowerDetailStatisticsScreen(borrowerName: borrowerName),
        ),
      ),
    );
  }
}
