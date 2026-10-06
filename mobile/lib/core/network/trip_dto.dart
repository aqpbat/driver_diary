import '../domain/trip.dart';
import '../domain/zoned_time.dart';

/// A trip as it travels over the wire. Both features use it: the day feature
/// reads trips, the add-trip feature sends one and reads the saved copy back.
abstract final class TripDto {
  /// Throws [FormatException] when a field is missing or has the wrong type.
  static Trip fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('trip must be a JSON object');
    }
    return Trip(
      id: _string(json, 'id'),
      start: ZonedTime.parse(_string(json, 'start')),
      end: ZonedTime.parse(_string(json, 'end')),
      amount: _int(json, 'amount'),
      payment: _payment(_string(json, 'payment')),
      commission: _int(json, 'commission'),
    );
  }

  static Map<String, dynamic> toJson(Trip trip) => {
    'id': trip.id,
    'start': trip.start.toIso(),
    'end': trip.end.toIso(),
    'amount': trip.amount,
    'payment': trip.payment.name,
    'commission': trip.commission,
  };

  static Payment _payment(String value) => switch (value) {
    'cash' => Payment.cash,
    'card' => Payment.card,
    _ => throw FormatException('unknown payment', value),
  };
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('"$key" must be a string');
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('"$key" must be an integer');
}
