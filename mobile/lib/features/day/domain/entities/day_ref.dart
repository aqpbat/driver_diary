import 'package:equatable/equatable.dart';

import '../../../../core/domain/local_date.dart';

/// A day that has trips, as listed by the server.
final class DayRef extends Equatable {
  const DayRef({required this.date, required this.tripsCount});

  final LocalDate date;
  final int tripsCount;

  @override
  List<Object?> get props => [date, tripsCount];
}
