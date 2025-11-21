import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/repositories/borrow_card_repository.dart';
import '../../../../shared/models/borrow_card.dart';
import '../models/borrower_statistics_data.dart';

class BorrowerStatisticsService {
  final BorrowCardRepository borrowCardRepository;

  BorrowerStatisticsService({
    required this.borrowCardRepository,
  });

  Future<Either<Failure, BorrowerStatisticsData>> getBorrowerStatistics({
    required String borrowerName,
    required TimePeriod period,
  }) async {
    try {
      // Get all borrow cards for this borrower
      final borrowCardsResult = await borrowCardRepository.getAll();

      return borrowCardsResult.fold(
        (failure) => Left(failure),
        (allCards) {
          // Filter cards for this borrower
          final borrowerCards = allCards
              .where((card) => card.borrowerName == borrowerName)
              .toList();

          if (borrowerCards.isEmpty) {
            return Right(BorrowerStatisticsData(
              borrowerName: borrowerName,
              totalBorrows: 0,
              activeBorrows: 0,
              returnedBorrows: 0,
              overdueBorrows: 0,
              periodData: const [],
              borrowedBooks: const [],
              period: period,
            ));
          }

          // Calculate basic statistics
          final totalBorrows = borrowerCards.length;
          final activeBorrows = borrowerCards
              .where((c) => c.status == BorrowStatus.borrowed && !c.isOverdue)
              .length;
          final returnedBorrows = borrowerCards
              .where((c) => c.status == BorrowStatus.returned)
              .length;
          final overdueBorrows = borrowerCards
              .where((c) => c.isOverdue)
              .length;

          // Calculate period data
          final periodData = _calculatePeriodData(borrowerCards, period);

          // Calculate borrowed books info
          final borrowedBooks = _calculateBorrowedBooks(borrowerCards);

          return Right(BorrowerStatisticsData(
            borrowerName: borrowerName,
            totalBorrows: totalBorrows,
            activeBorrows: activeBorrows,
            returnedBorrows: returnedBorrows,
            overdueBorrows: overdueBorrows,
            periodData: periodData,
            borrowedBooks: borrowedBooks,
            period: period,
          ));
        },
      );
    } catch (e) {
      return Left(DatabaseFailure('Lỗi khi lấy thống kê người mượn: $e'));
    }
  }

  List<PeriodData> _calculatePeriodData(List<BorrowCard> cards, TimePeriod period) {
    final now = DateTime.now();
    final periodDataMap = <String, PeriodData>{};

    // Determine the number of periods to show and calculate date ranges
    List<DateRange> dateRanges;
    switch (period) {
      case TimePeriod.week:
        dateRanges = _getWeekRanges(now, 12); // Last 12 weeks
        break;
      case TimePeriod.month:
        dateRanges = _getMonthRanges(now, 12); // Last 12 months
        break;
      case TimePeriod.quarter:
        dateRanges = _getQuarterRanges(now, 8); // Last 8 quarters
        break;
      case TimePeriod.year:
        dateRanges = _getYearRanges(now, 5); // Last 5 years
        break;
    }

    // Initialize all periods with 0 count
    for (final range in dateRanges) {
      periodDataMap[range.label] = PeriodData(
        label: range.label,
        count: 0,
        startDate: range.startDate,
        endDate: range.endDate,
      );
    }

    // Count borrows in each period
    for (final card in cards) {
      for (final range in dateRanges) {
        if (card.borrowDate.isAfter(range.startDate.subtract(const Duration(days: 1))) &&
            card.borrowDate.isBefore(range.endDate.add(const Duration(days: 1)))) {
          final current = periodDataMap[range.label]!;
          periodDataMap[range.label] = PeriodData(
            label: current.label,
            count: current.count + 1,
            startDate: current.startDate,
            endDate: current.endDate,
          );
          break;
        }
      }
    }

    return periodDataMap.values.toList();
  }

  List<DateRange> _getWeekRanges(DateTime now, int count) {
    final ranges = <DateRange>[];
    for (int i = count - 1; i >= 0; i--) {
      final endDate = now.subtract(Duration(days: i * 7));
      final startDate = endDate.subtract(const Duration(days: 6));
      ranges.add(DateRange(
        label: 'T${count - i}',
        startDate: startDate,
        endDate: endDate,
      ));
    }
    return ranges;
  }

  List<DateRange> _getMonthRanges(DateTime now, int count) {
    final ranges = <DateRange>[];
    for (int i = count - 1; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final startDate = DateTime(targetDate.year, targetDate.month, 1);
      final endDate = DateTime(targetDate.year, targetDate.month + 1, 0);
      ranges.add(DateRange(
        label: 'T${targetDate.month}',
        startDate: startDate,
        endDate: endDate,
      ));
    }
    return ranges;
  }

  List<DateRange> _getQuarterRanges(DateTime now, int count) {
    final ranges = <DateRange>[];
    final currentQuarter = ((now.month - 1) ~/ 3) + 1;
    final currentYear = now.year;

    for (int i = count - 1; i >= 0; i--) {
      final quarterOffset = currentQuarter - i;
      final yearOffset = (quarterOffset - 1) ~/ 4;
      final quarter = ((quarterOffset - 1) % 4) + 1;
      final year = currentYear + yearOffset;

      final startMonth = (quarter - 1) * 3 + 1;
      final startDate = DateTime(year, startMonth, 1);
      final endDate = DateTime(year, startMonth + 3, 0);

      ranges.add(DateRange(
        label: 'Q$quarter',
        startDate: startDate,
        endDate: endDate,
      ));
    }
    return ranges;
  }

  List<DateRange> _getYearRanges(DateTime now, int count) {
    final ranges = <DateRange>[];
    for (int i = count - 1; i >= 0; i--) {
      final year = now.year - i;
      final startDate = DateTime(year, 1, 1);
      final endDate = DateTime(year, 12, 31);
      ranges.add(DateRange(
        label: year.toString(),
        startDate: startDate,
        endDate: endDate,
      ));
    }
    return ranges;
  }

  List<BorrowedBookInfo> _calculateBorrowedBooks(List<BorrowCard> cards) {
    final bookMap = <String, BorrowedBookInfo>{};

    for (final card in cards) {
      if (!bookMap.containsKey(card.bookName)) {
        bookMap[card.bookName] = BorrowedBookInfo(
          bookName: card.bookName,
          borrowCount: 0,
        );
      }

      final current = bookMap[card.bookName]!;
      final lastDate = current.lastBorrowDate;
      bookMap[card.bookName] = BorrowedBookInfo(
        bookName: current.bookName,
        borrowCount: current.borrowCount + 1,
        lastBorrowDate: lastDate == null || card.borrowDate.isAfter(lastDate)
            ? card.borrowDate
            : lastDate,
      );
    }

    // Sort by borrow count descending
    final bookList = bookMap.values.toList()
      ..sort((a, b) => b.borrowCount.compareTo(a.borrowCount));

    return bookList;
  }
}

class DateRange {
  final String label;
  final DateTime startDate;
  final DateTime endDate;

  DateRange({
    required this.label,
    required this.startDate,
    required this.endDate,
  });
}
