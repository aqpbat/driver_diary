import '../../../../core/domain/local_date.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/day_overview.dart';
import '../../domain/entities/day_ref.dart';
import '../../domain/repositories/day_repository.dart';
import '../datasources/day_remote_data_source.dart';

class DayRepositoryImpl implements DayRepository {
  const DayRepositoryImpl(this._remote);

  final DayRemoteDataSource _remote;

  @override
  Future<Result<List<DayRef>>> getDays() => _guard(_remote.fetchDays);

  @override
  Future<Result<DayOverview>> getDay(LocalDate date) =>
      _guard(() => _remote.fetchDay(date));

  Future<Result<T>> _guard<T>(Future<T> Function() request) async {
    try {
      return Ok(await request());
    } on ApiException catch (e) {
      return Err(failureFrom(e));
    } on FormatException catch (e) {
      return Err(failureFrom(e));
    }
  }
}
