part of 'add_trip_cubit.dart';

sealed class AddTripState extends Equatable {
  const AddTripState({
    required this.form,
    this.errors = const {},
    this.commissionEdited = false,
  });

  final TripForm form;

  /// Errors to show next to fields; a field loses its error when edited.
  final Map<TripField, TripFieldError> errors;

  /// Once the driver types a commission, the form stops suggesting one.
  final bool commissionEdited;

  @override
  List<Object?> get props => [form, errors, commissionEdited];
}

/// The form is waiting for input. [failure] is set when the last attempt to
/// send it did not go through.
final class AddTripEditing extends AddTripState {
  const AddTripEditing({
    required super.form,
    super.errors,
    super.commissionEdited,
    this.failure,
  });

  final Failure? failure;

  @override
  List<Object?> get props => [...super.props, failure];
}

/// The request is in flight; the form is locked.
final class AddTripSubmitting extends AddTripState {
  const AddTripSubmitting({required super.form, super.commissionEdited});
}

/// The server has the trip; [trip] is its stored copy.
final class AddTripSuccess extends AddTripState {
  const AddTripSuccess({
    required super.form,
    super.commissionEdited,
    required this.trip,
  });

  final Trip trip;

  @override
  List<Object?> get props => [...super.props, trip];
}
