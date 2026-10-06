import '../../../../core/domain/trip.dart';
import '../../../../core/error/result.dart';
import '../repositories/add_trip_repository.dart';

class AddTrip {
  const AddTrip(this._repository);

  final AddTripRepository _repository;

  Future<Result<Trip>> call(Trip trip) => _repository.add(trip);
}
