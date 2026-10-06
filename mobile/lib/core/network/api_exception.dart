/// What [ApiClient] throws. Repositories catch these and turn them into a
/// `Failure`; nothing above the `data` layer sees them.
sealed class ApiException implements Exception {
  const ApiException();
}

/// No answer: connection refused, DNS failure, timeout, CORS on the web.
final class ApiNetworkException extends ApiException {
  const ApiNetworkException(this.cause);

  final Object cause;

  @override
  String toString() => 'ApiNetworkException: $cause';
}

/// The server answered with a non-2xx status. [code] and [fields] come from
/// the error envelope `{"error": {"code", "message", "fields"}}` when the
/// body carries one.
final class ApiErrorException extends ApiException {
  const ApiErrorException({
    required this.status,
    this.code,
    this.message,
    this.fields = const {},
  });

  final int status;
  final String? code;
  final String? message;
  final Map<String, String> fields;

  @override
  String toString() => 'ApiErrorException: $status $code $message';
}

/// A 2xx answer whose body is not the JSON we expect.
final class ApiFormatException extends ApiException {
  const ApiFormatException(this.message);

  final String message;

  @override
  String toString() => 'ApiFormatException: $message';
}
