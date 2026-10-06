import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:driver_app_demo/core/domain/local_date.dart';
import 'package:driver_app_demo/core/error/failure.dart';
import 'package:driver_app_demo/core/error/result.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_overview.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_ref.dart';
import 'package:driver_app_demo/features/day/domain/usecases/get_day.dart';
import 'package:driver_app_demo/features/day/domain/usecases/get_days.dart';
import 'package:driver_app_demo/features/day/presentation/bloc/day_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';

class _MockGetDays extends Mock implements GetDays {}

class _MockGetDay extends Mock implements GetDay {}

void main() {
  late _MockGetDays getDays;
  late _MockGetDay getDay;
  final today = LocalDate(2026, 10, 6);

  setUpAll(() => registerFallbackValue(oct1));

  setUp(() {
    getDays = _MockGetDays();
    getDay = _MockGetDay();
    when(() => getDays()).thenAnswer((_) async => Ok(days));
    when(
      () => getDay(any()),
    ).thenAnswer((i) async => Ok(emptyOverview(i.positionalArguments.first)));
    when(() => getDay(oct1)).thenAnswer((_) async => Ok(oct1Overview));
  });

  DayBloc build() =>
      DayBloc(getDays: getDays, getDay: getDay, today: () => today);

  DayLoaded loaded(LocalDate date, {DayOverview? overview}) => DayLoaded(
    date: date,
    days: days,
    overview: overview ?? emptyOverview(date),
  );

  group('start', () {
    blocTest<DayBloc, DayState>(
      'loads the days and opens the latest day that has trips',
      build: build,
      act: (bloc) => bloc.add(const DayStarted()),
      expect: () => [
        const DayLoading(),
        DayLoading(date: oct5, days: days),
        loaded(oct5),
      ],
      verify: (_) => verify(() => getDay(oct5)).called(1),
    );

    blocTest<DayBloc, DayState>(
      'opens today when the server has no trips at all',
      setUp: () =>
          when(() => getDays()).thenAnswer((_) async => const Ok(<DayRef>[])),
      build: build,
      act: (bloc) => bloc.add(const DayStarted()),
      expect: () => [
        const DayLoading(),
        DayLoading(date: today),
        DayLoaded(date: today, days: const [], overview: emptyOverview(today)),
      ],
    );

    blocTest<DayBloc, DayState>(
      'reports a failure to load the list of days',
      setUp: () =>
          when(() => getDays())
              .thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (bloc) => bloc.add(const DayStarted()),
      expect: () => [
        const DayLoading(),
        const DayFailed(failure: NetworkFailure()),
      ],
      verify: (_) => verifyNever(() => getDay(any())),
    );

    blocTest<DayBloc, DayState>(
      'reports a failure to load the day, keeping the date and the days',
      setUp: () =>
          when(() => getDay(oct5))
              .thenAnswer((_) async => const Err(UnknownFailure('HTTP 500'))),
      build: build,
      act: (bloc) => bloc.add(const DayStarted()),
      expect: () => [
        const DayLoading(),
        DayLoading(date: oct5, days: days),
        DayFailed(
          date: oct5,
          days: days,
          failure: const UnknownFailure('HTTP 500'),
        ),
      ],
    );
  });

  group('selecting a day', () {
    blocTest<DayBloc, DayState>(
      'loads that day and keeps the list of days',
      build: build,
      seed: () => loaded(oct5),
      act: (bloc) => bloc.add(DaySelected(oct1)),
      expect: () => [
        DayLoading(date: oct1, days: days),
        loaded(oct1, overview: oct1Overview),
      ],
      verify: (_) => verifyNever(() => getDays()),
    );

    blocTest<DayBloc, DayState>(
      'a day without trips is data, not an error',
      build: build,
      seed: () => loaded(oct5),
      act: (bloc) => bloc.add(DaySelected(oct2)),
      expect: () => [DayLoading(date: oct2, days: days), loaded(oct2)],
    );

    test('flipping days quickly shows only the last one', () async {
      // Answers arrive in the wrong order: the first request is the slowest.
      final answers = {
        oct1: Completer<Result<DayOverview>>(),
        oct2: Completer<Result<DayOverview>>(),
        oct4: Completer<Result<DayOverview>>(),
      };
      when(() => getDay(any())).thenAnswer(
        (i) => answers[i.positionalArguments.first as LocalDate]!.future,
      );
      final bloc = build();
      final states = <DayState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(DaySelected(oct1));
      await pumpEventQueue();
      bloc.add(DaySelected(oct2));
      await pumpEventQueue();
      bloc.add(DaySelected(oct4));
      await pumpEventQueue();

      answers[oct4]!.complete(Ok(emptyOverview(oct4)));
      await pumpEventQueue();
      answers[oct2]!.complete(Ok(emptyOverview(oct2)));
      answers[oct1]!.complete(Ok(oct1Overview));
      await pumpEventQueue();

      expect(states, [
        DayLoading(date: oct1),
        DayLoading(date: oct2),
        DayLoading(date: oct4),
        DayLoaded(date: oct4, days: const [], overview: emptyOverview(oct4)),
      ]);
      expect(bloc.state.date, oct4);

      await subscription.cancel();
      await bloc.close();
    });
  });

  group('refresh', () {
    blocTest<DayBloc, DayState>(
      'reloads the day and the days while the old data stays on screen',
      build: build,
      seed: () => loaded(oct1),
      act: (bloc) => bloc.add(const DayRefreshed()),
      expect: () => [
        DayLoaded(
          date: oct1,
          days: days,
          overview: emptyOverview(oct1),
          isRefreshing: true,
        ),
        loaded(oct1, overview: oct1Overview),
      ],
      verify: (_) => verify(() => getDays()).called(1),
    );

    blocTest<DayBloc, DayState>(
      'a failed refresh keeps the data and reports the failure',
      setUp: () =>
          when(() => getDay(oct1))
              .thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      seed: () => loaded(oct1, overview: oct1Overview),
      act: (bloc) => bloc.add(const DayRefreshed()),
      skip: 1,
      expect: () => [
        DayLoaded(
          date: oct1,
          days: days,
          overview: oct1Overview,
          refreshFailure: const NetworkFailure(),
        ),
      ],
    );

    blocTest<DayBloc, DayState>(
      'retry after a failed day loads that same day again',
      build: build,
      seed: () =>
          DayFailed(date: oct1, days: days, failure: const NetworkFailure()),
      act: (bloc) => bloc.add(const DayRefreshed()),
      expect: () => [
        DayLoading(date: oct1, days: days),
        loaded(oct1, overview: oct1Overview),
      ],
    );

    blocTest<DayBloc, DayState>(
      'retry after a failed start starts over',
      build: build,
      seed: () => const DayFailed(failure: NetworkFailure()),
      act: (bloc) => bloc.add(const DayRefreshed()),
      expect: () => [
        const DayLoading(),
        DayLoading(date: oct5, days: days),
        loaded(oct5),
      ],
    );
  });

  blocTest<DayBloc, DayState>(
    'after a trip is added, reloads the days and shows the trip day',
    build: build,
    seed: () => loaded(oct5),
    act: (bloc) => bloc.add(DayTripAdded(oct1)),
    expect: () => [
      DayLoading(date: oct1, days: days),
      loaded(oct1, overview: oct1Overview),
    ],
    verify: (_) {
      verify(() => getDays()).called(1);
      verify(() => getDay(oct1)).called(1);
    },
  );
}
