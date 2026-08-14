import 'package:flutter/material.dart';

/// أيقونة Meetings — طاولة اجتماعات + 4 أشخاص (من الأيقونة المرفقة).
class MeetingsIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MeetingsIcon({
    super.key,
    this.size = 64,
    this.color = const Color(0xFF1B5E20),
  });

  static const String _asset = 'assets/images/meetings_icon.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
      ),
    );
  }
}
