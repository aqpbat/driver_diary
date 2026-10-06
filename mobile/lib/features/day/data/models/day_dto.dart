import '../../../../core/domain/local_date.dart';
import '../../../../core/network/trip_dto.dart';
import '../../domain/entities/day_overview.dart';
import '../../domain/entities/day_ref.dart';
import '../../domain/entities/day_summary.dart';

/// Readers for the bodies of `GET /days` and `GET /days/{date}`. Each throws
/// [FormatException] when the body does not match the contract.
abstract final class DayDto {
  /// `{"days": [{"date": "2026-10-01", "trips_count": 2}]}`
  static List<DayRef> daysFromJson(Map<String, dynamic> json) => [
    for (final item in _list(json, 'days'))
      DayRef(
        date: LocalDate.parse(_string(_object(item), 'date')),
        tripsCount: _int(_object(item), 'trips_count'),
      ),
  ];

  /// `{"date": ..., "summary": {...}, "trips": [...]}`
  static DayOverview overviewFromJson(Map<String, dynamic> json) {
    final summary = _object(json['summary']);
    final byPayment = _object(summary['by_payment']);
    return DayOverview(
      date: LocalDate.parse(_string(json, 'date')),
      summary: DaySummary(
        total: _totals(summary),
        cash: _totals(_object(byPayment['cash'])),
        card: _totals(_object(byPayment['card'])),
      ),
      trips: [for (final item in _list(json, 'trips')) TripDto.fromJson(item)],
    );
  }

  static Totals _totals(Map<String, dynamic> json) => Totals(
    tripsCount: _int(json, 'trips_count'),
    revenue: _int(json, 'revenue'),
    commission: _int(json, 'commission'),
    net: _int(json, 'net'),
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('expected a JSON object');
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('"$key" must be an array');
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
