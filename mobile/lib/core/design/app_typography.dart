import 'package:flutter/widgets.dart';

const _family = 'Onest';

/// Onest ships as one variable font: the weight has to be set on the `wght`
/// axis as well, `fontWeight` alone picks nothing.
TextStyle _style(
  double size,
  double height,
  int weight, {
  double spacing = 0,
  bool tabular = false,
}) => TextStyle(
  fontFamily: _family,
  fontSize: size,
  height: height / size,
  fontWeight: FontWeight.values[weight ~/ 100 - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  letterSpacing: spacing,
  // Money and times must not jitter between rows or while loading.
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  decoration: TextDecoration.none,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The type scale. Colour is not part of it — it comes from `AppColors`.
final class AppTypography {
  const AppTypography._();

  static const instance = AppTypography._();

  /// The take-home sum.
  TextStyle get display => _style(44, 48, 700, spacing: -1, tabular: true);

  /// Screen and sheet titles.
  TextStyle get title => _style(22, 28, 700, spacing: -0.3);

  /// Section headers, button labels.
  TextStyle get headline => _style(16, 22, 600);

  TextStyle get body => _style(15, 21, 400);

  TextStyle get bodyStrong => _style(15, 21, 600);

  /// Sums and times in lists and inputs.
  TextStyle get numeric => _style(17, 22, 600, tabular: true);

  TextStyle get caption => _style(13, 18, 400, tabular: true);

  /// Small labels above values and fields.
  TextStyle get label => _style(12, 16, 500, spacing: 0.3);
}
