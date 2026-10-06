import 'package:flutter/widgets.dart';

import '../../../../core/design/design.dart';
import '../../../../core/format/money.dart';
import '../../domain/entities/day_summary.dart';

/// The headline of the day: what the driver takes home, and under it the
/// revenue, the commission and the number of trips it comes from.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.total});

  final Totals total;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return AppCard(
      color: colors.hero,
      padding: const EdgeInsets.all(AppSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'На руки',
                  style: AppTextStyle.label,
                  color: colors.onHeroMuted,
                ),
                const SizedBox(height: AppSpace.x1),
                // A long sum shrinks to fit rather than wrapping.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    formatMoney(total.net),
                    style: AppTextStyle.display,
                    color: colors.accent,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.x4),
          Container(height: 1, color: colors.heroDivider),
          const SizedBox(height: AppSpace.x4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _Metric(
                  label: 'Выручка',
                  value: formatMoney(total.revenue),
                ),
              ),
              Expanded(
                flex: 5,
                child: _Metric(
                  label: 'Комиссия',
                  value: formatMoney(total.commission),
                ),
              ),
              Expanded(
                flex: 3,
                child: _Metric(label: 'Поездок', value: '${total.tripsCount}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(label, style: AppTextStyle.label, color: colors.onHeroMuted),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppText(
              value,
              style: AppTextStyle.numeric,
              color: colors.onHero,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
