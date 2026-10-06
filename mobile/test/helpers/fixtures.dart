import 'package:driver_app_demo/core/domain/local_date.dart';
import 'package:driver_app_demo/core/domain/trip.dart';
import 'package:driver_app_demo/core/domain/zoned_time.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_overview.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_ref.dart';
import 'package:driver_app_demo/features/day/domain/entities/day_summary.dart';

final oct1 = LocalDate(2026, 10, 1);
final oct2 = LocalDate(2026, 10, 2);
final oct4 = LocalDate(2026, 10, 4);
final oct5 = LocalDate(2026, 10, 5);

const almaty = Duration(hours: 5);

final days = [
  DayRef(date: oct1, tripsCount: 2),
  DayRef(date: oct4, tripsCount: 1),
  DayRef(date: oct5, tripsCount: 3),
];

final cardTrip = Trip(
  id: 't-1001',
  start: ZonedTime.parse('2026-10-01T08:10:00+05:00'),
  end: ZonedTime.parse('2026-10-01T08:42:00+05:00'),
  amount: 2400,
  payment: Payment.card,
  commission: 360,
);

final cashTrip = Trip(
  id: 't-1002',
  start: ZonedTime.parse('2026-10-01T09:15:00+05:00'),
  end: ZonedTime.parse('2026-10-01T09:40:00+05:00'),
  amount: 1500,
  payment: Payment.cash,
  commission: 225,
);

/// The example from the API contract: two trips, one per payment kind.
final oct1Overview = DayOverview(
  date: oct1,
  summary: const DaySummary(
    total: Totals(tripsCount: 2, revenue: 3900, commission: 585, net: 3315),
    cash: Totals(tripsCount: 1, revenue: 1500, commission: 225, net: 1275),
    card: Totals(tripsCount: 1, revenue: 2400, commission: 360, net: 2040),
  ),
  trips: [cardTrip, cashTrip],
);

DayOverview emptyOverview(LocalDate date) =>
    DayOverview(date: date, summary: DaySummary.empty, trips: const []);

const oct1Json = '''
{
  "date": "2026-10-01",
  "summary": {
    "trips_count": 2, "revenue": 3900, "commission": 585, "net": 3315,
    "by_payment": {
      "cash": {"trips_count": 1, "revenue": 1500, "commission": 225, "net": 1275},
      "card": {"trips_count": 1, "revenue": 2400, "commission": 360, "net": 2040}
    }
  },
  "trips": [
    {"id": "t-1001", "start": "2026-10-01T08:10:00+05:00", "end": "2026-10-01T08:42:00+05:00", "amount": 2400, "payment": "card", "commission": 360},
    {"id": "t-1002", "start": "2026-10-01T09:15:00+05:00", "end": "2026-10-01T09:40:00+05:00", "amount": 1500, "payment": "cash", "commission": 225}
  ]
}
''';
