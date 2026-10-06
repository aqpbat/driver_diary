import 'package:driver_app_demo/core/design/design.dart';
import 'package:driver_app_demo/core/domain/local_date.dart';
import 'package:driver_app_demo/core/domain/trip.dart';
import 'package:driver_app_demo/core/error/failure.dart';
import 'package:driver_app_demo/core/error/result.dart';
import 'package:driver_app_demo/features/add_trip/domain/usecases/add_trip.dart';
import 'package:driver_app_demo/features/add_trip/presentation/cubit/add_trip_cubit.dart';
import 'package:driver_app_demo/features/add_trip/presentation/widgets/add_trip_sheet.dart';
import 'package:driver_app_demo/features/add_trip/presentation/widgets/time_input_formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/pump_app.dart';

class _MockAddTrip extends Mock implements AddTrip {}

void main() {
  late _MockAddTrip addTrip;
  Object? sheetResult;

  setUpAll(() => registerFallbackValue(cardTrip));

  setUp(() {
    addTrip = _MockAddTrip();
    sheetResult = 'not closed';
  });

  /// Opens the sheet the way the app does and remembers what it popped with.
  Future<void> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      Builder(
        builder: (context) => AppButton(
          label: 'open',
          onPressed: () async {
            sheetResult = await showAppSheet<LocalDate>(
              context,
              builder: (context) => BlocProvider(
                create: (_) => AddTripCubit(
                  addTrip: addTrip,
                  newId: () => 'id-1',
                  date: oct1,
                  offset: almaty,
                ),
                child: const AddTripSheet(),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String name) => find.descendant(
    of: find.byKey(ValueKey('add-trip-$name')),
    matching: find.byType(EditableText),
  );

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(field('start'), '0810');
    await tester.enterText(field('end'), '0842');
    await tester.enterText(field('amount'), '2400');
    await tester.pump();
  }

  testWidgets('sends the trip and closes with its day', (tester) async {
    when(() => addTrip(any())).thenAnswer((_) async => Ok(cardTrip));
    await openSheet(tester);
    expect(find.text('Новая поездка'), findsOneWidget);
    expect(find.text('чт, 1 октября'), findsOneWidget);

    await fill(tester);
    expect(find.text('В пути 32 мин'), findsOneWidget);
    // 15 % of the amount was filled in.
    expect(
      tester.widget<EditableText>(field('commission')).controller.text,
      '360',
    );

    await tester.tap(find.text('Карта'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final sent = verify(() => addTrip(captureAny())).captured.single as Trip;
    expect(sent.id, 'id-1');
    expect(sent.start.toIso(), '2026-10-01T08:10:00+05:00');
    expect(sent.end.toIso(), '2026-10-01T08:42:00+05:00');
    expect(sent.amount, 2400);
    expect(sent.commission, 360);
    expect(sent.payment, Payment.card);
    expect(find.text('Новая поездка'), findsNothing);
    expect(sheetResult, oct1);
  });

  testWidgets('shows validation errors next to the fields and sends nothing', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(field('start'), '0900');
    await tester.enterText(field('end'), '0830');
    await tester.enterText(field('amount'), '0');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();

    expect(find.textContaining('Не позже начала'), findsOneWidget);
    expect(find.text('Сумма должна быть больше нуля'), findsOneWidget);
    verifyNever(() => addTrip(any()));
    expect(find.text('Новая поездка'), findsOneWidget);
  });

  testWidgets('after a network failure the same trip can be sent again', (
    tester,
  ) async {
    final answers = <Result<Trip>>[const Err(NetworkFailure()), Ok(cardTrip)];
    when(() => addTrip(any())).thenAnswer((_) async => answers.removeAt(0));
    await openSheet(tester);
    await fill(tester);

    await tester.tap(find.text('Сохранить'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Нет связи с сервером'), findsOneWidget);
    expect(find.text('Новая поездка'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();

    final sent = verify(() => addTrip(captureAny())).captured.cast<Trip>();
    expect(sent.map((t) => t.id), ['id-1', 'id-1']);
    expect(sheetResult, oct1);
  });

  testWidgets('the day can be changed and the trip can end next day', (
    tester,
  ) async {
    when(() => addTrip(any())).thenAnswer((_) async => Ok(cardTrip));
    await openSheet(tester);

    await tester.tap(find.bySemanticsLabel('День позже'));
    await tester.pump();
    expect(find.text('пт, 2 октября'), findsOneWidget);

    await tester.enterText(field('start'), '2350');
    await tester.enterText(field('end'), '0020');
    await tester.enterText(field('amount'), '1800');
    await tester.tap(find.text('Закончилась на следующий день'));
    await tester.pump();
    expect(find.text('В пути 30 мин'), findsOneWidget);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    final sent = verify(() => addTrip(captureAny())).captured.single as Trip;
    expect(sent.start.toIso(), '2026-10-02T23:50:00+05:00');
    expect(sent.end.toIso(), '2026-10-03T00:20:00+05:00');
  });

  testWidgets('closing the sheet returns nothing', (tester) async {
    await openSheet(tester);

    await tester.tap(find.bySemanticsLabel('Закрыть').last);
    await tester.pumpAndSettle();

    expect(sheetResult, isNull);
    verifyNever(() => addTrip(any()));
  });

  group('TimeInputFormatter', () {
    String type(String text) => const TimeInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
        .text;

    test('inserts the colon', () {
      expect(type('0'), '0');
      expect(type('08'), '08');
      expect(type('081'), '08:1');
      expect(type('0810'), '08:10');
      expect(type('2355'), '23:55');
    });

    test('pads an hour that cannot be two digits', () {
      expect(type('8'), '08');
      expect(type('810'), '08:10');
    });

    test('drops everything that is not a digit and anything extra', () {
      expect(type('08:10'), '08:10');
      expect(type('8ч10'), '08:10');
      expect(type('081099'), '08:10');
    });
  });
}
