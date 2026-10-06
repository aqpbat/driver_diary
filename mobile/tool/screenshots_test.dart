// Renders the screenshots for the README into docs/screenshots/.
//
// Not part of the test suite (it lives outside test/): the pictures depend on
// the machine's text rendering, so they are regenerated on purpose, not
// compared on every run:
//
//   flutter test --update-goldens tool/screenshots_test.dart
//
// The screens are the real widgets with the real font; only the data source
// is replaced, by the answers the API gives for the seed data.
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:driver_app_demo/core/design/design.dart';
import 'package:driver_app_demo/core/domain/local_date.dart';
import 'package:driver_app_demo/core/domain/trip.dart';
import 'package:driver_app_demo/core/domain/zoned_time.dart';
import 'package:driver_app_demo/core/error/failure.dart';
import 'package:driver_app_demo/core/error/result.dart';
import 'package:driver_app_demo/features/add_trip/domain/usecases/add_trip.dart';
import 'package:driver_app_demo/features/add_trip/presentation/cubit/add_trip_cubit.dart';
import 'package:driver_app_demo/features/add_trip/presentation/widgets/add_trip_sheet.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_overview.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_ref.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_summary.dart';
import 'package:driver_app_demo/features/day/presentation/bloc/day_bloc.dart';
import 'package:driver_app_demo/features/day/presentation/pages/day_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test/helpers/pump_app.dart';

class _MockDayBloc extends MockBloc<DayEvent, DayState> implements DayBloc {}

class _MockAddTrip extends Mock implements AddTrip {}

const _out = '../../docs/screenshots';

/// A 390×844 phone at 2x.
const _phone = Size(390, 844);
const _pixelRatio = 2.0;

final _oct3 = LocalDate(2026, 10, 3);
final _oct5 = LocalDate(2026, 10, 5);

final _days = [
  DayRef(date: LocalDate(2026, 10, 1), tripsCount: 6),
  DayRef(date: LocalDate(2026, 10, 2), tripsCount: 6),
  DayRef(date: LocalDate(2026, 10, 4), tripsCount: 4),
  DayRef(date: _oct5, tripsCount: 6),
];

Trip _trip(
  String id,
  String start,
  String end,
  int amount,
  Payment payment,
  int commission,
) => Trip(
  id: id,
  start: ZonedTime.parse('$start:00+05:00'),
  end: ZonedTime.parse('$end:00+05:00'),
  amount: amount,
  payment: payment,
  commission: commission,
);

/// `GET /api/v1/days/2026-10-05` on the seed data.
final _oct5Overview = DayOverview(
  date: _oct5,
  summary: const DaySummary(
    total: Totals(tripsCount: 6, revenue: 13750, commission: 1912, net: 11838),
    cash: Totals(tripsCount: 2, revenue: 3750, commission: 412, net: 3338),
    card: Totals(tripsCount: 4, revenue: 10000, commission: 1500, net: 8500),
  ),
  trips: [
    _trip('1', '2026-10-05T06:50', '2026-10-05T07:20', 2000, Payment.card, 300),
    _trip('2', '2026-10-05T08:30', '2026-10-05T09:05', 2500, Payment.card, 375),
    _trip('3', '2026-10-05T12:00', '2026-10-05T12:20', 1000, Payment.cash, 0),
    _trip('4', '2026-10-05T15:45', '2026-10-05T16:30', 3300, Payment.card, 495),
    _trip('5', '2026-10-05T21:10', '2026-10-05T21:55', 2750, Payment.cash, 412),
    _trip('6', '2026-10-05T23:40', '2026-10-06T00:15', 2200, Payment.card, 330),
  ],
);

void main() {
  setUpAll(() async {
    registerFallbackValue(_oct5Overview.trips.first);
    // Tests draw text with a placeholder font unless the real one is loaded.
    final font = File('assets/fonts/Onest.ttf').readAsBytes();
    await (FontLoader(
      'Onest',
    )..addFont(font.then((bytes) => ByteData.view(bytes.buffer)))).load();
  });

  Future<void> shoot(WidgetTester tester, String name) => expectLater(
    find.byType(WidgetsApp),
    matchesGoldenFile('$_out/$name.png'),
  );

  /// Pumps the day screen in [state]. The "add trip" button opens the real
  /// form, whose requests are answered by [addTrip].
  Future<void> pumpDay(
    WidgetTester tester,
    DayState state,
    Brightness brightness, {
    AddTrip? addTrip,
  }) async {
    tester.view.physicalSize = _phone * _pixelRatio;
    tester.view.devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.reset);

    final bloc = _MockDayBloc();
    whenListen(bloc, const Stream<DayState>.empty(), initialState: state);
    await pumpApp(
      tester,
      BlocProvider<DayBloc>.value(
        value: bloc,
        child: DayPage(
          onAddTrip: (context, date) => showAppSheet<LocalDate>(
            context,
            builder: (context) => BlocProvider(
              create: (_) => AddTripCubit(
                addTrip: addTrip ?? _MockAddTrip(),
                newId: () => 'screenshot',
                date: date,
                offset: const Duration(hours: 5),
              ),
              child: const AddTripSheet(),
            ),
          ),
        ),
      ),
      brightness: brightness,
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Finder field(String name) => find.descendant(
    of: find.byKey(ValueKey('add-trip-$name')),
    matching: find.byType(EditableText),
  );

  final loaded = DayLoaded(date: _oct5, days: _days, overview: _oct5Overview);

  for (final brightness in Brightness.values) {
    final theme = brightness.name;

    testWidgets('day, $theme', (tester) async {
      await pumpDay(tester, loaded, brightness);
      await shoot(tester, 'day-$theme');
    });

    testWidgets('empty day, $theme', (tester) async {
      await pumpDay(
        tester,
        DayLoaded(
          date: _oct3,
          days: _days,
          overview: DayOverview(
            date: _oct3,
            summary: DaySummary.empty,
            trips: const [],
          ),
        ),
        brightness,
      );
      await shoot(tester, 'empty-$theme');
    });

    testWidgets('loading, $theme', (tester) async {
      await pumpDay(tester, DayLoading(date: _oct5, days: _days), brightness);
      await shoot(tester, 'loading-$theme');
    });

    testWidgets('network error, $theme', (tester) async {
      await pumpDay(
        tester,
        DayFailed(date: _oct5, days: _days, failure: const NetworkFailure()),
        brightness,
      );
      await shoot(tester, 'error-$theme');
    });

    testWidgets('form, $theme', (tester) async {
      final addTrip = _MockAddTrip();
      when(() => addTrip(any()))
          .thenAnswer((_) async => const Err(NetworkFailure()));
      await pumpDay(tester, loaded, brightness, addTrip: addTrip);
      await tester.tap(find.text('Добавить поездку'));
      await tester.pumpAndSettle();

      // Filled in correctly.
      await tester.enterText(field('start'), '1810');
      await tester.enterText(field('end'), '1845');
      await tester.enterText(field('amount'), '2600');
      await tester.tap(find.text('Карта').last);
      await tester.pumpAndSettle();
      await shoot(tester, 'form-$theme');

      // Sent while the server is unreachable.
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      await shoot(tester, 'form-retry-$theme');
    });

    testWidgets('form with mistakes, $theme', (tester) async {
      await pumpDay(tester, loaded, brightness);
      await tester.tap(find.text('Добавить поездку'));
      await tester.pumpAndSettle();

      await tester.enterText(field('start'), '1810');
      await tester.enterText(field('end'), '1745');
      await tester.enterText(field('amount'), '0');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      await shoot(tester, 'form-invalid-$theme');
    });
  }
}
