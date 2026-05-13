/// نموذج المستخدم - مهندس موقع أو مدير المشروعات
class UserModel {
  static const String siteEngineerManagerRoleLabel = 'مدير المشروعات';

  final int id;
  final String name;
  final String email;
  final String role; // 'site_engineer' | 'site_engineer_manager' | 'operation_manager' | 'app_admin' | 'accountant'

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isSiteEngineer => role == 'site_engineer';
  bool get isManager =>
      role == 'site_engineer_manager' ||
      role == 'operation_manager' ||
      role == 'app_admin';
  bool get isAdmin => role == 'app_admin';
  bool get isAccountant => role == 'accountant';

  /// موافقة / رفض طلبات سحب الخامات (مدير المشروعات أو مدير العمليات).
  bool get canActOnWithdrawalRequests =>
      role == 'site_engineer_manager' || role == 'operation_manager';

  /// إدارة إلغاء سحب الخامات من المخزن (لوحة التحكم): مسؤول التطبيق بهذا البريد فقط.
  bool get canManageWarehouseWithdrawalReset =>
      isAdmin && email.trim().toLowerCase() == 'mouhammedhelal@gmail.com';

  /// عرض سجل حركة النظام لمسؤول التطبيق المحدد فقط.
  bool get canViewActivityLogs =>
      isAdmin && email.trim().toLowerCase() == 'mouhammedhelal@gmail.com';

  /// حذف/تعديل أي خطة عمل اليوم أو الغد (تقارير مفصّلة) — لهذا البريد فقط.
  bool get canManageAnySiteWorkPlan =>
      email.trim().toLowerCase() == 'mouhammedhelal@gmail.com';

  /// التحكم في إظهار/إخفاء أيقونات الواجهة — لهذا البريد فقط.
  bool get canManageIconsControl =>
      email.trim().toLowerCase() == 'mouhammedhelal@gmail.com';

  /// تقارير التأجيل/الغرامات: مدير العمليات، أو مسؤول التطبيق بهذا البريد فقط.
  bool get canAccessPostponeFinesReports =>
      role == 'operation_manager' ||
      (isAdmin && email.trim().toLowerCase() == 'mouhammedhelal@gmail.com');

  /// حذف مرفقات IR / MIR — مسؤول التطبيق بهذا البريد فقط.
  bool get canDeleteIrMirAttachments =>
      isAdmin && email.trim().toLowerCase() == 'mouhammedhelal@gmail.com';

  bool get canUsePrivateAdminManagerChat {
    final e = email.trim().toLowerCase();
    return e == 'islam.shams2050@gmail.com' || e == 'mouhammedhelal@gmail.com';
  }

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
