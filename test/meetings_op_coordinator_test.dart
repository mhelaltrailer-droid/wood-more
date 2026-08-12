import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/user_model.dart';
import 'package:wood_and_more_app/services/home_icon_order_service.dart';
import 'package:wood_and_more_app/services/icon_visibility_service.dart';

UserModel _user(String role) => UserModel(
      id: 1,
      name: 'T',
      email: 't@example.com',
      role: role,
    );

void main() {
  test('op_coordinator has Meetings only + notification capability', () {
    final user = _user('op_coordinator');
    expect(user.isOpCoordinator, isTrue);
    expect(user.canAccessMeetings, isTrue);
    expect(user.canUseMeetingsNotification, isTrue);

    final eligible = eligibleHomeIconIds(
      user: user,
      iconConfig: IconVisibilityService.defaultForRole('op_coordinator'),
    );
    expect(eligible, ['meetings']);
  });

  test('meetings icon and notification for target roles', () {
    for (final role in [
      'operation_manager',
      'site_engineer_manager',
      'app_admin',
      'technical_office',
      'op_coordinator',
    ]) {
      final user = _user(role);
      expect(user.canAccessMeetings, isTrue, reason: role);
      expect(user.canUseMeetingsNotification, isTrue, reason: role);
      final eligible = eligibleHomeIconIds(
        user: user,
        iconConfig: IconVisibilityService.defaultForRole(role),
      );
      expect(eligible, contains('meetings'), reason: role);
    }
  });

  test('op_coordinator is registered in icon visibility roles', () {
    expect(
      IconVisibilityService.roleIcons.containsKey('op_coordinator'),
      isTrue,
    );
    expect(
      IconVisibilityService.roleTitles['op_coordinator'],
      'Op-Coordinator',
    );
  });
}
