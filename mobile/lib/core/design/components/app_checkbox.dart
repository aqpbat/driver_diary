import 'package:flutter/widgets.dart';

import '../app_icons.dart';
import '../app_theme.dart';
import '../app_tokens.dart';
import 'app_pressable.dart';

/// A labelled on/off choice; the whole row is the tap target.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;

  /// Null disables the control.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Semantics(
      checked: value,
      child: AppPressable(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        semanticLabel: label,
        builder: (context, pressed) => Opacity(
          opacity: onChanged == null ? 0.6 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppDuration.fast,
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value ? colors.accent : colors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(
                      color: value ? colors.accent : colors.textFaint,
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? AppIcon(
                          AppIcons.check,
                          size: 18,
                          color: colors.onAccent,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      style: theme.type.body.copyWith(color: colors.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
