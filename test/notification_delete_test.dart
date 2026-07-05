import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_and_more_app/services/web_storage_service.dart';

Map<String, dynamic> _generalNotif(int id, int recipient) => {
      'id': id,
      'recipient_user_id': recipient,
      'recipient_role': 'site_engineer',
      'title': 'إشعار $id',
      'body': 'body $id',
      'event_type': 'test_$id',
      'actor_user_id': null,
      'actor_user_name': null,
      'project_name': null,
      'created_at': DateTime(2026, 1, id).toIso8601String(),
      'is_read': 0,
      'read_at': null,
    };

void main() {
  group('WebStorageService.deleteNotification', () {
    late WebStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'wood_notifications': jsonEncode([
          _generalNotif(1, 100),
          _generalNotif(2, 100),
          _generalNotif(3, 200),
        ]),
      });
      storage = WebStorageService();
    });

    test('حذف إشعار المستخدم يزيل نسخته فقط', () async {
      await storage.deleteNotification(notificationId: 1, userId: 100);
      final mine = await storage.getNotificationsForUser(100);
      expect(mine.map((n) => n.id).toList(), [2]);
      final other = await storage.getNotificationsForUser(200);
      expect(other.map((n) => n.id).toList(), [3]);
    });

    test('العداد يتحدث بعد الحذف', () async {
      expect(await storage.getUnreadNotificationsCount(100), 2);
      await storage.deleteNotification(notificationId: 2, userId: 100);
      expect(await storage.getUnreadNotificationsCount(100), 1);
    });
  });
}
