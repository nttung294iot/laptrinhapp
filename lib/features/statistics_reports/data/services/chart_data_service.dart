import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../shared/models/borrow_card.dart';
import '../models/statistics_data.dart';

/// Service to format data for charts
class ChartDataService {
  /// Convert user statistics to bar chart data
  List<BarChartGroupData> convertUserStatsToBarChart(
    List<UserStatistics> userStats, {
    int maxUsers = 10,
  }) {
    // Sort by total borrows and take top users
    final sortedStats = List<UserStatistics>.from(userStats)
      ..sort((a, b) => b.totalBorrows.compareTo(a.totalBorrows));
    
    final topUsers = sortedStats.take(maxUsers).toList();
    
    return topUsers.asMap().entries.map((entry) {
      final index = entry.key;
      final stats = entry.value;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: stats.totalBorrows.toDouble(),
            color: _getUserBarColor(stats),
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  /// Convert monthly statistics to line chart data
  List<FlSpot> convertMonthlyStatsToLineChart(
    List<MonthlyStatistics> monthlyStats,
  ) {
    return monthlyStats.asMap().entries.map((entry) {
      final index = entry.key;
      final stats = entry.value;
      
      return FlSpot(
        index.toDouble(),
        stats.totalBorrows.toDouble(),
      );
    }).toList();
  }

  /// Convert borrow status data to pie chart
  List<PieChartSectionData> convertStatusToPieChart(
    StatisticsSummary summary,
  ) {
    final total = summary.totalBorrows.toDouble();
    if (total == 0) return [];

    return [
      PieChartSectionData(
        color: const Color(0xFF4CAF50), // Green for returned
        value: summary.returnedBorrows.toDouble(),
        title: 'Đã trả\n${summary.returnedBorrows}',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFF2196F3), // Blue for active
        value: summary.activeBorrows.toDouble(),
        title: 'Đang mượn\n${summary.activeBorrows}',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        color: const Color(0xFFF44336), // Red for overdue
        value: summary.overdueBorrows.toDouble(),
        title: 'Quá hạn\n${summary.overdueBorrows}',
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  /// Convert monthly data to multiple line chart (borrows vs returns)
  List<LineChartBarData> convertMonthlyToMultiLineChart(
    List<MonthlyStatistics> monthlyStats,
  ) {
    final borrowSpots = monthlyStats.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalBorrows.toDouble());
    }).toList();

    final returnSpots = monthlyStats.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.totalReturns.toDouble());
    }).toList();

    return [
      LineChartBarData(
        spots: borrowSpots,
        isCurved: true,
        color: const Color(0xFF2196F3),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFF2196F3).withOpacity(0.1),
        ),
      ),
      LineChartBarData(
        spots: returnSpots,
        isCurved: true,
        color: const Color(0xFF4CAF50),
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          color: const Color(0xFF4CAF50).withOpacity(0.1),
        ),
      ),
    ];
  }

  /// Generate chart data points from borrow cards
  List<ChartDataPoint> generateChartDataPoints(
    List<BorrowCard> borrowCards,
    ChartDataType type,
  ) {
    switch (type) {
      case ChartDataType.borrowsByMonth:
        return _generateMonthlyBorrowPoints(borrowCards);
      case ChartDataType.borrowsByUser:
        return _generateUserBorrowPoints(borrowCards);
      case ChartDataType.borrowsByBook:
        return _generateBookBorrowPoints(borrowCards);
      case ChartDataType.borrowsByStatus:
        return _generateStatusPoints(borrowCards);
    }
  }

  List<ChartDataPoint> _generateMonthlyBorrowPoints(List<BorrowCard> cards) {
    final monthlyCount = <String, int>{};
    
    for (final card in cards) {
      final monthKey = '${card.borrowDate.year}-${card.borrowDate.month.toString().padLeft(2, '0')}';
      monthlyCount[monthKey] = (monthlyCount[monthKey] ?? 0) + 1;
    }

    return monthlyCount.entries.map((entry) {
      return ChartDataPoint(
        label: entry.key,
        value: entry.value.toDouble(),
        date: DateTime.parse('${entry.key}-01'),
      );
    }).toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
  }

  List<ChartDataPoint> _generateUserBorrowPoints(List<BorrowCard> cards) {
    final userCount = <String, int>{};
    
    for (final card in cards) {
      userCount[card.borrowerName] = (userCount[card.borrowerName] ?? 0) + 1;
    }

    return userCount.entries.map((entry) {
      return ChartDataPoint(
        label: entry.key,
        value: entry.value.toDouble(),
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  List<ChartDataPoint> _generateBookBorrowPoints(List<BorrowCard> cards) {
    final bookCount = <String, int>{};
    
    for (final card in cards) {
      bookCount[card.bookName] = (bookCount[card.bookName] ?? 0) + 1;
    }

    return bookCount.entries.map((entry) {
      return ChartDataPoint(
        label: entry.key,
        value: entry.value.toDouble(),
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  List<ChartDataPoint> _generateStatusPoints(List<BorrowCard> cards) {
    final statusCount = <BorrowStatus, int>{};
    
    for (final card in cards) {
      final status = card.isOverdue ? BorrowStatus.overdue : card.status;
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }

    return statusCount.entries.map((entry) {
      return ChartDataPoint(
        label: _getStatusLabel(entry.key),
        value: entry.value.toDouble(),
      );
    }).toList();
  }

  String _getStatusLabel(BorrowStatus status) {
    switch (status) {
      case BorrowStatus.borrowed:
        return 'Đang mượn';
      case BorrowStatus.returned:
        return 'Đã trả';
      case BorrowStatus.overdue:
        return 'Quá hạn';
    }
  }

  Color _getUserBarColor(UserStatistics stats) {
    if (stats.overdueBorrows > 0) {
      return const Color(0xFFF44336); // Red for users with overdue books
    } else if (stats.activeBorrows > 0) {
      return const Color(0xFF2196F3); // Blue for users with active borrows
    } else {
      return const Color(0xFF4CAF50); // Green for users with only returned books
    }
  }

  /// Get X-axis labels for monthly chart
  List<String> getMonthlyLabels(List<MonthlyStatistics> monthlyStats) {
    return monthlyStats.map((stats) => stats.monthName).toList();
  }

  /// Get X-axis labels for user chart
  List<String> getUserLabels(List<UserStatistics> userStats, {int maxUsers = 10}) {
    final sortedStats = List<UserStatistics>.from(userStats)
      ..sort((a, b) => b.totalBorrows.compareTo(a.totalBorrows));
    
    return sortedStats
        .take(maxUsers)
        .map((stats) => stats.borrowerName)
        .toList();
  }

  /// Get full user names without truncation
  List<String> getFullUserLabels(List<UserStatistics> userStats, {int maxUsers = 10}) {
    final sortedStats = List<UserStatistics>.from(userStats)
      ..sort((a, b) => b.totalBorrows.compareTo(a.totalBorrows));
    
    return sortedStats
        .take(maxUsers)
        .map((stats) => stats.borrowerName)
        .toList();
  }
}

enum ChartDataType {
  borrowsByMonth,
  borrowsByUser,
  borrowsByBook,
  borrowsByStatus,
}