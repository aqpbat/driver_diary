import 'package:flutter/widgets.dart';

import '../app_theme.dart';
import '../app_tokens.dart';

/// A rounded surface that groups related content.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.x4),
    this.color,
    this.radius = AppRadius.large,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to the theme's surface colour.
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
