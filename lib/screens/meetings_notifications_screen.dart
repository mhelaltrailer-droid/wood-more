import 'package:flutter/material.dart';

import '../widgets/meetings_notification_app_bar_icon.dart';

/// إشعارات الاجتماعات — واجهة فقط في هذه المرحلة.
class MeetingsNotificationsScreen extends StatelessWidget {
  const MeetingsNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MeetingsNotificationAppBarIcon(size: 22),
            SizedBox(width: 10),
            Text('إشعارات الاجتماعات'),
          ],
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لم يكتمل جاري العمل عليها',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1B5E20),
            ),
          ),
        ),
      ),
    );
  }
}
