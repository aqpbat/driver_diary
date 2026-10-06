import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/local_date.dart';
import '../../../../core/domain/trip.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/trip_form.dart';
import '../../domain/trip_form_validator.dart';
import '../../domain/usecases/add_trip.dart';

part 'add_trip_state.dart';

class AddTripCubit extends Cubit<AddTripState> {
  /// [newId] is called exactly once, here. Every attempt to send this form,
  /// including a retry after a timeout, carries that one id — a fresh id on
  /// retry would defeat the server's duplicate protection.
  AddTripCubit({
    required this._addTrip,
    required String Function() newId,
    required LocalDate date,
    required this._offset,
  }) : super(
         AddTripEditing(
           form: TripForm(id: newId(), date: date),
         ),
       );

  final AddTrip _addTrip;

  /// The driver's zone: typed times are on that clock.
  final Duration _offset;

  void dateChanged(LocalDate date) => _edit(state.form.copyWith(date: date));

  void startChanged(String text) =>
      _edit(state.form.copyWith(startText: text), touched: TripField.start);

  void endChanged(String text) =>
      _edit(state.form.copyWith(endText: text), touched: TripField.end);

  void endsNextDayChanged(bool value) =>
      _edit(state.form.copyWith(endsNextDay: value), touched: TripField.end);

  void paymentChanged(Payment payment) =>
      _edit(state.form.copyWith(payment: payment), touched: TripField.payment);

  /// Also refreshes the suggested commission until the driver has typed one.
  void amountChanged(String text) {
    var form = state.form.copyWith(amountText: text);
    if (!state.commissionEdited) {
      final amount = parseAmount(text);
      form = form.copyWith(
        commissionText: amount == null || amount <= 0
            ? ''
            : suggestedCommission(amount).toString(),
      );
    }
    _edit(form, touched: TripField.amount, alsoTouched: TripField.commission);
  }

  void commissionChanged(String text) => _edit(
    state.form.copyWith(commissionText: text),
    touched: TripField.commission,
    commissionEdited: true,
  );

  Future<void> submit() async {
    final current = state;
    // A second tap while the request is in flight, or after success, is
    // ignored: one form sends one trip at a time.
    if (current is! AddTripEditing) return;

    final checked = validateTripForm(current.form, offset: _offset);
    switch (checked) {
      case TripFormInvalid(:final errors):
        emit(
          AddTripEditing(
            form: current.form,
            errors: errors,
            commissionEdited: current.commissionEdited,
          ),
        );
      case TripFormValid(:final trip):
        emit(
          AddTripSubmitting(
            form: current.form,
            commissionEdited: current.commissionEdited,
          ),
        );
        final result = await _addTrip(trip);
        if (isClosed) return;
        switch (result) {
          case Ok(:final value):
            emit(
              AddTripSuccess(
                form: current.form,
                commissionEdited: current.commissionEdited,
                trip: value,
              ),
            );
          case Err(:final failure):
            emit(
              AddTripEditing(
                form: current.form,
                errors: _serverErrors(failure),
                commissionEdited: current.commissionEdited,
                failure: failure,
              ),
            );
        }
    }
  }

  void _edit(
    TripForm form, {
    TripField? touched,
    TripField? alsoTouched,
    bool? commissionEdited,
  }) {
    final current = state;
    if (current is! AddTripEditing) return;
    emit(
      AddTripEditing(
        form: form,
        errors: {
          for (final entry in current.errors.entries)
            if (entry.key != touched && entry.key != alsoTouched)
              entry.key: entry.value,
        },
        commissionEdited: commissionEdited ?? current.commissionEdited,
        failure: current.failure,
      ),
    );
  }

  /// Field errors of a `422`, keyed by the form's fields. Names the form does
  /// not have (`id`, an unknown field) stay in the failure itself.
  static Map<TripField, TripFieldError> _serverErrors(Failure failure) {
    if (failure is! ValidationFailure) return const {};
    const byName = {
      'start': TripField.start,
      'end': TripField.end,
      'amount': TripField.amount,
      'payment': TripField.payment,
      'commission': TripField.commission,
    };
    return {
      for (final name in failure.fields.keys)
        ?byName[name]: TripFieldError.rejectedByServer,
    };
  }
}
