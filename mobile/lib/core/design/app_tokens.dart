import 'package:flutter/widgets.dart';

/// Spacing on a 4-point grid.
abstract final class AppSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
}

abstract final class AppRadius {
  static const double small = 8;
  static const double medium = 14;
  static const double large = 20;
  static const double sheet = 28;
  static const double pill = 999;
}

abstract final class AppDuration {
  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
}

abstract final class AppCurves {
  static const standard = Cubic(0.2, 0, 0, 1);
}

abstract final class AppSizes {
  /// Minimum height of anything tappable.
  static const double control = 52;

  /// Content never grows wider than this; matters on the web and tablets.
  static const double contentMaxWidth = 560;
}
