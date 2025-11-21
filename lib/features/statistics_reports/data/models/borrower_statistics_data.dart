import 'package:equatable/equatable.dart';

/// Time period for statistics
enum TimePeriod {
  week,
  month,
  quarter,
  year,
}

/// Model for borrower statistics data
class BorrowerStatisticsData extends Equatable {
  final String borrowerName;
  final int totalBorrows;
  final int activeBorrows;
  final int returnedBorrows;
  final int overdueBorrows;
  final List<PeriodData> periodData;
  final List<BorrowedBookInfo> borrowedBooks;
  final TimePeriod period;

  const BorrowerStatisticsData({
    required this.borrowerName,
    required this.totalBorrows,
    required this.activeBorrows,
    required this.returnedBorrows,
    required this.overdueBorrows,
    required this.periodData,
    required this.borrowedBooks,
    required this.period,
  });

  @override
  List<Object?> get props => [
        borrowerName,
        totalBorrows,
        activeBorrows,
        returnedBorrows,
        overdueBorrows,
        periodData,
        borrowedBooks,
        period,
      ];
}

/// Model for period data (week/month/quarter/year)
class PeriodData extends Equatable {
  final String label;
  final int count;
  final DateTime startDate;
  final DateTime endDate;

  const PeriodData({
    required this.label,
    required this.count,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [label, count, startDate, endDate];
}

/// Model for borrowed book information
class BorrowedBookInfo extends Equatable {
  final String bookName;
  final int borrowCount;
  final DateTime? lastBorrowDate;

  const BorrowedBookInfo({
    required this.bookName,
    required this.borrowCount,
    this.lastBorrowDate,
  });

  @override
  List<Object?> get props => [bookName, borrowCount, lastBorrowDate];
}
