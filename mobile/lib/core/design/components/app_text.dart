import 'package:flutter/widgets.dart';

import '../app_theme.dart';

enum AppTextStyle {
  display,
  title,
  headline,
  body,
  bodyStrong,
  numeric,
  caption,
  label,
}

/// Text in one of the styles of the type scale. The colour defaults to the
/// theme's main text colour.
class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.style = AppTextStyle.body,
    this.color,
    this.maxLines,
    this.textAlign,
  });

  final String text;
  final AppTextStyle style;
  final Color? color;
  final int? maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final type = theme.type;
    final base = switch (style) {
      AppTextStyle.display => type.display,
      AppTextStyle.title => type.title,
      AppTextStyle.headline => type.headline,
      AppTextStyle.body => type.body,
      AppTextStyle.bodyStrong => type.bodyStrong,
      AppTextStyle.numeric => type.numeric,
      AppTextStyle.caption => type.caption,
      AppTextStyle.label => type.label,
    };
    return Text(
      text,
      style: base.copyWith(color: color ?? theme.colors.text),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}
