import '../../../../core/domain/trip.dart';
import '../../../../core/error/result.dart';

abstract interface class AddTripRepository {
  /// Saves [trip] and returns it as the server stored it. Sending the same
  /// trip again is safe and also succeeds: the server recognises the repeat
  /// by `id`.
  Future<Result<Trip>> add(Trip trip);
}
