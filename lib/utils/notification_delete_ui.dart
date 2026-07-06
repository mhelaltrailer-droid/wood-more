import 'package:flutter/material.dart';

/// رسالة عند محاولة حذف إشعار طلب سحب قبل اتخاذ إجراء.
const String withdrawalNotificationDeleteBlockedMessage =
    'لا يمكن حذف الإشعار قبل اتخاذ إجراء على الطلب (موافقة أو رفض)';

/// تأكيد حذف إشعار فردي (مشترك بين كل شاشات الإشعارات).
Future<bool> confirmDeleteNotification(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف الإشعار'),
      content: const Text('هل تريد حذف هذا الإشعار من قائمتك؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Widget notificationDismissDeleteBackground(Alignment alignment) {
  return Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.red.shade600,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.delete_outline, color: Colors.white),
  );
}
