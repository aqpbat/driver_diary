import 'package:flutter/widgets.dart';

import '../app_icons.dart';
import '../app_theme.dart';
import '../app_tokens.dart';
import 'app_icon_button.dart';

/// Slides [builder]'s widget up from the bottom edge over a dimmed page.
/// Completes with the value passed to `Navigator.pop`, or null when the
/// sheet is dismissed by tapping outside or by the back gesture.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  // AppTheme sits above the Navigator, so the sheet inherits it.
  final scrim = AppTheme.of(context).colors.scrim;
  return Navigator.of(context)
      .push<T>(_SheetRoute<T>(builder: builder, scrim: scrim));
}

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({required this.builder, required this.scrim});

  final WidgetBuilder builder;
  final Color scrim;

  @override
  Color get barrierColor => scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => 'Закрыть';

  @override
  Duration get transitionDuration => AppDuration.slow;

  @override
  Duration get reverseTransitionDuration => AppDuration.normal;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: animation,
            curve: AppCurves.standard,
            reverseCurve: Curves.easeIn,
          ),
        ),
    child: child,
  );
}

/// The body of a bottom sheet: a rounded surface with a title, a close
/// button and scrollable content that stays above the keyboard.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);
    final colors = theme.colors;
    final media = MediaQuery.of(context);
    // On a wide screen the sheet floats as a card instead of hugging the edge.
    final floating = media.size.width > AppSizes.contentMaxWidth + AppSpace.x8;

    return Align(
      alignment: floating ? Alignment.center : Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: media.padding.top + AppSpace.x6,
          bottom: media.viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: title,
            explicitChildNodes: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: floating
                    ? BorderRadius.circular(AppRadius.sheet)
                    : const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.sheet),
                      ),
              ),
              child: SafeArea(
                top: false,
                // With the keyboard up its inset already covers the notch.
                bottom: media.viewInsets.bottom == 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.x5,
                        AppSpace.x4,
                        AppSpace.x3,
                        AppSpace.x2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: theme.type.title.copyWith(
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ),
                          AppIconButton(
                            icon: AppIcons.close,
                            semanticLabel: 'Закрыть',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.x5,
                          AppSpace.x2,
                          AppSpace.x5,
                          AppSpace.x5,
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
