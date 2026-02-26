import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class FerriLogo extends StatelessWidget {
  final double size;

  const FerriLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _FerriLogoPainter(),
      ),
    );
  }
}

class _FerriLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100; // scale factor from 100x100 viewBox

    // Background rounded rectangle
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(22 * s),
    );
    canvas.drawRRect(bgRect, Paint()..color = FerriColors.primary);

    // Body — large cream ellipse
    _drawEllipse(canvas, s, 50, 62, 28, 22, const Color(0xFFFFF0EA));

    // Head — dark terracotta ellipse
    _drawEllipse(canvas, s, 50, 40, 22, 20, FerriColors.primaryDark);

    // Face — cream ellipse
    _drawEllipse(canvas, s, 50, 44, 14, 12, const Color(0xFFFFF0EA));

    // Left ear — rotated ellipse
    _drawRotatedEllipse(canvas, s, 32, 24, 7, 9, -15, FerriColors.primaryDark);

    // Right ear — rotated ellipse
    _drawRotatedEllipse(canvas, s, 68, 24, 7, 9, 15, FerriColors.primaryDark);

    // Left eye
    _drawCircle(canvas, s, 42, 41, 4, const Color(0xFF1A1B2E));

    // Right eye
    _drawCircle(canvas, s, 58, 41, 4, const Color(0xFF1A1B2E));

    // Left eye highlight
    _drawCircle(canvas, s, 43.5, 39.5, 1.5, Colors.white);

    // Right eye highlight
    _drawCircle(canvas, s, 59.5, 39.5, 1.5, Colors.white);

    // Nose
    _drawEllipse(canvas, s, 50, 48, 3, 2, const Color(0xFF1A1B2E));
  }

  void _drawEllipse(
    Canvas canvas,
    double s,
    double cx,
    double cy,
    double rx,
    double ry,
    Color color,
  ) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx * s, cy * s),
        width: rx * 2 * s,
        height: ry * 2 * s,
      ),
      Paint()..color = color,
    );
  }

  void _drawRotatedEllipse(
    Canvas canvas,
    double s,
    double cx,
    double cy,
    double rx,
    double ry,
    double degrees,
    Color color,
  ) {
    canvas.save();
    canvas.translate(cx * s, cy * s);
    canvas.rotate(degrees * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: rx * 2 * s,
        height: ry * 2 * s,
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  void _drawCircle(
    Canvas canvas,
    double s,
    double cx,
    double cy,
    double r,
    Color color,
  ) {
    canvas.drawCircle(
      Offset(cx * s, cy * s),
      r * s,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
