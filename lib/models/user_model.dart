import '../core/shop_drawing_constants.dart';
import 'expense_statement_model.dart';

/// نموذج المستخدم - مهندس موقع أو مدير المشروعات أو Projects Manager
class UserModel {
  static const String siteEngineerManagerRoleLabel = 'مدير المشروعات';
  static const String projectsManagerRoleLabel = 'Projects Manager';
  static const String generalSupervisorRoleLabel = 'مشرف عام';
  static const String documentControllerRoleLabel = 'Document Controller';
  static const String technicalOfficeRoleLabel = 'المكتب الفني';
  static const String topManagementRoleLabel = 'Top Managment';
  static const String opCoordinatorRoleLabel = 'Op-Coordinator';
  static const String primaryAppAdminEmail = 'mouhammedhelal@gmail.com';

  /// قيمة الدور في قاعدة البيانات.
  static const String roleProjectsManager = 'projects_manager';

  final int id;
  final String name;
  final String email;
  final String role; // incl. projects_manager

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
  bool get isOpCoordinator => role == 'op_coordinator';
  bool get isSiteEngineerManager => role == 'site_engineer_manager';
  bool get isProjectsManager => role == roleProjectsManager;

  /// حالياً نفس صلاحيات مدير المشروعات — للتوسعة لاحقاً على Projects Manager فقط.
  bool get hasSiteEngineerManagerPrivileges =>
      isSiteEngineerManager || isProjectsManager;

  /// أيقونة Meetings + جرس إشعارات الاجتماعات في الشاشة الرئيسية.
  /// للأدمن: المسؤول الرئيسي فقط (mouhammedhelal@gmail.com).
  bool get canAccessMeetings =>
      isOpCoordinator ||
      isOperationManager ||
      hasSiteEngineerManagerPrivileges ||
      isTechnicalOffice ||
      isPrimaryAppAdmin;

  bool get canUseMeetingsNotification => canAccessMeetings;

  /// إنشاء/رفع/استبدال ملفات الاجتماعات — Op-Coordinator فقط.
  bool get canUploadMeetings => isOpCoordinator;

  /// حذف ملف أو اجتماع بالكامل — المسؤول الرئيسي فقط.
  bool get canDeleteMeetings => isPrimaryAppAdmin;
  /// مدير مشروعات Shop-Drawing: البريد المحدد، أو دور Projects Manager بالكامل.
  bool get isShopDrawingProjectManager =>
      isProjectsManager ||
      (isSiteEngineerManager && isShopDrawingPmEmail(email));

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

  /// رفع مرفقات IR / MIR (مهندس موقع أو Document Controller).
  bool get canUploadIrMir => isSiteEngineer || isDocumentController;

  /// عرض مرفقات IR/MIR ووحدات المستندات (بدون رفع من مهندس الموقع).
  bool get canViewUploadedDocuments =>
      isManager || isAdmin || isDocumentController;
  bool get isManager =>
      hasSiteEngineerManagerPrivileges ||
      role == 'general_supervisor' ||
      role == 'operation_manager' ||
      role == 'app_admin';

  /// زر الإشعارات في الشاشة الرئيسية (بدون طلبات السحب لـ مشرف عام).
  bool get canUseNotifications =>
      role == 'site_engineer' ||
      hasSiteEngineerManagerPrivileges ||
      role == 'general_supervisor' ||
      role == 'operation_manager' ||
      role == 'app_admin';
  bool get isAdmin => role == 'app_admin';
  bool get isAccountant => role == 'accountant';

  /// إدارة أرصدة المستخدمين (إضافة/سحب) — المحاسب ومدير المشروعات.
  bool get canManageUserBalances =>
      isAccountant || hasSiteEngineerManagerPrivileges;

  /// موافقة / رفض طلبات سحب الخامات (مدير المشروعات أو مدير العمليات).
  bool get canActOnWithdrawalRequests =>
      hasSiteEngineerManagerPrivileges || role == 'operation_manager';

  /// رفع نسخ التطبيق (APK) وإدارة الإصدارات — البريد الأساسي فقط.
  bool get canManageAppVersions =>
      email.trim().toLowerCase() == primaryAppAdminEmail.toLowerCase();

  /// عرض أيقونة Versions — مؤقتاً لدور app_admin فقط (مخفية عن باقي الأدوار).
  bool get canViewAppVersionsIcon => isAdmin;

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

  /// اعتماد/رفض بيانات صرف مهندسي المواقع — البريد المحدد فقط.
  bool get canApproveExpenseStatements =>
      email.trim().toLowerCase() == ExpenseStatementModel.approverEmail;

  /// الاطلاع على بيانات الصرف المعتمدة/المرفوضة (مدير العمليات + المسؤول الأساسي).
  bool get canViewCustodyExpensesArchive =>
      isOperationManager || isPrimaryAppAdmin;

  /// حذف أي بيان صرف — المسؤول الأساسي فقط.
  bool get canDeleteExpenseStatements => isPrimaryAppAdmin;

  /// أيقونة Reports-SYS في الواجهة الرئيسية.
  bool get canAccessReportsSysHomeIcon => canParticipateInReportsSys;

  /// المشاركة في تداول Reports-SYS (استلام وتوجيه عبر الإشعارات).
  bool get canParticipateInReportsSys => true;

  /// عرض النظام كاملاً: أرشيف + كل المرفوضة + تبويب «الكل».
  bool get canViewReportsSysFullAccess =>
      role == 'app_admin' ||
      role == 'operation_manager' ||
      hasSiteEngineerManagerPrivileges ||
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

  bool get isPrimaryAppAdmin =>
      email.trim().toLowerCase() == primaryAppAdminEmail.toLowerCase();

  /// Projects Dashboard — المكتب الفني، مدير العمليات، والمسؤول الأساسي.
  bool get canAccessProjectsDashboard =>
      isTechnicalOffice || isOperationManager || isPrimaryAppAdmin;

  bool get canEditProjectsDashboardSheet => canAccessProjectsDashboard;

  bool get canUploadProjectsDashboardInitial => isTechnicalOffice;

  bool get canDeleteProjectsDashboardNotes =>
      isAdmin && isPrimaryAppAdmin;

  /// ملاحظات الطرف الآخر في Projects Dashboard.
  String get projectsDashboardPeerNotesRole {
    if (isTechnicalOffice) return 'operation_manager';
    if (isOperationManager || isPrimaryAppAdmin) return 'technical_office';
    return '';
  }

  /// عرض جميع الملاحظات (الطرفين) — المسؤول الأساسي فقط.
  bool get canViewAllProjectsDashboardNotes => isPrimaryAppAdmin;

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
