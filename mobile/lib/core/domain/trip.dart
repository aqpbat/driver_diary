import 'package:equatable/equatable.dart';

import 'local_date.dart';
import 'zoned_time.dart';

enum Payment { cash, card }

/// One trip of the driver. Money is whole tenge, never fractional.
final class Trip extends Equatable {
  const Trip({
    required this.id,
    required this.start,
    required this.end,
    required this.amount,
    required this.payment,
    required this.commission,
  });

  /// Also the idempotency key: the server treats a second trip with the same
  /// id and the same content as a repeat of the first.
  final String id;
  final ZonedTime start;
  final ZonedTime end;
  final int amount;
  final Payment payment;
  final int commission;

  /// What the driver keeps.
  int get net => amount - commission;

  Duration get duration => end.difference(start);

  /// The day the trip belongs to: the date it started on. The server sends
  /// times in the driver's zone, so this agrees with its grouping.
  LocalDate get day => start.date;

  @override
  List<Object?> get props => [id, start, end, amount, payment, commission];
}
