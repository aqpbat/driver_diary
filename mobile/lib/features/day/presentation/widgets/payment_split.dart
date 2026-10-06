import 'package:flutter/widgets.dart';

import '../../../../core/design/design.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';
import '../../domain/entities/day_summary.dart';

/// How the day's revenue divides between cash and card: a proportional bar
/// and the figures for each kind.
class PaymentSplit extends StatelessWidget {
  const PaymentSplit({super.key, required this.cash, required this.card});

  final Totals cash;
  final Totals card;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: SizedBox(
                height: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (cash.revenue > 0)
                      Expanded(
                        flex: cash.revenue,
                        child: ColoredBox(color: colors.cash),
                      ),
                    if (cash.revenue > 0 && card.revenue > 0)
                      const SizedBox(width: 3),
                    if (card.revenue > 0)
                      Expanded(
                        flex: card.revenue,
                        child: ColoredBox(color: colors.card),
                      ),
                    if (cash.revenue <= 0 && card.revenue <= 0)
                      Expanded(child: ColoredBox(color: colors.surfaceMuted)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.x4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Part(
                  label: 'Наличные',
                  icon: AppIcons.cash,
                  color: colors.cash,
                  totals: cash,
                ),
              ),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: _Part(
                  label: 'Карта',
                  icon: AppIcons.card,
                  color: colors.card,
                  totals: card,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({
    required this.label,
    required this.icon,
    required this.color,
    required this.totals,
  });

  final String label;
  final AppIcons icon;
  final Color color;
  final Totals totals;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(icon, size: 18, color: color),
              const SizedBox(width: AppSpace.x1 + 2),
              Flexible(
                child: AppText(
                  label,
                  style: AppTextStyle.label,
                  color: colors.textMuted,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppText(
              formatMoney(totals.revenue),
              style: AppTextStyle.numeric,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          AppText(
            '${formatTripsCount(totals.tripsCount)} · '
            'на руки ${formatMoney(totals.net)}',
            style: AppTextStyle.caption,
            color: colors.textMuted,
          ),
        ],
      ),
    );
  }
}
