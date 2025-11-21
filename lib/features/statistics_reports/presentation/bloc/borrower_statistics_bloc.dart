import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/borrower_statistics_data.dart';
import '../../data/services/borrower_statistics_service.dart';

// Events
abstract class BorrowerStatisticsEvent extends Equatable {
  const BorrowerStatisticsEvent();

  @override
  List<Object?> get props => [];
}

class LoadBorrowerStatisticsEvent extends BorrowerStatisticsEvent {
  final String borrowerName;
  final TimePeriod period;

  const LoadBorrowerStatisticsEvent({
    required this.borrowerName,
    required this.period,
  });

  @override
  List<Object?> get props => [borrowerName, period];
}

// States
abstract class BorrowerStatisticsState extends Equatable {
  const BorrowerStatisticsState();

  @override
  List<Object?> get props => [];
}

class BorrowerStatisticsInitial extends BorrowerStatisticsState {
  const BorrowerStatisticsInitial();
}

class BorrowerStatisticsLoading extends BorrowerStatisticsState {
  const BorrowerStatisticsLoading();
}

class BorrowerStatisticsLoaded extends BorrowerStatisticsState {
  final BorrowerStatisticsData statistics;

  const BorrowerStatisticsLoaded({required this.statistics});

  @override
  List<Object?> get props => [statistics];
}

class BorrowerStatisticsError extends BorrowerStatisticsState {
  final String message;

  const BorrowerStatisticsError({required this.message});

  @override
  List<Object?> get props => [message];
}

// BLoC
class BorrowerStatisticsBloc extends Bloc<BorrowerStatisticsEvent, BorrowerStatisticsState> {
  final BorrowerStatisticsService statisticsService;

  BorrowerStatisticsBloc({
    required this.statisticsService,
  }) : super(const BorrowerStatisticsInitial()) {
    on<LoadBorrowerStatisticsEvent>(_onLoadBorrowerStatistics);
  }

  Future<void> _onLoadBorrowerStatistics(
    LoadBorrowerStatisticsEvent event,
    Emitter<BorrowerStatisticsState> emit,
  ) async {
    emit(const BorrowerStatisticsLoading());

    final result = await statisticsService.getBorrowerStatistics(
      borrowerName: event.borrowerName,
      period: event.period,
    );

    result.fold(
      (failure) => emit(BorrowerStatisticsError(message: failure.message)),
      (statistics) => emit(BorrowerStatisticsLoaded(statistics: statistics)),
    );
  }
}
