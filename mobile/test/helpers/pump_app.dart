import 'package:driver_app_demo/core/design/design.dart';
import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] the way the real app hosts a page: inside a `WidgetsApp`
/// with the design tokens above the navigator.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) {
  final theme = AppThemeData.of(brightness);
  return tester.pumpWidget(
    WidgetsApp(
      color: theme.colors.accent,
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      builder: (context, navigator) => AppTheme(
        data: theme,
        child: DefaultTextStyle(
          style: theme.type.body.copyWith(color: theme.colors.text),
          child: navigator!,
        ),
      ),
      home: child,
    ),
  );
}
