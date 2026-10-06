import 'package:equatable/equatable.dart';

/// Why an operation did not produce a value. Exceptions stop at the `data`
/// layer and are turned into one of these.
sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const [];
}

/// The server could not be reached, or did not answer in time.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// The server rejected the data; [fields] maps a field name of the API
/// contract (`start`, `amount`, ...) to the server's message.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.fields);

  final Map<String, String> fields;

  @override
  List<Object?> get props => [fields];
}

/// The trip `id` is already taken by a different trip.
final class ConflictFailure extends Failure {
  const ConflictFailure();
}

/// Anything else: a 5xx, an unexpected status, a response we cannot read.
final class UnknownFailure extends Failure {
  const UnknownFailure([this.details]);

  /// For logs and debugging, never shown to the driver as is.
  final String? details;

  @override
  List<Object?> get props => [details];
}
