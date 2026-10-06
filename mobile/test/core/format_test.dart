import 'package:driver_app_demo/core/domain/local_date.dart';
import 'package:driver_app_demo/core/domain/zoned_time.dart';
import 'package:driver_app_demo/core/format/dates.dart';
import 'package:driver_app_demo/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nbsp = ' ';

  group('formatMoney', () {
    test('groups thousands with no-break spaces and adds the tenge sign', () {
      expect(formatMoney(0), '0$nbsp₸');
      expect(formatMoney(900), '900$nbsp₸');
      expect(formatMoney(2400), '2${nbsp}400$nbsp₸');
      expect(formatMoney(100000), '100${nbsp}000$nbsp₸');
      expect(formatMoney(1234567), '1${nbsp}234${nbsp}567$nbsp₸');
    });

    test('writes a negative sum with a minus sign', () {
      expect(formatMoney(-1500), '−1${nbsp}500$nbsp₸');
    });
  });

  group('dates', () {
    test('day title is a short weekday, the day and the month', () {
      expect(formatDayTitle(LocalDate(2026, 10, 1)), 'чт, 1 октября');
      expect(formatDayTitle(LocalDate(2026, 10, 4)), 'вс, 4 октября');
      expect(formatDayTitle(LocalDate(2026, 5, 11)), 'пн, 11 мая');
    });

    test('time is the wall clock of the server string', () {
      expect(formatTime(ZonedTime.parse('2026-10-01T08:05:00+05:00')), '08:05');
      // Not converted to UTC and not to the zone of the test machine.
      expect(formatTime(ZonedTime.parse('2026-10-02T00:05:00+05:00')), '00:05');
      expect(formatTime(ZonedTime.parse('2026-10-01T23:55:00-08:00')), '23:55');
    });

    test('duration', () {
      expect(formatDuration(const Duration(minutes: 32)), '32 мин');
      expect(formatDuration(const Duration(minutes: 60)), '1 ч');
      expect(formatDuration(const Duration(minutes: 65)), '1 ч 5 мин');
    });

    test('trip count uses the right plural form', () {
      expect(formatTripsCount(0), '0 поездок');
      expect(formatTripsCount(1), '1 поездка');
      expect(formatTripsCount(2), '2 поездки');
      expect(formatTripsCount(5), '5 поездок');
      expect(formatTripsCount(11), '11 поездок');
      expect(formatTripsCount(12), '12 поездок');
      expect(formatTripsCount(21), '21 поездка');
      expect(formatTripsCount(22), '22 поездки');
      expect(formatTripsCount(111), '111 поездок');
    });
  });
}
