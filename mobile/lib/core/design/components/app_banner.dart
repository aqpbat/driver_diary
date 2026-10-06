import 'package:flutter/widgets.dart';

import '../app_icons.dart';
import '../app_theme.dart';
import '../app_tokens.dart';
import 'app_pressable.dart';

enum AppBannerKind { error, success }

/// An inline message about the outcome of an action, optionally with one
/// text action such as "Retry".
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.kind,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final AppBannerKind kind;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final (background, foreground, icon) = switch (kind) {
      AppBannerKind.error => (
        colors.errorSurface,
        colors.error,
        AppIcons.alert,
      ),
      AppBannerKind.success => (
        colors.successSurface,
        colors.success,
        AppIcons.check,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.x3,
          vertical: AppSpace.x3,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AppIcon(icon, size: 20, color: foreground),
            ),
            const SizedBox(width: AppSpace.x2),
            Expanded(
              child: Text(
                message,
                style: theme.type.body.copyWith(color: colors.text),
              ),
            ),
            if (actionLabel case final label?) ...[
              const SizedBox(width: AppSpace.x2),
              AppPressable(
                onTap: onAction,
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.6 : 1,
                  child: Text(
                    label,
                    style: theme.type.bodyStrong.copyWith(color: foreground),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
