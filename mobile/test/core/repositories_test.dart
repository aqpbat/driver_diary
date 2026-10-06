import 'dart:convert';

import 'package:driver_app_demo/core/error/failure.dart';
import 'package:driver_app_demo/core/error/result.dart';
import 'package:driver_app_demo/core/network/api_client.dart';
import 'package:driver_app_demo/features/add_trip/data/datasources/add_trip_remote_data_source.dart';
import 'package:driver_app_demo/features/add_trip/data/repositories/add_trip_repository_impl.dart';
import 'package:driver_app_demo/features/day/data/datasources/day_remote_data_source.dart';
import 'package:driver_app_demo/features/day/data/repositories/day_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fixtures.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

ApiClient _api(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 1),
}) => ApiClient(
  baseUrl: 'https://api.test/',
  httpClient: MockClient(handler),
  timeout: timeout,
);

AddTripRepositoryImpl _addRepo(MockClientHandler handler) =>
    AddTripRepositoryImpl(AddTripRemoteDataSource(_api(handler)));

DayRepositoryImpl _dayRepo(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 1),
}) => DayRepositoryImpl(DayRemoteDataSource(_api(handler, timeout: timeout)));

/// The failure of [result]; fails the test if it is a success.
Failure _failure(Result<Object?> result) => switch (result) {
  Err(:final failure) => failure,
  Ok(:final value) => fail('expected a failure, got $value'),
};

String _tripJson() => jsonEncode({
  'id': 't-1001',
  'start': '2026-10-01T08:10:00+05:00',
  'end': '2026-10-01T08:42:00+05:00',
  'amount': 2400,
  'payment': 'card',
  'commission': 360,
});

void main() {
  group('AddTripRepository', () {
    test('posts the trip as JSON with its offset', () async {
      late http.Request sent;
      final repo = _addRepo((request) async {
        sent = request;
        return http.Response(_tripJson(), 201, headers: _json);
      });

      await repo.add(cardTrip);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.test/api/v1/trips');
      expect(sent.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), jsonDecode(_tripJson()));
    });

    test('201 (created) is a success', () async {
      final repo = _addRepo(
        (_) async => http.Response(_tripJson(), 201, headers: _json),
      );

      expect(await repo.add(cardTrip), Ok(cardTrip));
    });

    test('200 (the same trip was already saved) is a success too', () async {
      final repo = _addRepo(
        (_) async => http.Response(_tripJson(), 200, headers: _json),
      );

      expect(await repo.add(cardTrip), Ok(cardTrip));
    });

    test('409 becomes ConflictFailure', () async {
      final repo = _addRepo(
        (_) async => http.Response(
          '{"error": {"code": "id_conflict", "message": "another trip with '
          'this id already exists"}}',
          409,
          headers: _json,
        ),
      );

      expect(_failure(await repo.add(cardTrip)), const ConflictFailure());
    });

    test(
      '422 becomes ValidationFailure with the server field errors',
      () async {
        final repo = _addRepo(
          (_) async => http.Response(
            '{"error": {"code": "validation_failed", "message": "trip is '
            'invalid", "fields": {"end": "must be after start", "amount": '
            '"must be greater than 0"}}}',
            422,
            headers: _json,
          ),
        );

        final result = await repo.add(cardTrip);

        expect(
          _failure(result),
          const ValidationFailure({
            'end': 'must be after start',
            'amount': 'must be greater than 0',
          }),
        );
      },
    );

    test('a dropped connection becomes NetworkFailure', () async {
      final repo = _addRepo(
        (_) async => throw http.ClientException('Connection reset by peer'),
      );

      expect(_failure(await repo.add(cardTrip)), const NetworkFailure());
    });

    test('500 becomes UnknownFailure', () async {
      final repo = _addRepo(
        (_) async => http.Response(
          '{"error": {"code": "internal", "message": "internal error"}}',
          500,
          headers: _json,
        ),
      );

      final result = await repo.add(cardTrip);

      expect(_failure(result), isA<UnknownFailure>());
    });

    test('an error that is not JSON still maps by status', () async {
      final repo = _addRepo(
        (_) async => http.Response('<html>Bad Gateway</html>', 502),
      );

      expect(_failure(await repo.add(cardTrip)), isA<UnknownFailure>());
    });
  });

  group('DayRepository', () {
    test('reads the list of days', () async {
      final repo = _dayRepo((request) async {
        expect(request.url.path, '/api/v1/days');
        return http.Response(
          '{"days": [{"date": "2026-10-01", "trips_count": 2}]}',
          200,
          headers: _json,
        );
      });

      final result = await repo.getDays();

      expect((result as Ok).value, [days.first]);
    });

    test('asks for a day by its ISO date', () async {
      final repo = _dayRepo((request) async {
        expect(request.url.path, '/api/v1/days/2026-10-01');
        return http.Response(oct1Json, 200, headers: _json);
      });

      expect(await repo.getDay(oct1), Ok(oct1Overview));
    });

    test('a timeout becomes NetworkFailure', () async {
      final repo = _dayRepo((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(oct1Json, 200, headers: _json);
      }, timeout: const Duration(milliseconds: 20));

      expect(_failure(await repo.getDay(oct1)), const NetworkFailure());
    });

    test('a dropped connection becomes NetworkFailure', () async {
      final repo = _dayRepo((_) async => throw http.ClientException('offline'));

      expect(_failure(await repo.getDays()), const NetworkFailure());
    });

    test('a 200 that is not the contract becomes UnknownFailure', () async {
      for (final body in ['not json', '[]', '{"days": "many"}']) {
        final repo = _dayRepo(
          (_) async => http.Response(body, 200, headers: _json),
        );

        final result = await repo.getDays();

        expect(_failure(result), isA<UnknownFailure>(), reason: body);
      }
    });

    test('400 for a bad date becomes UnknownFailure', () async {
      final repo = _dayRepo(
        (_) async => http.Response(
          '{"error": {"code": "invalid_date", "message": "date must look '
          'like 2026-10-01"}}',
          400,
          headers: _json,
        ),
      );

      expect(_failure(await repo.getDay(oct1)), isA<UnknownFailure>());
    });
  });
}
