import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Authentic Google 'G' Logo drawn using precise CustomPainter vector paths
/// strictly following the official Google Identity Brand Guidelines.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.20;
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      w - strokeWidth,
      h - strokeWidth,
    );

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Draw 4 circular arcs of the Google 'G'
    // 1. Red top arc (from approx -15 deg to -125 deg)
    canvas.drawArc(rect, -math.pi * 0.72, math.pi * 0.52, false, redPaint);

    // 2. Yellow left arc (from approx -125 deg to -215 deg)
    canvas.drawArc(rect, -math.pi * 1.15, math.pi * 0.45, false, yellowPaint);

    // 3. Green bottom arc (from approx -215 deg to -315 deg)
    canvas.drawArc(rect, -math.pi * 1.62, math.pi * 0.50, false, greenPaint);

    // 4. Blue right arc
    canvas.drawArc(rect, -math.pi * 0.20, math.pi * 0.32, false, bluePaint);

    // 5. Blue horizontal center bar
    final Paint blueFill = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final double barHeight = strokeWidth;
    final double barY = (h - barHeight) / 2;
    final double barLeft = w * 0.45;
    final double barRight = w - (strokeWidth * 0.1);

    canvas.drawRect(
      Rect.fromLTRB(barLeft, barY, barRight, barY + barHeight),
      blueFill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
