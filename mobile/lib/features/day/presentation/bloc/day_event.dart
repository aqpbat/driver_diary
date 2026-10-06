part of 'day_bloc.dart';

sealed class DayEvent extends Equatable {
  const DayEvent();

  @override
  List<Object?> get props => const [];
}

/// The screen opened: load the list of days and show the latest one that has
/// trips.
final class DayStarted extends DayEvent {
  const DayStarted();
}

/// The driver picked another day.
final class DaySelected extends DayEvent {
  const DaySelected(this.date);

  final LocalDate date;

  @override
  List<Object?> get props => [date];
}

/// Reload what is on screen: pull-to-refresh, or "Retry" after an error.
final class DayRefreshed extends DayEvent {
  const DayRefreshed();
}

/// A trip was saved for [date]: show that day with fresh data.
final class DayTripAdded extends DayEvent {
  const DayTripAdded(this.date);

  final LocalDate date;

  @override
  List<Object?> get props => [date];
}
