import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_and_more_app/services/web_storage_service.dart';

Map<String, dynamic> _notif(int id, int recipient) => {
      'id': id,
      'recipient_user_id': recipient,
      'title': 'SD — طلب جديد',
      'body': 'body $id',
      'shop_drawing_id': id * 10,
      'created_at': DateTime(2026, 1, id).toIso8601String(),
      'is_read': 0,
      'read_at': null,
    };

void main() {
  group('WebStorageService.deleteShopDarwingNotification', () {
    late WebStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'wood_shop_darwing_notifications': jsonEncode([
          _notif(1, 100),
          _notif(2, 100),
          _notif(3, 200),
        ]),
      });
      storage = WebStorageService();
    });

    test('حذف إشعار المستخدم يزيل نسخته فقط', () async {
      var mine = await storage.getShopDarwingNotifications(100);
      expect(mine.map((n) => n.id), containsAll([1, 2]));

      await storage.deleteShopDarwingNotification(
        notificationId: 1,
        userId: 100,
      );

      mine = await storage.getShopDarwingNotifications(100);
      expect(mine.map((n) => n.id).toList(), [2]);

      final other = await storage.getShopDarwingNotifications(200);
      expect(other.map((n) => n.id).toList(), [3]);
    });

    test('لا يمكن حذف إشعار مستخدم آخر', () async {
      await storage.deleteShopDarwingNotification(
        notificationId: 3,
        userId: 100,
      );

      final other = await storage.getShopDarwingNotifications(200);
      expect(other.map((n) => n.id).toList(), [3],
          reason: 'notification of user 200 must remain');
    });

    test('العداد يتحدث بعد الحذف', () async {
      expect(await storage.getUnreadShopDarwingNotificationsCount(100), 2);
      await storage.deleteShopDarwingNotification(
        notificationId: 2,
        userId: 100,
      );
      expect(await storage.getUnreadShopDarwingNotificationsCount(100), 1);
    });
  });
}
