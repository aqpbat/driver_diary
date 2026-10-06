import '../../../../core/domain/trip.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/trip_dto.dart';

/// Throws `ApiException` or [FormatException]; the repository handles both.
class AddTripRemoteDataSource {
  const AddTripRemoteDataSource(this._api);

  final ApiClient _api;

  /// `201` (created) and `200` (the same trip was already saved) are both a
  /// success and both carry the stored trip.
  Future<Trip> postTrip(Trip trip) async {
    final response = await _api.post('/api/v1/trips', TripDto.toJson(trip));
    return TripDto.fromJson(response.body);
  }
}
