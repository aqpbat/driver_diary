import '../../../../core/domain/trip.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/repositories/add_trip_repository.dart';
import '../datasources/add_trip_remote_data_source.dart';

class AddTripRepositoryImpl implements AddTripRepository {
  const AddTripRepositoryImpl(this._remote);

  final AddTripRemoteDataSource _remote;

  @override
  Future<Result<Trip>> add(Trip trip) async {
    try {
      return Ok(await _remote.postTrip(trip));
    } on ApiException catch (e) {
      return Err(failureFrom(e));
    } on FormatException catch (e) {
      return Err(failureFrom(e));
    }
  }
}
