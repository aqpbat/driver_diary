import 'package:flutter/widgets.dart';

import '../app_icons.dart';
import '../app_theme.dart';
import '../app_tokens.dart';
import 'app_pressable.dart';
import 'app_spinner.dart';

enum AppButtonVariant { primary, secondary }

/// A full-width action. While [loading] it shows a spinner and ignores taps;
/// a null [onPressed] disables it.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppIcons? icon;
  final bool loading;

  /// Take all the width available; otherwise hug the label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final enabled = onPressed != null && !loading;
    final (background, foreground) = switch (variant) {
      AppButtonVariant.primary => (colors.accent, colors.onAccent),
      AppButtonVariant.secondary => (colors.surfaceMuted, colors.text),
    };

    return AppPressable(
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      builder: (context, pressed) => AnimatedOpacity(
        // Loading keeps full colour: the button is busy, not unavailable.
        opacity: onPressed == null && !loading ? 0.45 : (pressed ? 0.85 : 1),
        duration: AppDuration.fast,
        child: Container(
          height: AppSizes.control,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x5),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                AppSpinner(color: foreground)
              else ...[
                if (icon case final icon?) ...[
                  AppIcon(icon, size: 20, color: foreground),
                  const SizedBox(width: AppSpace.x2),
                ],
                Flexible(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.type.headline.copyWith(color: foreground),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
