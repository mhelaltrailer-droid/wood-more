import '../core/shop_drawing_constants.dart';

/// نموذج المستخدم - مهندس موقع أو مدير المشروعات
class UserModel {  static const String siteEngineerManagerRoleLabel = 'مدير المشروعات';
  static const String generalSupervisorRoleLabel = 'مشرف عام';
  static const String documentControllerRoleLabel = 'Document Controller';
  static const String technicalOfficeRoleLabel = 'المكتب الفني';
  static const String topManagementRoleLabel = 'Top Managment';
  static const String primaryAppAdminEmail = 'mouhammedhelal@gmail.com';

  final int id;
  final String name;
  final String email;
  final String role; // 'site_engineer' | 'site_engineer_manager' | 'general_supervisor' | 'operation_manager' | 'app_admin' | 'accountant' | 'document_controller' | 'technical_office' | 'top_management'

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isSiteEngineer => role == 'site_engineer';
  bool get isDocumentController => role == 'document_controller';
  bool get isGeneralSupervisor => role == 'general_supervisor';
  bool get isTechnicalOffice => role == shopDrawingRoleTechnicalOffice;
  bool get isTopManagement => role == shopDrawingRoleTopManagement;
  bool get isOperationManager => role == 'operation_manager';
  bool get isShopDrawingProjectManager =>
      role == 'site_engineer_manager' && isShopDrawingPmEmail(email);

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

  /// إدارة أرصدة المستخدمين (إضافة/سحب) — المحاسب ومدير المشروعات.
  bool get canManageUserBalances =>
      isAccountant || role == 'site_engineer_manager';

  /// موافقة / رفض طلبات سحب الخامات (مدير المشروعات أو مدير العمليات).
  bool get canActOnWithdrawalRequests =>
      role == 'site_engineer_manager' || role == 'operation_manager';

  /// رفع نسخ التطبيق (APK) وإدارة الإصدارات — البريد الأساسي فقط.
  bool get canManageAppVersions =>
      email.trim().toLowerCase() == primaryAppAdminEmail.toLowerCase();

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

  /// تقرير بنود صرف العهدة/المصروفات + حذف البنود — مسؤول التطبيق بهذا البريد فقط.
  bool get canManageSiteEngineerExpensesReport =>
      isAdmin && email.trim().toLowerCase() == primaryAppAdminEmail.toLowerCase();

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

  /// أيقونة Shop-drawing في الشاشة الرئيسية.
  bool get canAccessShopDrawingHomeIcon =>
      isTechnicalOffice ||
      isTopManagement ||
      isShopDrawingProjectManager ||
      isOperationManager ||
      canManageShopDrawingApproved;

  /// إجراءات مدير المشروعات في Shop-drawing.
  bool get canActAsShopDrawingProjectManager => isShopDrawingProjectManager;

  /// اعتماد نهائي من مدير العمليات.
  bool get canApproveShopDrawingAsOm => isOperationManager;

  /// عرض Shop-Drawing & PO للقراءة فقط (Top Management).
  bool get canViewShopDrawingReadOnly => isTopManagement;

  /// إدارة Shop-Drawing & PO (حذف بأي مرحلة، عرض كامل…) — مسؤول التطبيق المحدد فقط.
  bool get canManageShopDrawingApproved =>
      email.trim().toLowerCase() == primaryAppAdminEmail.toLowerCase();

  /// جرس shop-darwing-notification في الشاشة الرئيسية (مدير العمليات + المسؤول).
  bool get canUseShopDarwingNotification =>
      isOperationManager || canManageShopDrawingApproved;

  /// إشعارات داخل أيقونة Shop-drawing (مكتب فني + مدير المشروعات المحدد).
  bool get canSeeShopDrawingModuleNotifications =>
      isTechnicalOffice || isShopDrawingProjectManager;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    int parseId(dynamic v) => v is int ? v : int.parse(v.toString());
    return UserModel(
      id: parseId(map['id']),
      name: (map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      role: (map['role'] ?? 'site_engineer').toString(),
    );
  }
}
