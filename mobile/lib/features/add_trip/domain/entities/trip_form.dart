import 'package:equatable/equatable.dart';

import '../../../../core/domain/local_date.dart';
import '../../../../core/domain/trip.dart';

/// The fields of the form that can carry an error.
enum TripField { start, end, amount, payment, commission }

/// The add-trip form exactly as the driver typed it. Text stays text until
/// `validateTripForm` turns the whole form into a trip.
final class TripForm extends Equatable {
  const TripForm({
    required this.id,
    required this.date,
    this.startText = '',
    this.endText = '',
    this.endsNextDay = false,
    this.amountText = '',
    this.payment = Payment.cash,
    this.commissionText = '',
  });

  /// Generated once per form and sent with every attempt, so a repeat after
  /// a lost answer cannot create a second trip.
  final String id;

  /// The day the trip started on.
  final LocalDate date;

  /// `HH:MM`
  final String startText;

  /// `HH:MM`
  final String endText;

  /// The trip ran past midnight: the end time is on the day after [date].
  final bool endsNextDay;

  final String amountText;
  final Payment payment;
  final String commissionText;

  TripForm copyWith({
    LocalDate? date,
    String? startText,
    String? endText,
    bool? endsNextDay,
    String? amountText,
    Payment? payment,
    String? commissionText,
  }) => TripForm(
    id: id,
    date: date ?? this.date,
    startText: startText ?? this.startText,
    endText: endText ?? this.endText,
    endsNextDay: endsNextDay ?? this.endsNextDay,
    amountText: amountText ?? this.amountText,
    payment: payment ?? this.payment,
    commissionText: commissionText ?? this.commissionText,
  );

  @override
  List<Object?> get props => [
    id,
    date,
    startText,
    endText,
    endsNextDay,
    amountText,
    payment,
    commissionText,
  ];
}
