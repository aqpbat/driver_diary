import '../error/failure.dart';
import 'api_exception.dart';

/// Turns what the `data` layer can catch into a [Failure].
Failure failureFrom(Object error) => switch (error) {
  ApiNetworkException() => const NetworkFailure(),
  ApiErrorException(status: 409) => const ConflictFailure(),
  ApiErrorException(status: 422, :final fields) => ValidationFailure(fields),
  ApiErrorException(:final status, :final code) => UnknownFailure(
    'HTTP $status${code == null ? '' : ' $code'}',
  ),
  ApiFormatException(:final message) => UnknownFailure(message),
  FormatException(:final message) => UnknownFailure(message),
  _ => UnknownFailure(error.toString()),
};
