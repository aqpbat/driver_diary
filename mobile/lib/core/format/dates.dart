import '../domain/local_date.dart';
import '../domain/zoned_time.dart';

const _weekdaysShort = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

const _monthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// `чт`
String formatWeekdayShort(LocalDate date) => _weekdaysShort[date.weekday - 1];

/// `чт, 1 октября`
String formatDayTitle(LocalDate date) =>
    '${formatWeekdayShort(date)}, ${date.day} ${_monthsGenitive[date.month - 1]}';

/// `08:10` — the wall clock the server sent, not the device's.
String formatTime(ZonedTime time) => formatClock(time.hour, time.minute);

/// `08:10`
String formatClock(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// `32 мин`, `1 ч`, `1 ч 5 мин`. Seconds are dropped.
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes мин';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} ч' : '${minutes ~/ 60} ч $rest мин';
}

/// `1 поездка`, `3 поездки`, `11 поездок`.
String formatTripsCount(int count) =>
    '$count ${pluralRu(count, 'поездка', 'поездки', 'поездок')}';

/// Picks the Russian plural form for [n]: 1 → [one], 2–4 → [few], else [many].
String pluralRu(int n, String one, String few, String many) {
  final mod100 = n.abs() % 100;
  final mod10 = mod100 % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
