import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/user_model.dart';
import 'package:wood_and_more_app/services/home_icon_order_service.dart';
import 'package:wood_and_more_app/services/icon_visibility_service.dart';

UserModel _adminUser() {
  return const UserModel(
    id: 1,
    name: 'Admin',
    email: 'admin@example.com',
    role: 'app_admin',
  );
}

void main() {
  test('resolveAppAdminHomeIconOrder keeps saved order for visible icons', () {
    final iconConfig = IconVisibilityService.defaultForRole('app_admin');
  final resolved = resolveAppAdminHomeIconOrder(
      user: _adminUser(),
      iconConfig: iconConfig,
      savedOrder: const [
        'warehouses_view',
        'attendance_reports',
        'dashboard',
      ],
    );

    expect(resolved.first, 'warehouses_view');
    expect(resolved, contains('attendance_reports'));
    expect(resolved, contains('dashboard'));
    expect(resolved.length, eligibleAppAdminHomeIconIds(
      user: _adminUser(),
      iconConfig: iconConfig,
    ).length);
  });

  test('resolveAppAdminHomeIconOrder appends new visible icons', () {
    final iconConfig = IconVisibilityService.defaultForRole('app_admin');
    final resolved = resolveAppAdminHomeIconOrder(
      user: _adminUser(),
      iconConfig: iconConfig,
      savedOrder: const ['dashboard'],
    );

    expect(resolved.first, 'dashboard');
    expect(resolved.length, greaterThan(1));
  });

  test('resolveAppAdminHomeIconOrder drops hidden icons from saved order', () {
    final iconConfig = Map<String, bool>.from(
      IconVisibilityService.defaultForRole('app_admin'),
    )..['warehouses_view'] = false;
    final resolved = resolveAppAdminHomeIconOrder(
      user: _adminUser(),
      iconConfig: iconConfig,
      savedOrder: const ['warehouses_view', 'dashboard', 'reports'],
    );

    expect(resolved, isNot(contains('warehouses_view')));
    expect(resolved.first, 'dashboard');
    expect(resolved, contains('reports'));
  });
}
