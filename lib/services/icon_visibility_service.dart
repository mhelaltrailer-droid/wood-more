import '../core/shop_drawing_constants.dart';

class HomeIconItem {
  final String id;
  final String label;

  const HomeIconItem({required this.id, required this.label});
}

class IconVisibilityService {
  static const String roleAppAdmin = 'app_admin';
  static const String roleSiteEngineer = 'site_engineer';
  static const String roleSiteEngineerManager = 'site_engineer_manager';
  static const String roleProjectsManager = 'projects_manager';
  static const String roleGeneralSupervisor = 'general_supervisor';
  static const String roleOperationManager = 'operation_manager';
  static const String roleAccountant = 'accountant';
  static const String roleDocumentController = 'document_controller';
  static const String roleTechnicalOffice = 'technical_office';
  static const String roleTopManagement = 'top_management';
  static const String roleOpCoordinator = 'op_coordinator';

  static const HomeIconItem meetingsIcon = HomeIconItem(
    id: 'meetings',
    label: 'Meetings',
  );

  static const List<HomeIconItem> _shopDrawingOnlyHomeIcons = [
    HomeIconItem(id: 'shop_drawing', label: shopDrawingHomeIconLabel),
  ];

  static const HomeIconItem documentControlIcon = HomeIconItem(
    id: 'document_control',
    label: 'Document Control',
  );

  /// الأيقونات داخل محور Document Control (بترتيب العرض).
  static const List<HomeIconItem> documentControlChildIcons = [
    HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
    HomeIconItem(id: 'ms_sd', label: 'MS-SD'),
    HomeIconItem(id: 'qs_invs', label: 'QS-INV(s)'),
    HomeIconItem(id: 'mos_itp', label: 'MoS-ITP'),
  ];

  static const List<String> _docControlChildrenDefault = [
    'ir_mir',
    'ms_sd',
    'qs_invs',
    'mos_itp',
  ];

  static const List<String> _docControlChildrenWithoutQs = [
    'ir_mir',
    'ms_sd',
    'mos_itp',
  ];

  /// الأيقونات الفرعية الظاهرة داخل Document Control حسب الدور.
  static List<String> documentControlChildrenForRole(String role) {
    switch (role) {
      case roleSiteEngineer:
      case roleSiteEngineerManager:
      case roleProjectsManager:
      case roleGeneralSupervisor:
        return _docControlChildrenWithoutQs;
      case roleDocumentController:
      case roleOperationManager:
      case roleAppAdmin:
        return _docControlChildrenDefault;
      default:
        return const [];
    }
  }

  static const List<HomeIconItem> _documentControllerHomeIcons = [
    documentControlIcon,
    HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
    HomeIconItem(id: 'admin_dashboard', label: 'لوح التحكم'),
    HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
  ];

  static const HomeIconItem balancesExpensesIcon = HomeIconItem(
    id: 'accountant_finance',
    label: 'الأرصدة / المصروفات',
  );

  static const HomeIconItem managerCustodyExpensesIcon = HomeIconItem(
    id: 'manager_custody_expenses',
    label: 'العهد/تقارير المصروفات',
  );

  static const HomeIconItem custodyExpensesViewIcon = HomeIconItem(
    id: 'custody_expenses_view',
    label: 'العهده/ المصروفات',
  );

  static const HomeIconItem operationManagerCustodyBalancesExpensesIcon =
      HomeIconItem(
        id: 'operation_manager_custody_balances_expenses',
        label: 'العهد/الارصدة/المصروفات',
      );

  static const HomeIconItem withdrawalFilesReportsIcon = HomeIconItem(
    id: 'withdrawal_files_reports',
    label: 'تقارير السحب والمرفقات',
  );

  static const List<HomeIconItem> _projectManagerHomeIcons = [
    HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
    HomeIconItem(
      id: 'work_plan_tracking_report',
      label: 'تقارير متابعة خطط اليوم/الغد',
    ),
    HomeIconItem(id: 'new_icon', label: 'Control'),
    HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
    documentControlIcon,
    HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
    HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
  ];

  static const Map<String, String> roleTitles = {
    roleAppAdmin: 'App admin',
    roleSiteEngineer: 'Site engineer',
    roleSiteEngineerManager: 'مدير المشروعات',
    roleProjectsManager: 'Projects Manager',
    roleGeneralSupervisor: 'مشرف عام',
    roleOperationManager: 'Operation manager',
    roleAccountant: 'Accountant',
    roleDocumentController: 'Document Controller',
    roleTechnicalOffice: 'المكتب الفني',
    roleTopManagement: 'Top Managment',
    roleOpCoordinator: 'Op-Coordinator',
  };

