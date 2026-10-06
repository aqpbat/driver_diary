import 'package:equatable/equatable.dart';

/// Totals of a set of trips. Money is whole tenge.
final class Totals extends Equatable {
  const Totals({
    required this.tripsCount,
    required this.revenue,
    required this.commission,
    required this.net,
  });

  static const zero = Totals(tripsCount: 0, revenue: 0, commission: 0, net: 0);

  final int tripsCount;
  final int revenue;
  final int commission;

  /// What the driver keeps: revenue minus commission.
  final int net;

  @override
  List<Object?> get props => [tripsCount, revenue, commission, net];
}

/// The summary of one day as the server computed it; the client only shows
/// it and never recomputes it from the trip list.
final class DaySummary extends Equatable {
  const DaySummary({
    required this.total,
    required this.cash,
    required this.card,
  });

  static const empty = DaySummary(
    total: Totals.zero,
    cash: Totals.zero,
    card: Totals.zero,
  );

  final Totals total;
  final Totals cash;
  final Totals card;

  @override
  List<Object?> get props => [total, cash, card];
}
