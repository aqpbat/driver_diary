import 'package:flutter/widgets.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/trip.dart';
import '../../../../core/format/dates.dart';
import '../../../../core/format/money.dart';

/// One trip in the day's list: when, how long, how much and how it was paid.
class TripTile extends StatelessWidget {
  const TripTile({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    final (icon, tint, payment) = switch (trip.payment) {
      Payment.cash => (AppIcons.cash, colors.cash, 'Наличные'),
      Payment.card => (AppIcons.card, colors.card, 'Карта'),
    };
    // A trip that ran past midnight ends on the next calendar day.
    final overnight = trip.end.date != trip.start.date;
    final times =
        '${formatTime(trip.start)} – ${formatTime(trip.end)}'
        '${overnight ? ' +1' : ''}';

    return MergeSemantics(
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x4,
          vertical: AppSpace.x3,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: AppIcon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: AppSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: overnight
                        ? 'с ${formatTime(trip.start)} до '
                              '${formatTime(trip.end)} следующего дня'
                        : null,
                    excludeSemantics: overnight,
                    child: AppText(
                      times,
                      style: AppTextStyle.numeric,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    '$payment · ${formatDuration(trip.duration)}',
                    style: AppTextStyle.caption,
                    color: colors.textMuted,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.x3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(formatMoney(trip.amount), style: AppTextStyle.numeric),
                const SizedBox(height: 2),
                AppText(
                  'комиссия ${formatMoney(trip.commission)}',
                  style: AppTextStyle.caption,
                  color: colors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
