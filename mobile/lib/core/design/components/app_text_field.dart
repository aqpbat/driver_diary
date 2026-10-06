import 'package:flutter/cupertino.dart'
    show CupertinoTextField, OverlayVisibilityMode;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app_theme.dart';
import '../app_tokens.dart';

/// A labelled input with an optional error underneath.
///
/// The editing engine (cursor, selection handles, the copy/paste menu, the
/// keyboard) is `CupertinoTextField` with its own decoration switched off;
/// everything visible is drawn here from the design tokens.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.error,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;

  /// Shown under the field; also turns the border red.
  final String? error;

  /// A unit after the value, e.g. `₸`.
  final String? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final hasError = widget.error != null;
    final borderColor = hasError
        ? colors.error
        : (_focusNode.hasFocus ? colors.text : colors.border);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            widget.label,
            style: theme.type.label.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(height: AppSpace.x1 + 2),
        AnimatedContainer(
          duration: AppDuration.fast,
          height: AppSizes.control,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: borderColor,
              width: hasError || _focusNode.hasFocus ? 1.5 : 1,
            ),
          ),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.6,
            child: Semantics(
              label: widget.label,
              child: CupertinoTextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                decoration: null,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.x4),
                style: theme.type.numeric.copyWith(color: colors.text),
                placeholder: widget.hint,
                placeholderStyle: theme.type.numeric.copyWith(
                  color: colors.textFaint,
                  fontWeight: FontWeight.w400,
                  fontVariations: const [FontVariation('wght', 400)],
                ),
                cursorColor: colors.text,
                keyboardType: widget.keyboardType,
                keyboardAppearance: colors.brightness,
                textInputAction: widget.textInputAction,
                inputFormatters: widget.inputFormatters,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                maxLines: 1,
                suffixMode: OverlayVisibilityMode.always,
                suffix: widget.suffix == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: AppSpace.x4),
                        child: Text(
                          widget.suffix!,
                          style: theme.type.numeric.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        if (widget.error case final error?) ...[
          const SizedBox(height: AppSpace.x1 + 2),
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: theme.type.caption.copyWith(color: colors.error),
            ),
          ),
        ],
      ],
    );
  }
}
