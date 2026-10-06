import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// A successful (2xx) answer: the status and the decoded JSON body.
final class ApiResponse {
  const ApiResponse(this.status, this.body);

  final int status;
  final Object? body;

  /// The body as a JSON object, or [ApiFormatException] if it is not one.
  Map<String, dynamic> get object {
    final body = this.body;
    if (body is Map<String, dynamic>) return body;
    throw const ApiFormatException('expected a JSON object');
  }
}

/// The one place that talks HTTP. Returns decoded JSON for 2xx and throws an
/// [ApiException] for everything else.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required http.Client httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _base = Uri.parse(baseUrl.replaceFirst(RegExp(r'/+$'), '')),
       _http = httpClient;

  final Uri _base;
  final http.Client _http;
  final Duration timeout;

  Future<ApiResponse> get(String path) =>
      _send(() => _http.get(_uri(path), headers: _headers));

  Future<ApiResponse> post(String path, Map<String, dynamic> body) => _send(
    () => _http.post(
      _uri(path),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ),
  );

  static const _headers = {'Accept': 'application/json'};

  Uri _uri(String path) => _base.replace(path: '${_base.path}$path');

  Future<ApiResponse> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException catch (e) {
      throw ApiNetworkException(e);
    } on http.ClientException catch (e) {
      // Covers socket errors on mobile and failed fetches on the web.
      throw ApiNetworkException(e);
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return ApiResponse(status, _decode(response, orThrow: true));
    }
    throw _error(status, _decode(response, orThrow: false));
  }

  Object? _decode(http.Response response, {required bool orThrow}) {
    try {
      // The server always sends UTF-8; do not trust a missing charset.
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      if (orThrow) throw const ApiFormatException('response is not JSON');
      return null;
    }
  }

  ApiErrorException _error(int status, Object? body) {
    final error = body is Map<String, dynamic> ? body['error'] : null;
    if (error is! Map<String, dynamic>) {
      return ApiErrorException(status: status);
    }
    final code = error['code'];
    final message = error['message'];
    final fields = error['fields'];
    return ApiErrorException(
      status: status,
      code: code is String ? code : null,
      message: message is String ? message : null,
      fields: fields is Map<String, dynamic>
          ? {
              for (final entry in fields.entries)
                if (entry.value is String) entry.key: entry.value as String,
            }
          : const {},
    );
  }
}
