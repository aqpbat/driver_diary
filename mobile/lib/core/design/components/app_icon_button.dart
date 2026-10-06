import 'package:flutter/widgets.dart';

import '../app_icons.dart';
import '../app_theme.dart';
import '../app_tokens.dart';
import 'app_pressable.dart';

/// A round icon-only button. [semanticLabel] is required: an icon alone says
/// nothing to a screen reader.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.filled = true,
  });

  final AppIcons icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Draw the circle behind the icon even when idle.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return AppPressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, pressed) => AnimatedContainer(
        duration: AppDuration.fast,
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pressed
              ? colors.surfaceMuted
              : (filled ? colors.surface : const Color(0x00000000)),
        ),
        child: AppIcon(
          icon,
          size: 22,
          color: onPressed == null ? colors.textFaint : colors.text,
        ),
      ),
    );
  }
}
