import '../../../../core/domain/local_date.dart';
import '../../../../core/error/result.dart';
import '../entities/day_overview.dart';
import '../repositories/day_repository.dart';

class GetDay {
  const GetDay(this._repository);

  final DayRepository _repository;

  Future<Result<DayOverview>> call(LocalDate date) => _repository.getDay(date);
}
