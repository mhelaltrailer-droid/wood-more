import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wood_and_more_app/models/activity_log_model.dart';
import 'package:wood_and_more_app/models/user_model.dart';
import 'package:wood_and_more_app/utils/activity_log_display.dart';

void main() {
  test('activityLogNarrative formats login line', () {
    final log = ActivityLogModel(
      id: 1,
      createdAt: DateTime(2026, 6, 29, 14, 30),
      actionType: 'login',
      actionLabel: 'تسجيل دخول',
      endpoint: '/auth/login',
      method: 'POST',
      statusCode: 200,
      details: '',
      userName: 'admin1',
      userEmail: 'admin1@example.com',
      userId: 1,
    );

    expect(
      activityLogNarrative(
        log,
        timeFormat: DateFormat('HH:mm — yyyy/MM/dd'),
      ),
      'قام admin1 بتسجيل الدخول (14:30 — 2026/06/29)',
    );
    expect(activityLogUserEmail(log), 'admin1@example.com');
  });

  test('activityLogUserName resolves from users list', () {
    final log = ActivityLogModel(
      id: 2,
      createdAt: DateTime.now(),
      actionType: 'plan_save_tomorrow',
      actionLabel: 'تسجيل خطة عمل الغد',
      endpoint: '/detailed-reports',
      method: 'POST',
      statusCode: 200,
      details: '',
      userId: 5,
    );
    const users = [
      UserModel(id: 5, name: 'emam', email: 'emam@example.com', role: 'site_engineer'),
    ];

    expect(activityLogUserName(log, users: users), 'emam');
    expect(activityLogUserEmail(log, users: users), 'emam@example.com');
    expect(activityLogActionPhrase(log), 'بتسجيل خطة عمل الغد');
  });
}
