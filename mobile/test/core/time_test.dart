import 'package:driver_app_demo/core/domain/local_date.dart';
import 'package:driver_app_demo/core/domain/zoned_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ZonedTime.parse', () {
    test('keeps the wall clock and the offset of the string', () {
      final time = ZonedTime.parse('2026-10-01T08:10:00+05:00');

      expect(time.date, LocalDate(2026, 10, 1));
      expect(time.hour, 8);
      expect(time.minute, 10);
      expect(time.offset, const Duration(hours: 5));
      // DateTime.parse would have turned this into 03:10 UTC.
      expect(time.instant, DateTime.utc(2026, 10, 1, 3, 10));
    });

    test('the wall-clock date can differ from the UTC date', () {
      final time = ZonedTime.parse('2026-10-02T00:05:00+05:00');

      expect(time.date, LocalDate(2026, 10, 2));
      expect(time.instant, DateTime.utc(2026, 10, 1, 19, 5));
    });

    test('reads Z, negative and half-hour offsets', () {
      expect(ZonedTime.parse('2026-10-01T03:10:00Z').offset, Duration.zero);
      expect(
        ZonedTime.parse('2026-10-01T03:10:00-03:30').offset,
        const Duration(hours: -3, minutes: -30),
      );
      expect(
        ZonedTime.parse('2026-10-01T03:10:00+05:45').offset,
        const Duration(hours: 5, minutes: 45),
      );
    });

    test('the same moment in two offsets has one instant', () {
      final almaty = ZonedTime.parse('2026-10-01T08:10:00+05:00');
      final utc = ZonedTime.parse('2026-10-01T03:10:00Z');

      expect(almaty.instant, utc.instant);
      expect(almaty, isNot(utc), reason: 'they show different clocks');
    });

    test('reads fractional seconds up to microseconds', () {
      final time = ZonedTime.parse('2026-10-01T08:10:00.5+05:00');
      expect(time.microsecond, 500000);
      expect(
        ZonedTime.parse('2026-10-01T08:10:00.123456789Z').microsecond,
        123456,
      );
    });

    test('rejects a time without an offset and other garbage', () {
      for (final text in [
        '2026-10-01T08:10:00',
        '2026-10-01 08:10:00+05:00',
        '2026-10-01T25:10:00+05:00',
        '2026-10-01T08:61:00+05:00',
        '2026-13-01T08:10:00+05:00',
        '2026-02-30T08:10:00+05:00',
        '2026-10-01T08:10:00+0500',
        '',
      ]) {
        expect(
          () => ZonedTime.parse(text),
          throwsFormatException,
          reason: text,
        );
      }
    });
  });

  group('ZonedTime.toIso', () {
    test('round-trips what the server sends', () {
      for (final text in [
        '2026-10-01T08:10:00+05:00',
        '2026-10-01T23:55:00+05:00',
        '2026-10-01T03:10:00-03:30',
        '2026-10-01T08:10:00.5+05:00',
        '2026-10-01T08:10:00.000001+05:00',
      ]) {
        expect(ZonedTime.parse(text).toIso(), text);
      }
    });

    test('writes Z as +00:00', () {
      expect(
        ZonedTime.parse('2026-10-01T03:10:00Z').toIso(),
        '2026-10-01T03:10:00+00:00',
      );
    });
  });

  test('difference crosses midnight and offsets', () {
    final start = ZonedTime.parse('2026-10-01T23:50:00+05:00');
    final end = ZonedTime.parse('2026-10-02T00:20:00+05:00');

    expect(end.difference(start), const Duration(minutes: 30));
    expect(end.isAfter(start), isTrue);
  });

  group('LocalDate', () {
    test('parses and prints ISO dates', () {
      expect(LocalDate.parse('2026-10-01'), LocalDate(2026, 10, 1));
      expect(LocalDate(2026, 3, 7).toIso(), '2026-03-07');
    });

    test('rejects dates that do not exist', () {
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDate.parse('2026-10-1'), throwsFormatException);
      expect(() => LocalDate.parse('01.10.2026'), throwsFormatException);
    });

    test('steps over month and year ends', () {
      expect(LocalDate(2026, 10, 31).addDays(1), LocalDate(2026, 11, 1));
      expect(LocalDate(2027, 1, 1).addDays(-1), LocalDate(2026, 12, 31));
      expect(
        LocalDate(2026, 10, 5).differenceInDays(LocalDate(2026, 9, 28)),
        7,
      );
    });

    test('knows the weekday', () {
      expect(LocalDate(2026, 10, 1).weekday, DateTime.thursday);
    });

    test('at() gives the date on the given clock, not the device clock', () {
      final instant = DateTime.utc(2026, 10, 1, 20, 30);

      expect(
        LocalDate.at(instant, const Duration(hours: 5)),
        LocalDate(2026, 10, 2),
      );
      expect(LocalDate.at(instant, Duration.zero), LocalDate(2026, 10, 1));
    });
  });
}
