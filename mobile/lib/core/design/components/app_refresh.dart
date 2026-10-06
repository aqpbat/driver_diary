import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/widgets.dart';

import '../app_theme.dart';
import 'app_spinner.dart';

/// Pull-to-refresh for a `CustomScrollView`: put it first among the slivers
/// and give the scroll view bouncing physics. The gesture comes from
/// `CupertinoSliverRefreshControl`; the indicator is the app's own spinner.
class AppRefreshSliver extends StatelessWidget {
  const AppRefreshSliver({super.key, required this.onRefresh});

  /// The indicator stays until the returned future completes.
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.of(context).colors.textMuted;
    return CupertinoSliverRefreshControl(
      onRefresh: onRefresh,
      builder: (context, mode, pulled, triggerDistance, indicatorExtent) =>
          Center(
            child: Opacity(
              opacity: (pulled / triggerDistance).clamp(0.0, 1.0),
              child: AppSpinner(size: 22, color: color),
            ),
          ),
    );
  }
}
