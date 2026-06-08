import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/user_model.dart';

void main() {
  test('UserModel role flags', () {
    const engineer = UserModel(
      id: 1,
      name: 'Engineer',
      email: 'e@example.com',
      role: 'site_engineer',
    );
    const admin = UserModel(
      id: 2,
      name: 'Admin',
      email: 'a@example.com',
      role: 'app_admin',
    );

    expect(engineer.isSiteEngineer, isTrue);
    expect(engineer.canUseNotifications, isFalse);
    expect(admin.isAdmin, isTrue);
    expect(admin.canUseNotifications, isTrue);
  });
}
