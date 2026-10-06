import 'dart:convert';

import 'package:driver_app_demo/core/domain/trip.dart';
import 'package:driver_app_demo/core/domain/zoned_time.dart';
import 'package:driver_app_demo/core/network/trip_dto.dart';
import 'package:driver_app_demo/features/day/data/models/day_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fixtures.dart';

void main() {
  group('TripDto', () {
    test('reads a trip and keeps its wall-clock time', () {
      final trip = TripDto.fromJson(
        jsonDecode(
          '{"id": "t-1", "start": "2026-10-01T23:50:00+05:00", '
          '"end": "2026-10-02T00:20:00+05:00", "amount": 1800, '
          '"payment": "cash", "commission": 270}',
        ),
      );

      expect(trip.id, 't-1');
      expect(trip.start.hour, 23);
      expect(trip.start.minute, 50);
      expect(trip.end.hour, 0);
      expect(trip.payment, Payment.cash);
      expect(trip.amount, 1800);
      expect(trip.commission, 270);
      expect(trip.net, 1530);
      expect(trip.duration, const Duration(minutes: 30));
      // Past midnight, but the trip belongs to the day it started on.
      expect(trip.day.toIso(), '2026-10-01');
    });

    test('writes exactly the fields of the contract', () {
      expect(TripDto.toJson(cardTrip), {
        'id': 't-1001',
        'start': '2026-10-01T08:10:00+05:00',
        'end': '2026-10-01T08:42:00+05:00',
        'amount': 2400,
        'payment': 'card',
        'commission': 360,
      });
    });

    test('survives a round trip', () {
      expect(TripDto.fromJson(TripDto.toJson(cashTrip)), cashTrip);
    });

    test('rejects bodies that break the contract', () {
      final good = TripDto.toJson(cardTrip);
      final broken = <Object?>[
        null,
        <dynamic>[],
        {...good}..remove('id'),
        {...good, 'amount': '2400'},
        {...good, 'amount': 2400.5},
        {...good, 'payment': 'crypto'},
        {...good, 'start': '2026-10-01T08:10:00'},
      ];
      for (final body in broken) {
        expect(
          () => TripDto.fromJson(body),
          throwsFormatException,
          reason: '$body',
        );
      }
    });
  });

  group('DayDto', () {
    test('reads the list of days', () {
      final days = DayDto.daysFromJson(
        jsonDecode(
          '{"days": [{"date": "2026-10-01", "trips_count": 2}, '
          '{"date": "2026-10-04", "trips_count": 1}]}',
        ) as Map<String, dynamic>,
      );

      expect(days.map((d) => d.date.toIso()), ['2026-10-01', '2026-10-04']);
      expect(days.map((d) => d.tripsCount), [2, 1]);
    });

    test('reads a day with its summary and trips', () {
      final overview = DayDto.overviewFromJson(
        jsonDecode(oct1Json) as Map<String, dynamic>,
      );

      expect(overview, oct1Overview);
      expect(
        overview.trips.first.start,
        ZonedTime.parse('2026-10-01T08:10:00+05:00'),
      );
    });

    test('reads an empty day', () {
      final overview = DayDto.overviewFromJson(
        jsonDecode('''
          {"date": "2026-10-03",
           "summary": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0,
             "by_payment": {
               "cash": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0},
               "card": {"trips_count": 0, "revenue": 0, "commission": 0, "net": 0}}},
           "trips": []}
        ''') as Map<String, dynamic>,
      );

      expect(overview.trips, isEmpty);
      expect(overview.summary.total.net, 0);
    });

    test('rejects a body without the summary', () {
      expect(
        () => DayDto.overviewFromJson({'date': '2026-10-01', 'trips': []}),
        throwsFormatException,
      );
    });
  });
}
