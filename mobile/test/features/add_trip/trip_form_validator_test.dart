import 'package:driver_app_demo/core/domain/trip.dart';
import 'package:driver_app_demo/features/add_trip/domain/entities/trip_form.dart';
import 'package:driver_app_demo/features/add_trip/domain/trip_form_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixtures.dart';

TripForm _form({
  String start = '08:10',
  String end = '08:42',
  bool endsNextDay = false,
  String amount = '2400',
  String commission = '360',
  Payment payment = Payment.card,
}) => TripForm(
  id: 'id-1',
  date: oct1,
  startText: start,
  endText: end,
  endsNextDay: endsNextDay,
  amountText: amount,
  payment: payment,
  commissionText: commission,
);

Map<TripField, TripFieldError> _errors(TripForm form) =>
    switch (validateTripForm(form, offset: almaty)) {
      TripFormInvalid(:final errors) => errors,
      TripFormValid(:final trip) => fail('expected errors, got $trip'),
    };

Trip _trip(TripForm form) => switch (validateTripForm(form, offset: almaty)) {
  TripFormValid(:final trip) => trip,
  TripFormInvalid(:final errors) => fail('expected a trip, got $errors'),
};

void main() {
  test('a correct form becomes a trip in the driver zone', () {
    final trip = _trip(_form());

    expect(trip.id, 'id-1');
    expect(trip.start.toIso(), '2026-10-01T08:10:00+05:00');
    expect(trip.end.toIso(), '2026-10-01T08:42:00+05:00');
    expect(trip.amount, 2400);
    expect(trip.commission, 360);
    expect(trip.payment, Payment.card);
  });

  group('amount', () {
    test('zero is rejected', () {
      expect(_errors(_form(amount: '0', commission: '0')), {
        TripField.amount: TripFieldError.notPositive,
      });
    });

    test('negative is rejected', () {
      expect(_errors(_form(amount: '-100', commission: '0')), {
        TripField.amount: TripFieldError.notPositive,
      });
    });

    test('empty is "required", text is "not a number"', () {
      expect(
        _errors(_form(amount: ''))[TripField.amount],
        TripFieldError.required,
      );
      expect(
        _errors(_form(amount: 'много'))[TripField.amount],
        TripFieldError.invalidNumber,
      );
      expect(
        _errors(_form(amount: '2400.50'))[TripField.amount],
        TripFieldError.invalidNumber,
        reason: 'money is whole tenge',
      );
    });

    test('digit groups may be separated by spaces', () {
      expect(_trip(_form(amount: '12 400', commission: '0')).amount, 12400);
    });
  });

  group('times', () {
    test('end earlier than start is rejected', () {
      expect(_errors(_form(start: '09:00', end: '08:30')), {
        TripField.end: TripFieldError.endNotAfterStart,
      });
    });

    test('end equal to start is rejected', () {
      expect(_errors(_form(start: '09:00', end: '09:00')), {
        TripField.end: TripFieldError.endNotAfterStart,
      });
    });

    test('a trip past midnight is fine once marked as ending next day', () {
      final trip = _trip(
        _form(start: '23:50', end: '00:20', endsNextDay: true),
      );

      expect(trip.start.toIso(), '2026-10-01T23:50:00+05:00');
      expect(trip.end.toIso(), '2026-10-02T00:20:00+05:00');
      expect(trip.duration, const Duration(minutes: 30));
      expect(trip.day, oct1, reason: 'the day is the day of the start');
    });

    test('empty and malformed times', () {
      expect(_errors(_form(start: '', end: '')), {
        TripField.start: TripFieldError.required,
        TripField.end: TripFieldError.required,
      });
      expect(
        _errors(_form(start: '25:00'))[TripField.start],
        TripFieldError.invalidTime,
      );
      expect(
        _errors(_form(end: '08:6'))[TripField.end],
        TripFieldError.invalidTime,
      );
    });
  });

  group('commission', () {
    test('larger than the amount is rejected', () {
      expect(_errors(_form(amount: '1000', commission: '1001')), {
        TripField.commission: TripFieldError.exceedsAmount,
      });
    });

    test('equal to the amount and zero are both allowed', () {
      expect(_trip(_form(amount: '1000', commission: '1000')).net, 0);
      expect(_trip(_form(amount: '1000', commission: '0')).net, 1000);
    });

    test('negative is rejected', () {
      expect(
        _errors(_form(commission: '-1'))[TripField.commission],
        TripFieldError.negative,
      );
    });

    test('is not compared with an invalid amount', () {
      expect(_errors(_form(amount: '0', commission: '50')), {
        TripField.amount: TripFieldError.notPositive,
      });
    });
  });

  test('every wrong field is reported at once', () {
    expect(
      _errors(_form(start: '', end: '99:99', amount: '0', commission: '')),
      {
        TripField.start: TripFieldError.required,
        TripField.end: TripFieldError.invalidTime,
        TripField.amount: TripFieldError.notPositive,
        TripField.commission: TripFieldError.required,
      },
    );
  });

  test('suggested commission is 15 %, rounded half up', () {
    expect(suggestedCommission(2400), 360);
    expect(suggestedCommission(1500), 225);
    expect(suggestedCommission(990), 149); // 148.5
    expect(suggestedCommission(1), 0); // 0.15
    expect(suggestedCommission(0), 0);
    expect(suggestedCommission(-500), 0);
  });
}
