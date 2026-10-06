import '../../../../core/domain/local_date.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/day_overview.dart';
import '../../domain/entities/day_ref.dart';
import '../models/day_dto.dart';

/// Throws `ApiException` or [FormatException]; the repository handles both.
class DayRemoteDataSource {
  const DayRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<DayRef>> fetchDays() async {
    final response = await _api.get('/api/v1/days');
    return DayDto.daysFromJson(response.object);
  }

  Future<DayOverview> fetchDay(LocalDate date) async {
    final response = await _api.get('/api/v1/days/${date.toIso()}');
    return DayDto.overviewFromJson(response.object);
  }
}
