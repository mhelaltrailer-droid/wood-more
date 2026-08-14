import 'package:flutter/material.dart';

import 'meetings_icon.dart';

/// رمز إشعارات الاجتماعات في شريط التطبيق (طاولة اجتماعات + أشخاص).
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
    return MeetingsIcon(size: size, color: color);
  }
}
