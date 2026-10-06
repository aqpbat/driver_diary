import 'package:bloc_test/bloc_test.dart';
import 'package:driver_app_demo/core/domain/local_date.dart';
import 'package:driver_app_demo/core/error/failure.dart';
import 'package:driver_app_demo/core/format/money.dart';
import 'package:driver_app_demo/features/day/presentation/bloc/day_bloc.dart';
import 'package:driver_app_demo/features/day/presentation/pages/day_page.dart';
import 'package:driver_app_demo/features/day/presentation/widgets/day_placeholders.dart';
import 'package:driver_app_demo/features/day/presentation/widgets/trip_tile.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

class _MockDayBloc extends MockBloc<DayEvent, DayState> implements DayBloc {}

void main() {
  late _MockDayBloc bloc;
  late List<LocalDate> addTripCalls;
  LocalDate? addTripResult;

  setUpAll(() => registerFallbackValue(const DayStarted()));

  setUp(() {
    bloc = _MockDayBloc();
    addTripCalls = [];
    addTripResult = null;
  });

  Future<void> pumpPage(
    WidgetTester tester,
    DayState state, {
    Brightness brightness = Brightness.light,
    Size size = const Size(400, 1400),
  }) async {
    // Tall enough for the whole day: the list builds only what is visible.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    whenListen(bloc, const Stream<DayState>.empty(), initialState: state);
    await pumpApp(
      tester,
      BlocProvider<DayBloc>.value(
        value: bloc,
        child: DayPage(
          onAddTrip: (context, date) async {
            addTripCalls.add(date);
            return addTripResult;
          },
        ),
      ),
      brightness: brightness,
    );
    // Not pumpAndSettle: skeletons and spinners animate forever.
    await tester.pump(const Duration(milliseconds: 300));
  }

  final loaded = DayLoaded(date: oct1, days: days, overview: oct1Overview);

  group('with data', () {
    testWidgets('shows the date, the summary and the trips', (tester) async {
      await pumpPage(tester, loaded);

      expect(find.text('чт, 1 октября'), findsOneWidget);
      // Take-home, revenue and commission, as the server computed them.
      expect(find.text('На руки'), findsOneWidget);
      expect(find.text(formatMoney(3315)), findsOneWidget);
      expect(find.text(formatMoney(3900)), findsOneWidget);
      expect(find.text(formatMoney(585)), findsOneWidget);
      // The split by payment kind.
      expect(
        find.text('1 поездка · на руки ${formatMoney(1275)}'),
        findsOneWidget,
      );
      expect(
        find.text('1 поездка · на руки ${formatMoney(2040)}'),
        findsOneWidget,
      );
      // The list.
      expect(find.byType(TripTile), findsNWidgets(2));
      expect(find.text('08:10 – 08:42'), findsOneWidget);
      expect(find.text('Карта · 32 мин'), findsOneWidget);
      expect(find.text('комиссия ${formatMoney(360)}'), findsOneWidget);
      expect(find.text('09:15 – 09:40'), findsOneWidget);
      expect(find.text('Наличные · 25 мин'), findsOneWidget);
      expect(find.text('2 поездки'), findsOneWidget);
    });

    testWidgets('renders in the dark theme too', (tester) async {
      await pumpPage(tester, loaded, brightness: Brightness.dark);

      expect(find.text(formatMoney(3315)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a narrow phone without overflowing', (tester) async {
      await pumpPage(tester, loaded, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });

    testWidgets('the arrows ask for the neighbouring days', (tester) async {
      await pumpPage(tester, loaded);

      await tester.tap(find.bySemanticsLabel('Следующий день'));
      await tester.tap(find.bySemanticsLabel('Предыдущий день'));

      verify(() => bloc.add(DaySelected(oct2))).called(1);
      verify(() => bloc.add(DaySelected(LocalDate(2026, 9, 30)))).called(1);
    });

    testWidgets('a swipe flips to the next day', (tester) async {
      await pumpPage(tester, loaded);

      await tester.fling(
        find.byType(TripTile).first,
        const Offset(-300, 0),
        1000,
      );
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => bloc.add(DaySelected(oct2))).called(1);
    });

    testWidgets('tapping a date on the strip selects it', (tester) async {
      await pumpPage(tester, loaded);

      await tester.tap(find.bySemanticsLabel(RegExp('^пт, 2 октября')));

      verify(() => bloc.add(DaySelected(oct2))).called(1);
    });

    testWidgets('the strip marks the days that have trips', (tester) async {
      await pumpPage(tester, loaded);

      expect(
        find.bySemanticsLabel('чт, 1 октября, есть поездки'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('пт, 2 октября, нет поездок'),
        findsOneWidget,
      );
    });

    testWidgets('a failed refresh keeps the data and says so', (tester) async {
      await pumpPage(
        tester,
        DayLoaded(
          date: oct1,
          days: days,
          overview: oct1Overview,
          refreshFailure: const NetworkFailure(),
        ),
      );

      expect(find.textContaining('Не удалось обновить'), findsOneWidget);
      expect(find.byType(TripTile), findsNWidgets(2));
    });
  });

  testWidgets('an empty day says there are no trips', (tester) async {
    await pumpPage(
      tester,
      DayLoaded(date: oct2, days: days, overview: emptyOverview(oct2)),
    );

    expect(find.text('пт, 2 октября'), findsOneWidget);
    expect(find.text('Поездок нет'), findsOneWidget);
    expect(find.byType(TripTile), findsNothing);
    expect(find.text('На руки'), findsNothing);
    expect(find.text('Добавить поездку'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton', (tester) async {
    await pumpPage(tester, DayLoading(date: oct1, days: days));

    expect(find.byType(DaySkeleton), findsOneWidget);
    expect(find.byType(TripTile), findsNothing);
  });

  group('on error', () {
    testWidgets('explains and offers to retry', (tester) async {
      await pumpPage(
        tester,
        DayFailed(date: oct1, days: days, failure: const NetworkFailure()),
      );

      expect(find.text('Не удалось загрузить день'), findsOneWidget);
      expect(find.textContaining('Нет связи'), findsOneWidget);

      await tester.tap(find.text('Повторить'));

      verify(() => bloc.add(const DayRefreshed())).called(1);
    });

    testWidgets('works before any date is known', (tester) async {
      await pumpPage(tester, const DayFailed(failure: NetworkFailure()));

      expect(find.text('Повторить'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('adding a trip', () {
    testWidgets('opens the form for the day on screen', (tester) async {
      await pumpPage(tester, loaded);

      await tester.tap(find.text('Добавить поездку'));
      await tester.pump();

      expect(addTripCalls, [oct1]);
      verifyNever(() => bloc.add(any(that: isA<DayTripAdded>())));
    });

    testWidgets('a saved trip moves the screen to the trip day', (
      tester,
    ) async {
      addTripResult = oct4;
      await pumpPage(tester, loaded);

      await tester.tap(find.text('Добавить поездку'));
      await tester.pump();

      verify(() => bloc.add(DayTripAdded(oct4))).called(1);
      expect(find.text('Поездка сохранена'), findsOneWidget);

      // The notice goes away on its own.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Поездка сохранена'), findsNothing);
    });
  });
}
