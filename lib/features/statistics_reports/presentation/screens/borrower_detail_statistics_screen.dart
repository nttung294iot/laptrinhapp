import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import '../bloc/borrower_statistics_bloc.dart';
import '../../data/models/borrower_statistics_data.dart';

class BorrowerDetailStatisticsScreen extends StatefulWidget {
  final String borrowerName;

  const BorrowerDetailStatisticsScreen({
    super.key,
    required this.borrowerName,
  });

  @override
  State<BorrowerDetailStatisticsScreen> createState() => _BorrowerDetailStatisticsScreenState();
}

class _BorrowerDetailStatisticsScreenState extends State<BorrowerDetailStatisticsScreen> {
  TimePeriod _selectedPeriod = TimePeriod.month;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  void _loadStatistics() {
    context.read<BorrowerStatisticsBloc>().add(
      LoadBorrowerStatisticsEvent(
        borrowerName: widget.borrowerName,
        period: _selectedPeriod,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildPeriodSelector(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thống kê người mượn',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.borrowerName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadStatistics,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPeriodButton('Tuần', TimePeriod.week),
          _buildPeriodButton('Tháng', TimePeriod.month),
          _buildPeriodButton('Quý', TimePeriod.quarter),
          _buildPeriodButton('Năm', TimePeriod.year),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, TimePeriod period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
          _loadStatistics();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? const Color(0xFF6A11CB) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return BlocBuilder<BorrowerStatisticsBloc, BorrowerStatisticsState>(
      builder: (context, state) {
        if (state is BorrowerStatisticsLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is BorrowerStatisticsLoaded) {
          return _buildStatisticsContent(state.statistics);
        } else if (state is BorrowerStatisticsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStatisticsContent(BorrowerStatisticsData statistics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(statistics),
          const SizedBox(height: 24),
          _buildChart(statistics),
          const SizedBox(height: 24),
          _buildBooksList(statistics),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BorrowerStatisticsData statistics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Tổng mượn',
                statistics.totalBorrows.toString(),
                Icons.library_books,
                const Color(0xFF3182CE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Đang mượn',
                statistics.activeBorrows.toString(),
                Icons.schedule,
                const Color(0xFF38A169),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Đã trả',
                statistics.returnedBorrows.toString(),
                Icons.check_circle,
                const Color(0xFF38A169),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Quá hạn',
                statistics.overdueBorrows.toString(),
                Icons.warning,
                const Color(0xFFE53E3E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BorrowerStatisticsData statistics) {
    if (statistics.periodData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Biểu đồ mượn sách',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: statistics.periodData.map((e) => e.count.toDouble()).reduce((a, b) => a > b ? a : b) + 2,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < statistics.periodData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            statistics.periodData[value.toInt()].label,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
              ),
              borderData: FlBorderData(show: false),
              barGroups: statistics.periodData.asMap().entries.map((entry) {
                return BarChartGroupData(
                  x: entry.key,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.count.toDouble(),
                      color: const Color(0xFF6A11CB),
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBooksList(BorrowerStatisticsData statistics) {
    if (statistics.borrowedBooks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sách đã mượn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        ...statistics.borrowedBooks.map((book) => _buildBookItem(book)),
      ],
    );
  }

  Widget _buildBookItem(BorrowedBookInfo book) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6A11CB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.menu_book,
              color: Color(0xFF6A11CB),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.bookName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Số lần mượn: ${book.borrowCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
