part of 'day_bloc.dart';

sealed class DayState extends Equatable {
  const DayState({this.date, this.days = const []});

  /// The day on screen. Null only until the first list of days arrives.
  final LocalDate? date;

  /// Days that have trips, oldest first — the marks on the date strip.
  final List<DayRef> days;

  @override
  List<Object?> get props => [date, days];
}

final class DayLoading extends DayState {
  const DayLoading({super.date, super.days});
}

final class DayLoaded extends DayState {
  const DayLoaded({
    required LocalDate super.date,
    required super.days,
    required this.overview,
    this.isRefreshing = false,
    this.refreshFailure,
  });

  final DayOverview overview;

  /// A reload is running while the old data stays on screen.
  final bool isRefreshing;

  /// The last reload failed; the data on screen may be stale.
  final Failure? refreshFailure;

  @override
  LocalDate get date => super.date!;

  @override
  List<Object?> get props => [
    ...super.props,
    overview,
    isRefreshing,
    refreshFailure,
  ];
}

final class DayFailed extends DayState {
  const DayFailed({super.date, super.days, required this.failure});

  final Failure failure;

  @override
  List<Object?> get props => [...super.props, failure];
}
