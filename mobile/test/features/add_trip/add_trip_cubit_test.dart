import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:driver_app_demo/core/domain/trip.dart';
import 'package:driver_app_demo/core/error/failure.dart';
import 'package:driver_app_demo/core/error/result.dart';
import 'package:driver_app_demo/features/add_trip/domain/entities/trip_form.dart';
import 'package:driver_app_demo/features/add_trip/domain/trip_form_validator.dart';
import 'package:driver_app_demo/features/add_trip/domain/usecases/add_trip.dart';
import 'package:driver_app_demo/features/add_trip/presentation/cubit/add_trip_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fixtures.dart';

class _MockAddTrip extends Mock implements AddTrip {}

void main() {
  late _MockAddTrip addTrip;
  late int idsGenerated;

  setUpAll(() => registerFallbackValue(cardTrip));

  setUp(() {
    addTrip = _MockAddTrip();
    idsGenerated = 0;
  });

  AddTripCubit build() => AddTripCubit(
    addTrip: addTrip,
    newId: () => 'id-${++idsGenerated}',
    date: oct1,
    offset: almaty,
  );

  void fill(AddTripCubit cubit) => cubit
    ..startChanged('08:10')
    ..endChanged('08:42')
    ..amountChanged('2400')
    ..paymentChanged(Payment.card);

  List<Trip> sentTrips() =>
      verify(() => addTrip(captureAny())).captured.cast<Trip>();

  test('the id is generated once, when the form opens', () {
    final cubit = build();

    expect(cubit.state.form.id, 'id-1');
    expect(idsGenerated, 1);
  });

  test('a retry after a network failure sends the same id', () async {
    final answers = <Result<Trip>>[const Err(NetworkFailure()), Ok(cardTrip)];
    when(() => addTrip(any())).thenAnswer((_) async => answers.removeAt(0));
    final cubit = build();
    fill(cubit);

    await cubit.submit();
    expect(
      cubit.state,
      isA<AddTripEditing>().having(
        (s) => s.failure,
        'failure',
        const NetworkFailure(),
      ),
    );

    await cubit.submit();
    expect(cubit.state, isA<AddTripSuccess>());

    final sent = sentTrips();
    expect(sent, hasLength(2));
    expect(sent[0].id, 'id-1');
    expect(sent[1].id, 'id-1');
    expect(sent[1], sent[0], reason: 'the retry is the very same trip');
    expect(idsGenerated, 1, reason: 'no new id for the retry');
  });

  test('editing the form between attempts keeps the id', () async {
    when(() => addTrip(any()))
        .thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = build();
    fill(cubit);

    await cubit.submit();
    cubit.amountChanged('2500');
    await cubit.submit();

    final sent = sentTrips();
    expect(sent.map((t) => t.id), ['id-1', 'id-1']);
    expect(sent.map((t) => t.amount), [2400, 2500]);
  });

  test('a second tap while the request is in flight sends nothing', () async {
    final answer = Completer<Result<Trip>>();
    when(() => addTrip(any())).thenAnswer((_) => answer.future);
    final cubit = build();
    fill(cubit);

    final first = cubit.submit();
    expect(cubit.state, isA<AddTripSubmitting>());
    await cubit.submit();
    await cubit.submit();
    answer.complete(Ok(cardTrip));
    await first;

    verify(() => addTrip(any())).called(1);
    expect(cubit.state, isA<AddTripSuccess>());
  });

  test('the form is locked while the request is in flight', () async {
    final answer = Completer<Result<Trip>>();
    when(() => addTrip(any())).thenAnswer((_) => answer.future);
    final cubit = build();
    fill(cubit);

    final pending = cubit.submit();
    cubit.amountChanged('9999');
    answer.complete(Ok(cardTrip));
    await pending;

    expect(cubit.state.form.amountText, '2400');
  });

  blocTest<AddTripCubit, AddTripState>(
    'an invalid form shows its errors and is not sent',
    build: build,
    act: (cubit) => cubit
      ..startChanged('09:00')
      ..endChanged('08:30')
      ..amountChanged('0')
      ..submit(),
    skip: 3,
    expect: () => [
      isA<AddTripEditing>().having((s) => s.errors, 'errors', {
        TripField.end: TripFieldError.endNotAfterStart,
        TripField.amount: TripFieldError.notPositive,
      }),
    ],
    verify: (_) => verifyNever(() => addTrip(any())),
  );

  test('editing a field clears its error and leaves the others', () async {
    final cubit = build()
      ..startChanged('09:00')
      ..endChanged('08:30');
    await cubit.submit();
    expect(
      cubit.state.errors.keys,
      containsAll([TripField.end, TripField.amount]),
    );

    cubit.endChanged('09:30');

    expect(cubit.state.errors.containsKey(TripField.end), isFalse);
    expect(cubit.state.errors.containsKey(TripField.amount), isTrue);
  });

  test('success carries the trip as the server stored it', () async {
    when(() => addTrip(any())).thenAnswer((_) async => Ok(cardTrip));
    final cubit = build();
    fill(cubit);

    await cubit.submit();

    expect(
      cubit.state,
      isA<AddTripSuccess>().having((s) => s.trip, 'trip', cardTrip),
    );
  });

  test('field errors of a 422 land on the form fields', () async {
    when(() => addTrip(any())).thenAnswer(
      (_) async => const Err(
        ValidationFailure({'end': 'must be after start', 'id': 'is required'}),
      ),
    );
    final cubit = build();
    fill(cubit);

    await cubit.submit();

    expect(cubit.state.errors, {
      TripField.end: TripFieldError.rejectedByServer,
    });
    expect((cubit.state as AddTripEditing).failure, isA<ValidationFailure>());
  });

  test('a conflict is reported and the form stays open', () async {
    when(() => addTrip(any()))
        .thenAnswer((_) async => const Err(ConflictFailure()));
    final cubit = build();
    fill(cubit);

    await cubit.submit();

    expect((cubit.state as AddTripEditing).failure, const ConflictFailure());
  });

  group('commission suggestion', () {
    test('follows the amount until the driver types a commission', () {
      final cubit = build()..amountChanged('2400');
      expect(cubit.state.form.commissionText, '360');

      cubit.amountChanged('1500');
      expect(cubit.state.form.commissionText, '225');

      cubit.commissionChanged('100');
      cubit.amountChanged('3000');
      expect(cubit.state.form.commissionText, '100');
      expect(cubit.state.commissionEdited, isTrue);
    });

    test('is zero for a zero amount: one mistake, not two', () {
      final cubit = build()..amountChanged('0');

      expect(cubit.state.form.commissionText, '0');
    });

    test('is empty while there is no amount', () {
      final cubit = build()..amountChanged('2400');

      cubit.amountChanged('');

      expect(cubit.state.form.commissionText, '');
    });
  });
}
