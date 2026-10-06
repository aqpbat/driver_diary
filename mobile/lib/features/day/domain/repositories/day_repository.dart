import '../../../../core/domain/local_date.dart';
import '../../../../core/error/result.dart';
import '../entities/day_overview.dart';
import '../entities/day_ref.dart';

abstract interface class DayRepository {
  /// Days that have trips, oldest first.
  Future<Result<List<DayRef>>> getDays();

  /// A day without trips is not an error: it comes back with a zero summary
  /// and an empty list.
  Future<Result<DayOverview>> getDay(LocalDate date);
}
