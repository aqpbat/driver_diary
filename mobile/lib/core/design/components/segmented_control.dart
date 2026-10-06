import 'package:flutter/widgets.dart';

import '../app_icons.dart';
import '../app_theme.dart';
import '../app_tokens.dart';
import 'app_pressable.dart';

final class Segment<T> {
  const Segment({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  final T value;
  final String label;
  final AppIcons? icon;

  /// Tint of the icon when the segment is selected.
  final Color? color;
}

/// A choice of exactly one of a few options, e.g. cash or card.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<Segment<T>> segments;
  final T value;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    return Opacity(
      opacity: onChanged == null ? 0.6 : 1,
      child: Container(
        height: AppSizes.control,
        padding: const EdgeInsets.all(AppSpace.x1),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(
                child: AppPressable(
                  onTap: onChanged == null
                      ? null
                      : () => onChanged!(segment.value),
                  selected: segment.value == value,
                  semanticLabel: segment.label,
                  builder: (context, pressed) {
                    final selected = segment.value == value;
                    return AnimatedContainer(
                      duration: AppDuration.normal,
                      curve: AppCurves.standard,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.surface
                            : const Color(0x00000000),
                        borderRadius: BorderRadius.circular(
                          AppRadius.medium - AppSpace.x1,
                        ),
                        boxShadow: [
                          if (selected)
                            BoxShadow(
                              color: colors.shadow,
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (segment.icon case final icon?) ...[
                            AppIcon(
                              icon,
                              size: 20,
                              color: selected
                                  ? (segment.color ?? colors.text)
                                  : colors.textMuted,
                            ),
                            const SizedBox(width: AppSpace.x2),
                          ],
                          ExcludeSemantics(
                            child: Text(
                              segment.label,
                              style: theme.type.bodyStrong.copyWith(
                                color: selected
                                    ? colors.text
                                    : colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
