import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/user_model.dart';
import 'package:wood_and_more_app/services/home_icon_order_service.dart';
import 'package:wood_and_more_app/services/icon_visibility_service.dart';

UserModel _user(String role) {
  return UserModel(
    id: 1,
    name: 'User',
    email: 'user@example.com',
    role: role,
  );
}

void main() {
  test('resolveHomeIconOrder keeps saved order for visible icons', () {
    final iconConfig = IconVisibilityService.defaultForRole('site_engineer');
    final resolved = resolveHomeIconOrder(
      user: _user('site_engineer'),
      iconConfig: iconConfig,
      savedOrder: const ['ir_mir', 'attendance', 'engineer_projects'],
    );

    expect(resolved.first, 'ir_mir');
    expect(resolved, contains('attendance'));
    expect(
      resolved.length,
      eligibleHomeIconIds(
        user: _user('site_engineer'),
        iconConfig: iconConfig,
      ).length,
    );
  });

  test('resolveHomeIconOrder appends new visible icons', () {
    final iconConfig = IconVisibilityService.defaultForRole('accountant');
    final resolved = resolveHomeIconOrder(
      user: _user('accountant'),
      iconConfig: iconConfig,
      savedOrder: const ['accountant_finance'],
    );

    expect(resolved.first, 'accountant_finance');
    expect(resolved.length, greaterThan(1));
  });

  test('general_supervisor has manager icons plus attendance', () {
    final iconConfig =
        IconVisibilityService.defaultForRole('general_supervisor');
    final eligible = eligibleHomeIconIds(
      user: _user('general_supervisor'),
      iconConfig: iconConfig,
    );

    expect(eligible.first, 'attendance');
    expect(eligible, contains('attendance_reports'));
    expect(eligible, contains('warehouses_view'));
    expect(eligible, isNot(contains('today_work_plan')));
  });

  test('resolveHomeIconOrder drops hidden icons from saved order', () {
    final iconConfig = Map<String, bool>.from(
      IconVisibilityService.defaultForRole('app_admin'),
    )..['warehouses_view'] = false;
    final resolved = resolveHomeIconOrder(
      user: _user('app_admin'),
      iconConfig: iconConfig,
      savedOrder: const ['warehouses_view', 'dashboard', 'reports'],
    );

    expect(resolved, isNot(contains('warehouses_view')));
    expect(resolved.first, 'dashboard');
    expect(resolved, contains('reports'));
  });
}
