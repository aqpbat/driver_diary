import 'package:equatable/equatable.dart';

/// A calendar date with no time and no zone: the driver's "day".
final class LocalDate extends Equatable implements Comparable<LocalDate> {
  /// Out-of-range parts roll over, as in [DateTime.utc]: day 32 of October
  /// is the 1st of November.
  factory LocalDate(int year, int month, int day) =>
      LocalDate._(DateTime.utc(year, month, day));

  const LocalDate._(this._utc);

  /// The date of [instant] on a clock running [offset] ahead of UTC.
  factory LocalDate.at(DateTime instant, Duration offset) {
    final wall = instant.toUtc().add(offset);
    return LocalDate(wall.year, wall.month, wall.day);
  }

  /// Parses `2026-10-01`. Throws [FormatException] on anything else,
  /// including dates that do not exist (`2026-02-30`).
  factory LocalDate.parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('Not a date', text);
    }
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final date = LocalDate(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('No such date', text);
    }
    return date;
  }

  static final _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  // Midnight UTC of the date; only the calendar fields are meaningful.
  final DateTime _utc;

  int get year => _utc.year;
  int get month => _utc.month;
  int get day => _utc.day;

  /// Monday is 1, Sunday is 7.
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) => LocalDate(year, month, day + days);

  /// How many days [other] is before this date; negative if it is after.
  int differenceInDays(LocalDate other) => _utc.difference(other._utc).inDays;

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  /// `2026-10-01`
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';

  @override
  int compareTo(LocalDate other) => _utc.compareTo(other._utc);

  @override
  List<Object?> get props => [_utc];

  @override
  String toString() => toIso();
}

String _two(int n) => n.toString().padLeft(2, '0');
