import 'package:flutter/widgets.dart';

import '../../../../core/design/design.dart';
import '../../../../core/domain/local_date.dart';
import '../../../../core/format/dates.dart';

/// The date on screen with "previous day" / "next day" arrows and a reload
/// button.
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.date,
    required this.refreshing,
    required this.onPrevious,
    required this.onNext,
    required this.onRefresh,
    this.onTitleLongPress,
  });

  /// Null until the first list of days arrives.
  final LocalDate? date;
  final bool refreshing;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRefresh;
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    final date = this.date;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x5,
        AppSpace.x3,
        AppSpace.x3,
        AppSpace.x2,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onTitleLongPress,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Дневник смен',
                    style: AppTextStyle.label,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: 2),
                  Semantics(
                    header: true,
                    child: AppText(
                      date == null ? 'Загрузка…' : formatDayTitle(date),
                      style: AppTextStyle.title,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (refreshing)
            SizedBox.square(
              dimension: 44,
              child: Center(child: AppSpinner(color: colors.textMuted)),
            )
          else
            AppIconButton(
              icon: AppIcons.refresh,
              semanticLabel: 'Обновить',
              filled: false,
              onPressed: onRefresh,
            ),
          AppIconButton(
            icon: AppIcons.chevronLeft,
            semanticLabel: 'Предыдущий день',
            onPressed: onPrevious,
          ),
          const SizedBox(width: AppSpace.x2),
          AppIconButton(
            icon: AppIcons.chevronRight,
            semanticLabel: 'Следующий день',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
