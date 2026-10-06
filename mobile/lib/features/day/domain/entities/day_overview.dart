import 'package:equatable/equatable.dart';

import '../../../../core/domain/local_date.dart';
import '../../../../core/domain/trip.dart';
import 'day_summary.dart';

/// Everything the day screen shows for one date.
final class DayOverview extends Equatable {
  const DayOverview({
    required this.date,
    required this.summary,
    required this.trips,
  });

  final LocalDate date;
  final DaySummary summary;

  /// In the server's order: by start time.
  final List<Trip> trips;

  @override
  List<Object?> get props => [date, summary, trips];
}
