import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/local_date.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/day_overview.dart';
import '../../domain/entities/day_ref.dart';
import '../../domain/usecases/get_day.dart';
import '../../domain/usecases/get_days.dart';

part 'day_event.dart';
part 'day_state.dart';

class DayBloc extends Bloc<DayEvent, DayState> {
  /// [today] is the current date on the driver's clock; it is the day shown
  /// when the server has no trips at all.
  DayBloc({required this._getDays, required this._getDay, required this._today})
    : super(const DayLoading()) {
    // One handler for every event, so that any new event cancels the one in
    // flight: when the driver flips through days quickly, the answer for a
    // day they already left is dropped instead of flashing on screen.
    on<DayEvent>(_onEvent, transformer: restartable());
  }

  final GetDays _getDays;
  final GetDay _getDay;
  final LocalDate Function() _today;

  Future<void> _onEvent(DayEvent event, Emitter<DayState> emit) {
    final date = state.date;
    return switch (event) {
      DayStarted() => _loadEverything(emit, date: null),
      DaySelected(:final date) => _loadDay(emit, date),
      DayTripAdded(:final date) => _loadEverything(emit, date: date),
      DayRefreshed() when state is DayLoaded => _refresh(emit),
      // "Retry" after a failure: the list of days first if we never got it.
      DayRefreshed() when date != null && state.days.isNotEmpty => _loadDay(
        emit,
        date,
      ),
      DayRefreshed() => _loadEverything(emit, date: date),
    };
  }

  /// Loads the list of days and then [date], or the latest day with trips
  /// when [date] is null.
  Future<void> _loadEverything(
    Emitter<DayState> emit, {
    required LocalDate? date,
  }) async {
    emit(DayLoading(date: date, days: state.days));

    final daysResult = await _getDays();
    if (emit.isDone) return;
    switch (daysResult) {
      case Err(:final failure):
        emit(DayFailed(date: date, days: state.days, failure: failure));
      case Ok(value: final days):
        final target = date ?? (days.isEmpty ? _today() : days.last.date);
        emit(DayLoading(date: target, days: days));
        await _fetchDay(emit, target, days);
    }
  }

  Future<void> _loadDay(Emitter<DayState> emit, LocalDate date) async {
    final days = state.days;
    emit(DayLoading(date: date, days: days));
    await _fetchDay(emit, date, days);
  }

  Future<void> _fetchDay(
    Emitter<DayState> emit,
    LocalDate date,
    List<DayRef> days,
  ) async {
    final result = await _getDay(date);
    if (emit.isDone) return;
    emit(switch (result) {
      Ok(:final value) => DayLoaded(date: date, days: days, overview: value),
      Err(:final failure) => DayFailed(
        date: date,
        days: days,
        failure: failure,
      ),
    });
  }

  /// Reloads the day on screen and the list of days, keeping the current
  /// data visible; if the reload fails, the data stays and the failure is
  /// reported next to it.
  Future<void> _refresh(Emitter<DayState> emit) async {
    final current = state as DayLoaded;
    emit(
      DayLoaded(
        date: current.date,
        days: current.days,
        overview: current.overview,
        isRefreshing: true,
      ),
    );

    final (daysResult, dayResult) = await (
      _getDays(),
      _getDay(current.date),
    ).wait;
    if (emit.isDone) return;

    final failure = switch ((daysResult, dayResult)) {
      (Err(:final failure), _) || (_, Err(:final failure)) => failure,
      _ => null,
    };
    emit(
      DayLoaded(
        date: current.date,
        days: daysResult is Ok<List<DayRef>> ? daysResult.value : current.days,
        overview: dayResult is Ok<DayOverview>
            ? dayResult.value
            : current.overview,
        refreshFailure: failure,
      ),
    );
  }
}
