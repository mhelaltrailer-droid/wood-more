/// نموذج المستخدم - مهندس موقع أو مدير مهندسين
class UserModel {
  final int id;
  final String name;
  final String email;
  final String role; // 'site_engineer' | 'site_engineer_manager' | 'app_admin' | 'accountant'

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isSiteEngineer => role == 'site_engineer';
  bool get isManager => role == 'site_engineer_manager' || role == 'app_admin';
  bool get isAdmin => role == 'app_admin';
  bool get isAccountant => role == 'accountant';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int,
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
    );
  }
}
