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
  static const String roleGeneralSupervisor = 'general_supervisor';
  static const String roleOperationManager = 'operation_manager';
  static const String roleAccountant = 'accountant';
  static const String roleDocumentController = 'document_controller';
  static const String roleTechnicalOffice = 'technical_office';
  static const String roleTopManagement = 'top_management';

  static const List<HomeIconItem> _shopDrawingOnlyHomeIcons = [
    HomeIconItem(id: 'shop_drawing', label: shopDrawingHomeIconLabel),
  ];

  static const List<HomeIconItem> _documentControllerHomeIcons = [
    HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
    HomeIconItem(id: 'ms_sd', label: 'MS-SD'),
    HomeIconItem(id: 'qs_invs', label: 'QS-INV(s)'),
    HomeIconItem(id: 'mos_itp', label: 'MoS-ITP'),
    HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
    HomeIconItem(id: 'admin_dashboard', label: 'لوح التحكم'),
    HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
  ];

  static const HomeIconItem balancesExpensesIcon = HomeIconItem(
    id: 'accountant_finance',
    label: 'الأرصدة / المصروفات',
  );

  static const List<HomeIconItem> _projectManagerHomeIcons = [
    HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
    HomeIconItem(
      id: 'work_plan_tracking_report',
      label: 'تقارير متابعة خطط اليوم/الغد',
    ),
    HomeIconItem(id: 'new_icon', label: 'New icon'),
    HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
    HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
    HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
    HomeIconItem(id: 'ms_sd', label: 'MS-SD'),
    HomeIconItem(id: 'mos_itp', label: 'MoS-ITP'),
    HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
  ];

  static const Map<String, String> roleTitles = {
    roleAppAdmin: 'App admin',
    roleSiteEngineer: 'Site engineer',
    roleSiteEngineerManager: 'مدير المشروعات',
    roleGeneralSupervisor: 'مشرف عام',
    roleOperationManager: 'Operation manager',
    roleAccountant: 'Accountant',
    roleDocumentController: 'Document Controller',
    roleTechnicalOffice: 'المكتب الفني',
    roleTopManagement: 'Top Managment',
  };

  static const Map<String, List<HomeIconItem>> roleIcons = {
    roleTechnicalOffice: [
      ..._shopDrawingOnlyHomeIcons,
      HomeIconItem(id: 'projects_dashboard', label: 'Projects Dashboard'),
      HomeIconItem(id: 'projects_dashboard_plus1', label: 'Projects Dashboard +1'),
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
      HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
      HomeIconItem(id: 'ms_sd', label: 'MS-SD'),
      HomeIconItem(id: 'mos_itp', label: 'MoS-ITP'),
      HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
    ],
    roleAccountant: [
      HomeIconItem(id: 'accountant_custody', label: 'العهدة'),
      balancesExpensesIcon,
    ],
    roleDocumentController: _documentControllerHomeIcons,
    roleSiteEngineerManager: [
      ..._projectManagerHomeIcons,
      balancesExpensesIcon,
    ],
    roleGeneralSupervisor: [
      HomeIconItem(id: 'attendance', label: 'تسجيل الحضور والانصراف'),
      HomeIconItem(id: 'engineer_finances', label: 'العهدة/المصروفات'),
      ..._projectManagerHomeIcons,
    ],
    roleOperationManager: [
      HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
      HomeIconItem(
        id: 'work_plan_tracking_report',
        label: 'تقارير متابعة خطط اليوم/الغد',
      ),
      HomeIconItem(
        id: 'postpone_fines_reports',
        label: 'تقارير التأجيل/الغرامات',
      ),
      HomeIconItem(id: 'new_icon', label: 'New icon'),
      HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
      HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
      HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
      HomeIconItem(id: 'ms_sd', label: 'MS-SD'),
      HomeIconItem(id: 'qs_invs', label: 'QS-INV(s)'),
      HomeIconItem(id: 'mos_itp', label: 'MoS-ITP'),
      HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
      HomeIconItem(id: 'shop_drawing', label: shopDrawingHomeIconLabel),
      HomeIconItem(id: 'projects_dashboard', label: 'Projects Dashboard'),
      HomeIconItem(id: 'projects_dashboard_plus1', label: 'Projects Dashboard +1'),
    ],
    roleAppAdmin: [
      HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
      HomeIconItem(
        id: 'work_plan_tracking_report',
        label: 'تقارير متابعة خطط اليوم/الغد',
      ),
      HomeIconItem(
        id: 'postpone_fines_reports',
        label: 'تقارير التأجيل/الغرامات',
      ),
      HomeIconItem(id: 'new_icon', label: 'New icon'),
      HomeIconItem(id: 'reports', label: 'التقارير'),
      HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
      HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
      HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
      HomeIconItem(id: 'admin_project_structure', label: 'هيكلة المشروعات'),
      HomeIconItem(id: 'admin_dashboard', label: 'لوح التحكم'),
      HomeIconItem(id: 'activity_logs', label: 'سجل الحركة'),
      HomeIconItem(id: 'ms_sd', label: 'MS-SD'),
      HomeIconItem(id: 'qs_invs', label: 'QS-INV(s)'),
      HomeIconItem(id: 'mos_itp', label: 'MoS-ITP'),
      HomeIconItem(id: 'reports_sys', label: 'Reports -SYS'),
      HomeIconItem(id: 'projects_dashboard', label: 'Projects Dashboard'),
      HomeIconItem(id: 'projects_dashboard_plus1', label: 'Projects Dashboard +1'),
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
