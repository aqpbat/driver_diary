import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_typography.dart';

final class AppThemeData {
  const AppThemeData({required this.colors, required this.type});

  factory AppThemeData.of(Brightness brightness) => AppThemeData(
    colors: brightness == Brightness.dark ? AppColors.dark : AppColors.light,
    type: AppTypography.instance,
  );

  final AppColors colors;
  final AppTypography type;
}

/// Gives the subtree its design tokens: `AppTheme.of(context).colors.accent`.
class AppTheme extends InheritedWidget {
  const AppTheme({super.key, required this.data, required super.child});

  final AppThemeData data;

  static AppThemeData of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(theme != null, 'No AppTheme above this widget');
    return theme!.data;
  }

  @override
  bool updateShouldNotify(AppTheme oldWidget) =>
      data.colors != oldWidget.data.colors;
}
