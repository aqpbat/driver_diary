import '../../../core/domain/trip.dart';
import '../../../core/domain/zoned_time.dart';
import 'entities/trip_form.dart';

/// What is wrong with a field. The wording lives in the presentation layer.
enum TripFieldError {
  /// Nothing was entered.
  required,

  /// Not a time of day like `08:10`.
  invalidTime,

  /// Not a whole number.
  invalidNumber,

  /// The end is not later than the start.
  endNotAfterStart,

  /// The amount is zero or negative.
  notPositive,

  /// The commission is negative.
  negative,

  /// The commission is larger than the amount.
  exceedsAmount,

  /// The server refused the value although the form let it through.
  rejectedByServer,
}

sealed class TripFormResult {
  const TripFormResult();
}

final class TripFormValid extends TripFormResult {
  const TripFormValid(this.trip);

  final Trip trip;
}

final class TripFormInvalid extends TripFormResult {
  const TripFormInvalid(this.errors);

  /// At most one error per field, for every field that has one.
  final Map<TripField, TripFieldError> errors;
}

/// The share of the amount the form suggests as commission.
const commissionPercent = 15;

/// 15 % of [amount], rounded half up. The server does not compute the
/// commission, it only checks it; this is a suggestion the driver can edit.
int suggestedCommission(int amount) =>
    amount <= 0 ? 0 : (amount * commissionPercent + 50) ~/ 100;

/// Applies the same rules as the server (`end > start`, `amount > 0`,
/// `0 ≤ commission ≤ amount`) so that most mistakes never leave the device.
/// [offset] is the driver's zone: the typed times are on that clock.
TripFormResult validateTripForm(TripForm form, {required Duration offset}) {
  final errors = <TripField, TripFieldError>{};

  final start = _parseClock(form.startText);
  final end = _parseClock(form.endText);
  if (start == null) {
    errors[TripField.start] = _timeError(form.startText);
  }
  if (end == null) {
    errors[TripField.end] = _timeError(form.endText);
  }

  ZonedTime? startAt;
  ZonedTime? endAt;
  if (start != null && end != null) {
    startAt = ZonedTime(
      date: form.date,
      hour: start.hour,
      minute: start.minute,
      offset: offset,
    );
    endAt = ZonedTime(
      date: form.endsNextDay ? form.date.addDays(1) : form.date,
      hour: end.hour,
      minute: end.minute,
      offset: offset,
    );
    if (!endAt.isAfter(startAt)) {
      errors[TripField.end] = TripFieldError.endNotAfterStart;
    }
  }

  final amount = _parseInt(form.amountText);
  if (amount == null) {
    errors[TripField.amount] = _numberError(form.amountText);
  } else if (amount <= 0) {
    errors[TripField.amount] = TripFieldError.notPositive;
  }

  final commission = _parseInt(form.commissionText);
  if (commission == null) {
    errors[TripField.commission] = _numberError(form.commissionText);
  } else if (commission < 0) {
    errors[TripField.commission] = TripFieldError.negative;
  } else if (amount != null && amount > 0 && commission > amount) {
    // Only against a valid amount: one wrong amount is one error, not two.
    errors[TripField.commission] = TripFieldError.exceedsAmount;
  }

  if (errors.isNotEmpty) return TripFormInvalid(errors);
  return TripFormValid(
    Trip(
      id: form.id,
      start: startAt!,
      end: endAt!,
      amount: amount!,
      payment: form.payment,
      commission: commission!,
    ),
  );
}

/// Parses a typed sum; spaces between digit groups are allowed.
int? parseAmount(String text) => _parseInt(text);

/// Parses `8:10` or `08:10`.
({int hour, int minute})? parseClock(String text) => _parseClock(text);

final _clock = RegExp(r'^(\d{1,2}):(\d{2})$');
final _spaces = RegExp(r'[\s  ]');

({int hour, int minute})? _parseClock(String text) {
  final match = _clock.firstMatch(text.trim());
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

int? _parseInt(String text) {
  final cleaned = text.replaceAll(_spaces, '');
  if (!RegExp(r'^-?\d{1,12}$').hasMatch(cleaned)) return null;
  return int.parse(cleaned);
}

TripFieldError _timeError(String text) =>
    text.trim().isEmpty ? TripFieldError.required : TripFieldError.invalidTime;

TripFieldError _numberError(String text) => text.trim().isEmpty
    ? TripFieldError.required
    : TripFieldError.invalidNumber;
