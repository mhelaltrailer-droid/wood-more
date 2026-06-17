/// نموذج المستخدم - مهندس موقع أو مدير المشروعات
class UserModel {
  static const String siteEngineerManagerRoleLabel = 'مدير المشروعات';
  static const String generalSupervisorRoleLabel = 'مشرف عام';
  static const String documentControllerRoleLabel = 'Document Controller';
  static const String primaryAppAdminEmail = 'mouhammedhelal@gmail.com';

  final int id;
  final String name;
  final String email;
  final String role; // 'site_engineer' | 'site_engineer_manager' | 'general_supervisor' | 'operation_manager' | 'app_admin' | 'accountant' | 'document_controller'

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isSiteEngineer => role == 'site_engineer';
  bool get isDocumentController => role == 'document_controller';
  bool get isGeneralSupervisor => role == 'general_supervisor';

  /// رفع سجلات MS-SD (Document Controller فقط).
  bool get canUploadMsSd => isDocumentController;

  /// عرض سجلات MS-SD (DC + مهندس/مدير/مشرف/عمليات).
  bool get canViewMsSd =>
      isDocumentController ||
      isSiteEngineer ||
      isManager ||
      isGeneralSupervisor;

  /// تعديل/حذف سجلات MS-SD بعد الحفظ — المسؤول المحدد فقط.
  bool get canManageMsSdRecords =>
      email.trim().toLowerCase() == primaryAppAdminEmail.toLowerCase();

  /// رفع سجلات MoS-ITP (Document Controller فقط).
  bool get canUploadMosItp => isDocumentController;

  /// عرض سجلات MoS-ITP (DC + مهندس/مدير/مشرف/عمليات).
  bool get canViewMosItp =>
      isDocumentController ||
      isSiteEngineer ||
      isManager ||
      isGeneralSupervisor;

  /// تعديل/حذف سجلات MoS-ITP بعد الحفظ — المسؤول المحدد فقط.
  bool get canManageMosItpRecords =>
      email.trim().toLowerCase() == primaryAppAdminEmail.toLowerCase();

  /// عرض مرفقات IR/MIR ووحدات المستندات (بدون رفع من مهندس الموقع).
  bool get canViewUploadedDocuments =>
      isManager || isAdmin || isDocumentController;
  bool get isManager =>
      role == 'site_engineer_manager' ||
      role == 'general_supervisor' ||
      role == 'operation_manager' ||
      role == 'app_admin';

  /// زر الإشعارات في الشاشة الرئيسية (بدون طلبات السحب لـ مشرف عام).
  bool get canUseNotifications =>
      role == 'site_engineer' ||
      role == 'site_engineer_manager' ||
      role == 'general_supervisor' ||
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

  /// أيقونة Reports-SYS في الواجهة الرئيسية — كل المشاركين (ما عدا المحاسب).
  bool get canAccessReportsSysHomeIcon => canParticipateInReportsSys;

  /// المشاركة في تداول Reports-SYS (استلام وتوجيه عبر الإشعارات).
  bool get canParticipateInReportsSys => !isAccountant;

  /// عرض النظام كاملاً: أرشيف + كل المرفوضة + تبويب «الكل».
  bool get canViewReportsSysFullAccess =>
      role == 'app_admin' ||
      role == 'operation_manager' ||
      role == 'site_engineer_manager' ||
      role == 'general_supervisor' ||
      role == 'document_controller';

  /// أرشفة تقارير Reports-SYS — نفس أدوار العرض الكامل.
  bool get canArchiveReportsSys => canViewReportsSysFullAccess;

  bool get canViewReportsSysArchiveTab => canViewReportsSysFullAccess;

  bool get canViewReportsSysAllTab => canViewReportsSysFullAccess;

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