  static const Map<String, List<HomeIconItem>> roleIcons = {
    roleOpCoordinator: [
      meetingsIcon,
    ],
    roleTechnicalOffice: [
      ..._shopDrawingOnlyHomeIcons,
      HomeIconItem(id: 'projects_dashboard', label: 'Projects Dashboard'),
      HomeIconItem(id: 'projects_dashboard_plus1', label: 'Projects Dashboard +1'),
      meetingsIcon,
    ],
    roleTopManagement: _shopDrawingOnlyHomeIcons,
    roleSiteEngineer: [
      HomeIconItem(id: 'attendance', label: 'تسجيل الحضور والانصراف'),
      HomeIconItem(id: 'today_work_plan', label: 'خطة عمل اليوم'),
      HomeIconItem(id: 'tomorrow_work_plan', label: 'خطة عمل الغد'),
      HomeIconItem(
        id: 'engineer_withdraw_materials',
        label: 'المخزن (سحب الخامات)',
      ),
      HomeIconItem(id: 'engineer_finances', label: 'العهدة/المصروفات'),
      HomeIconItem(id: 'operation_reports', label: 'تقارير التشغيل'),
      HomeIconItem(id: 'detailed_report', label: 'التقرير اليومي'),
      HomeIconItem(id: 'engineer_projects', label: 'المشروعات'),
      documentControlIcon,
      HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
    ],
    roleAccountant: [
      HomeIconItem(id: 'accountant_custody', label: 'العهدة'),
      balancesExpensesIcon,
      HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
    ],
    roleDocumentController: _documentControllerHomeIcons,
    roleSiteEngineerManager: [
      ..._projectManagerHomeIcons,
      HomeIconItem(id: 'weekly_report', label: 'التقرير الاسبوعي'),
      managerCustodyExpensesIcon,
      HomeIconItem(id: 'shop_drawing', label: shopDrawingHomeIconLabel),
      meetingsIcon,
    ],
    roleProjectsManager: [
      ..._projectManagerHomeIcons,
      HomeIconItem(id: 'weekly_report', label: 'التقرير الاسبوعي'),
      managerCustodyExpensesIcon,
      HomeIconItem(id: 'shop_drawing', label: shopDrawingHomeIconLabel),
      meetingsIcon,
    ],
    roleGeneralSupervisor: [
      HomeIconItem(id: 'attendance', label: 'تسجيل الحضور والانصراف'),
      HomeIconItem(id: 'today_work_plan', label: 'خطة عمل اليوم'),
      HomeIconItem(id: 'tomorrow_work_plan', label: 'خطة عمل الغد'),
      HomeIconItem(id: 'engineer_finances', label: 'العهدة/المصروفات'),
      ..._projectManagerHomeIcons,
    ],
    roleOperationManager: [
      HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
      HomeIconItem(
        id: 'work_plan_tracking_report',
        label: 'تقارير متابعة خطط اليوم/الغد',
      ),
      HomeIconItem(id: 'weekly_report', label: 'التقرير الاسبوعي'),
      HomeIconItem(
        id: 'postpone_fines_reports',
        label: 'تقارير التأجيل/الغرامات',
      ),
      HomeIconItem(id: 'new_icon', label: 'Control'),
      HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
      documentControlIcon,
      HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
      HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
      HomeIconItem(id: 'shop_drawing', label: shopDrawingHomeIconLabel),
      HomeIconItem(id: 'projects_dashboard', label: 'Projects Dashboard'),
      HomeIconItem(id: 'projects_dashboard_plus1', label: 'Projects Dashboard +1'),
      operationManagerCustodyBalancesExpensesIcon,
      meetingsIcon,
    ],
    roleAppAdmin: [
      HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
      HomeIconItem(
        id: 'work_plan_tracking_report',
        label: 'تقارير متابعة خطط اليوم/الغد',
      ),
      HomeIconItem(id: 'weekly_report', label: 'التقرير الاسبوعي'),
      HomeIconItem(
        id: 'postpone_fines_reports',
        label: 'تقارير التأجيل/الغرامات',
      ),
      HomeIconItem(id: 'new_icon', label: 'Control'),
      HomeIconItem(id: 'reports', label: 'التقارير'),
      HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
      withdrawalFilesReportsIcon,
      documentControlIcon,
      HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
      HomeIconItem(id: 'admin_project_structure', label: 'هيكلة المشروعات'),
      HomeIconItem(id: 'admin_dashboard', label: 'لوح التحكم'),
      HomeIconItem(id: 'activity_logs', label: 'سجل الحركة'),
      HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
      HomeIconItem(id: 'projects_dashboard', label: 'Projects Dashboard'),
      HomeIconItem(id: 'projects_dashboard_plus1', label: 'Projects Dashboard +1'),
      meetingsIcon,
    ],
  };

  static Map<String, bool> defaultForRole(String role) {
    final items = roleIcons[role] ?? const <HomeIconItem>[];
    return {for (final item in items) item.id: true};
  }

  static bool isVisible(Map<String, bool>? roleConfig, String iconId) {
    if (roleConfig == null) return true;
    return roleConfig[iconId] ?? true;
  }

  static Map<String, Map<String, bool>> normalizeAllConfig(
    Map<String, dynamic>? raw,
  ) {
    final output = <String, Map<String, bool>>{};
    for (final role in roleIcons.keys) {
      final dynamicRole = raw?[role];
      final roleMap = <String, bool>{};
      if (dynamicRole is Map) {
        dynamicRole.forEach((key, value) {
          roleMap[key.toString()] = value == true;
        });
      }
      final defaults = defaultForRole(role);
      for (final entry in defaults.entries) {
        roleMap.putIfAbsent(entry.key, () => entry.value);
      }
      output[role] = roleMap;
    }
    return output;
  }
}
