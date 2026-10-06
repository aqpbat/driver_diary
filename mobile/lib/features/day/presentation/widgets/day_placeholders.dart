import 'package:flutter/widgets.dart';

import '../../../../core/design/design.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/format/failure_text.dart';

/// The shape of a loaded day while it is loading.
class DaySkeleton extends StatelessWidget {
  const DaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Загрузка',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x5,
          AppSpace.x3,
          AppSpace.x5,
          AppSpace.x5,
        ),
        children: const [
          Skeleton(height: 172, radius: AppRadius.large),
          SizedBox(height: AppSpace.x3),
          Skeleton(height: 118, radius: AppRadius.large),
          SizedBox(height: AppSpace.x6),
          Skeleton(width: 96, height: 18),
          SizedBox(height: AppSpace.x3),
          Skeleton(height: 66, radius: AppRadius.large),
          SizedBox(height: AppSpace.x2),
          Skeleton(height: 66, radius: AppRadius.large),
          SizedBox(height: AppSpace.x2),
          Skeleton(height: 66, radius: AppRadius.large),
        ],
      ),
    );
  }
}

/// A centred message with an icon, used for "no trips" and "failed to load".
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final AppIcons icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.x8,
        vertical: AppSpace.x10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: AppIcon(icon, size: 28, color: iconColor),
          ),
          const SizedBox(height: AppSpace.x4),
          AppText(
            title,
            style: AppTextStyle.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.x1),
          AppText(
            message,
            color: colors.textMuted,
            textAlign: TextAlign.center,
          ),
          if (action case final action?) ...[
            const SizedBox(height: AppSpace.x5),
            action,
          ],
        ],
      ),
    );
  }
}

class EmptyDay extends StatelessWidget {
  const EmptyDay({super.key});

  @override
  Widget build(BuildContext context) => _Notice(
    icon: AppIcons.plus,
    iconColor: AppTheme.of(context).colors.textMuted,
    title: 'Поездок нет',
    message:
        'За этот день ничего не записано. Добавьте поездку — здесь '
        'появится сводка.',
  );
}

class DayError extends StatelessWidget {
  const DayError({super.key, required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: _Notice(
        icon: AppIcons.alert,
        iconColor: AppTheme.of(context).colors.error,
        title: 'Не удалось загрузить день',
        message: describeFailure(failure),
        action: AppButton(
          label: 'Повторить',
          icon: AppIcons.refresh,
          variant: AppButtonVariant.secondary,
          expand: false,
          onPressed: onRetry,
        ),
      ),
    ),
  );
}
