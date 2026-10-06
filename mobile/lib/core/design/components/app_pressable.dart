import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app_tokens.dart';

/// The base of everything tappable: tracks the pressed state, reacts to the
/// keyboard, shows a pointer cursor and announces itself as a button.
/// A null [onTap] means disabled.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.onLongPress,
    this.semanticLabel,
    this.selected,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Builds the look; `pressed` is also true while the control has keyboard
  /// focus.
  final Widget Function(BuildContext context, bool pressed) builder;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _down = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _setDown(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setDown(true) : null,
          onTapUp: _enabled ? (_) => _setDown(false) : null,
          onTapCancel: _enabled ? () => _setDown(false) : null,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: AppDuration.fast,
            curve: AppCurves.standard,
            child: widget.builder(context, _enabled && (_down || _focused)),
          ),
        ),
      ),
    );
  }
}
