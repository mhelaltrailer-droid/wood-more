import 'dart:math' as math;
import 'package:flutter/material.dart';

/// أيقونة shop-darwing-notification — شكل هندسي لشريط التطبيق.
class ShopDarwingNotificationAppBarIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ShopDarwingNotificationAppBarIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShopDarwingNotificationGeometricPainter(color: color),
      ),
    );
  }
}

class _ShopDarwingNotificationGeometricPainter extends CustomPainter {
  final Color color;

  _ShopDarwingNotificationGeometricPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;

    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 2;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();
    canvas.drawPath(hex, stroke);

    final innerR = r * 0.42;
    final diamond = Path()
      ..moveTo(cx, cy - innerR)
      ..lineTo(cx + innerR, cy)
      ..lineTo(cx, cy + innerR)
      ..lineTo(cx - innerR, cy)
      ..close();
    canvas.drawPath(diamond, fill);

    final dotR = size.width * 0.055;
    canvas.drawCircle(Offset(cx + r * 0.55, cy - r * 0.55), dotR, fill);
  }

  @override
  bool shouldRepaint(
    covariant _ShopDarwingNotificationGeometricPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}
