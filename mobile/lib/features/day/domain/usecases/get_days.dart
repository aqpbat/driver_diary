import '../../../../core/error/result.dart';
import '../entities/day_ref.dart';
import '../repositories/day_repository.dart';

class GetDays {
  const GetDays(this._repository);

  final DayRepository _repository;

  Future<Result<List<DayRef>>> call() => _repository.getDays();
}
