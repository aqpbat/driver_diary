import 'package:equatable/equatable.dart';

import 'local_date.dart';

/// A moment together with the wall-clock time it was written in.
///
/// Dart's [DateTime.parse] converts `08:10+05:00` to `03:10Z` and forgets the
/// offset, so the device would show the trip in its own zone. The diary must
/// show the driver's clock as the server sent it, hence this type.
final class ZonedTime extends Equatable {
  const ZonedTime({
    required this.date,
    required this.hour,
    required this.minute,
    this.second = 0,
    this.microsecond = 0,
    required this.offset,
  });

  /// Parses RFC 3339 with a mandatory offset, e.g.
  /// `2026-10-01T08:10:00+05:00` or `2026-10-01T03:10:00.5Z`.
  factory ZonedTime.parse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw FormatException('Not an RFC 3339 time with an offset', text);
    }
    final hour = int.parse(match[2]!);
    final minute = int.parse(match[3]!);
    final second = int.parse(match[4]!);
    if (hour > 23 || minute > 59 || second > 59) {
      throw FormatException('Time is out of range', text);
    }
    // Fractions beyond microseconds are dropped; the server stores no more.
    final fraction = (match[5] ?? '').padRight(6, '0').substring(0, 6);
    return ZonedTime(
      date: LocalDate.parse(match[1]!),
      hour: hour,
      minute: minute,
      second: second,
      microsecond: int.parse(fraction),
      offset: _parseOffset(match[6]!, text),
    );
  }

  static final _pattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.(\d+))?'
    r'([Zz]|[+-]\d{2}:\d{2})$',
  );

  static Duration _parseOffset(String raw, String source) {
    if (raw == 'Z' || raw == 'z') return Duration.zero;
    final hours = int.parse(raw.substring(1, 3));
    final minutes = int.parse(raw.substring(4, 6));
    if (hours > 23 || minutes > 59) {
      throw FormatException('Offset is out of range', source);
    }
    final offset = Duration(hours: hours, minutes: minutes);
    return raw.startsWith('-') ? -offset : offset;
  }

  /// Wall-clock date and time.
  final LocalDate date;
  final int hour;
  final int minute;
  final int second;
  final int microsecond;

  /// How far the wall clock is ahead of UTC.
  final Duration offset;

  /// The moment itself, in UTC. Two values written with different offsets
  /// have the same instant if they name the same moment.
  DateTime get instant => DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
    second,
    0,
    microsecond,
  ).subtract(offset);

  Duration difference(ZonedTime other) => instant.difference(other.instant);

  bool isAfter(ZonedTime other) => instant.isAfter(other.instant);

  /// RFC 3339 with the original offset: `2026-10-01T08:10:00+05:00`.
  String toIso() {
    final fraction = microsecond == 0
        ? ''
        : '.${microsecond.toString().padLeft(6, '0')}'.replaceFirst(
            RegExp(r'0+$'),
            '',
          );
    return '${date.toIso()}T${_two(hour)}:${_two(minute)}:${_two(second)}'
        '$fraction${_offsetText()}';
  }

  String _offsetText() {
    final minutes = offset.inMinutes;
    final abs = minutes.abs();
    return '${minutes < 0 ? '-' : '+'}${_two(abs ~/ 60)}:${_two(abs % 60)}';
  }

  @override
  List<Object?> get props => [date, hour, minute, second, microsecond, offset];

  @override
  String toString() => toIso();
}

String _two(int n) => n.toString().padLeft(2, '0');
