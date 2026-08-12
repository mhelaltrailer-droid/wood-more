import 'package:flutter/material.dart';

/// رمز إشعارات الاجتماعات في شريط التطبيق (شكل تقويم + أشخاص).
class MeetingsNotificationAppBarIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MeetingsNotificationAppBarIcon({
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
        painter: _MeetingsNotificationPainter(color: color),
      ),
    );
  }
}

class _MeetingsNotificationPainter extends CustomPainter {
  final Color color;

  _MeetingsNotificationPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // جسم التقويم
    final cal = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.22, w * 0.76, h * 0.66),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(cal, stroke);

    // شريط أعلى التقويم
    canvas.drawLine(
      Offset(w * 0.12, h * 0.38),
      Offset(w * 0.88, h * 0.38),
      stroke,
    );

    // حلقات التعليق
    canvas.drawLine(
      Offset(w * 0.32, h * 0.12),
      Offset(w * 0.32, h * 0.28),
      stroke,
    );
    canvas.drawLine(
      Offset(w * 0.68, h * 0.12),
      Offset(w * 0.68, h * 0.28),
      stroke,
    );

    // رأس شخص
    canvas.drawCircle(Offset(w * 0.42, h * 0.55), w * 0.07, fill);
    // كتف/جسم
    final body = Path()
      ..moveTo(w * 0.28, h * 0.78)
      ..quadraticBezierTo(w * 0.42, h * 0.62, w * 0.56, h * 0.78);
    canvas.drawPath(body, stroke);

    // رأس شخص ثانٍ أصغر
    canvas.drawCircle(Offset(w * 0.66, h * 0.58), w * 0.055, fill);
    final body2 = Path()
      ..moveTo(w * 0.54, h * 0.78)
      ..quadraticBezierTo(w * 0.66, h * 0.66, w * 0.78, h * 0.78);
    canvas.drawPath(body2, stroke);
  }

  @override
  bool shouldRepaint(covariant _MeetingsNotificationPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
