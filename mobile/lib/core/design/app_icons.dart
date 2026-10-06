import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The app's own icons, drawn on a 24×24 grid with a 2-point round stroke.
enum AppIcons {
  chevronLeft,
  chevronRight,
  plus,
  close,
  check,
  refresh,
  cash,
  card,
  alert,
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 24, required this.color});

  final AppIcons icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(icon, color),
    ),
  );
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.icon, this.color);

  final AppIcons icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);

    void polyline(List<double> xy) {
      final path = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        path.lineTo(xy[i], xy[i + 1]);
      }
      canvas.drawPath(path, stroke);
    }

    void box(double left, double top, double right, double bottom, double r) =>
        canvas.drawRRect(
          RRect.fromLTRBR(left, top, right, bottom, Radius.circular(r)),
          stroke,
        );

    switch (icon) {
      case AppIcons.chevronLeft:
        polyline([14.5, 5.5, 8, 12, 14.5, 18.5]);
      case AppIcons.chevronRight:
        polyline([9.5, 5.5, 16, 12, 9.5, 18.5]);
      case AppIcons.plus:
        line(12, 5, 12, 19);
        line(5, 12, 19, 12);
      case AppIcons.close:
        line(6.5, 6.5, 17.5, 17.5);
        line(17.5, 6.5, 6.5, 17.5);
      case AppIcons.check:
        polyline([5.5, 12.5, 10, 17, 18.5, 7.5]);
      case AppIcons.refresh:
        const start = -40 * math.pi / 180;
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12.5), radius: 7),
          start,
          290 * math.pi / 180,
          false,
          stroke,
        );
        polyline([18, 3.5, 18, 8, 13.5, 8]);
      case AppIcons.cash:
        box(3, 6.5, 21, 17.5, 2.5);
        canvas.drawCircle(const Offset(12, 12), 2.25, stroke);
      case AppIcons.card:
        box(3, 5.5, 21, 18.5, 3);
        line(3.5, 10, 20.5, 10);
        line(6.5, 14.5, 10, 14.5);
      case AppIcons.alert:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        line(12, 7.75, 12, 12.75);
        canvas.drawCircle(const Offset(12, 16.1), 1.15, fill);
    }
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      icon != oldDelegate.icon || color != oldDelegate.color;
}
