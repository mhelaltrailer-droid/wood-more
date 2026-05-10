class HomeIconItem {
  final String id;
  final String label;

  const HomeIconItem({required this.id, required this.label});
}

class IconVisibilityService {
  static const String roleAppAdmin = 'app_admin';
  static const String roleSiteEngineer = 'site_engineer';
  static const String roleSiteEngineerManager = 'site_engineer_manager';
  static const String roleOperationManager = 'operation_manager';
  static const String roleAccountant = 'accountant';

  static const Map<String, String> roleTitles = {
    roleAppAdmin: 'App admin',
    roleSiteEngineer: 'Site engineer',
    roleSiteEngineerManager: 'Site engineer manager',
    roleOperationManager: 'Operation manager',
    roleAccountant: 'Accountant',
  };

  static const Map<String, List<HomeIconItem>> roleIcons = {
    roleSiteEngineer: [
      HomeIconItem(id: 'attendance', label: 'تسجيل الحضور والانصراف'),
      HomeIconItem(id: 'today_work_plan', label: 'خطة عمل اليوم'),
      HomeIconItem(id: 'tomorrow_work_plan', label: 'خطة عمل الغد'),
      HomeIconItem(
        id: 'engineer_withdraw_materials',
        label: 'المخزن (سحب الخامات)',
      ),
      HomeIconItem(id: 'engineer_finances', label: 'الماليات'),
      HomeIconItem(id: 'operation_reports', label: 'تقارير التشغيل'),
      HomeIconItem(id: 'detailed_report', label: 'التقرير اليومي'),
      HomeIconItem(id: 'engineer_projects', label: 'المشروعات'),
      HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
    ],
    roleAccountant: [
      HomeIconItem(id: 'accountant_custody', label: 'العهدة'),
      HomeIconItem(id: 'accountant_finance', label: 'الماليات'),
    ],
    roleSiteEngineerManager: [
      HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
      HomeIconItem(
        id: 'work_plan_tracking_report',
        label: 'تقارير متابعة خطط اليوم/الغد',
      ),
      HomeIconItem(id: 'new_icon', label: 'New icon'),
      HomeIconItem(
        id: 'operation_reports_tracking',
        label: 'متابعة تقارير التشغيل',
      ),
      HomeIconItem(
        id: 'aggregated_detailed_daily',
        label: 'التقرير اليومي المجمع',
      ),
      HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
      HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
      HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
    ],
    roleOperationManager: [
      HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
      HomeIconItem(
        id: 'work_plan_tracking_report',
        label: 'تقارير متابعة خطط اليوم/الغد',
      ),
      HomeIconItem(id: 'new_icon', label: 'New icon'),
      HomeIconItem(
        id: 'operation_reports_tracking',
        label: 'متابعة تقارير التشغيل',
      ),
      HomeIconItem(
        id: 'aggregated_detailed_daily',
        label: 'التقرير اليومي المجمع',
      ),
      HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
      HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
      HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
    ],
    roleAppAdmin: [
      HomeIconItem(id: 'attendance_reports', label: 'تقارير الحضور والانصراف'),
      HomeIconItem(
        id: 'work_plan_tracking_report',
        label: 'تقارير متابعة خطط اليوم/الغد',
      ),
      HomeIconItem(id: 'new_icon', label: 'New icon'),
      HomeIconItem(
        id: 'operation_reports_tracking',
        label: 'متابعة تقارير التشغيل',
      ),
      HomeIconItem(id: 'daily_movement', label: 'الحركة اليومية'),
      HomeIconItem(id: 'reports', label: 'التقارير'),
      HomeIconItem(
        id: 'aggregated_detailed_daily',
        label: 'التقرير اليومي المجمع',
      ),
      HomeIconItem(id: 'contractor_report', label: 'تقارير المقاول'),
      HomeIconItem(id: 'ir_mir', label: 'IR-MIR'),
      HomeIconItem(id: 'warehouses_view', label: 'المخازن'),
      HomeIconItem(id: 'admin_project_structure', label: 'هيكلة المشروعات'),
      HomeIconItem(id: 'admin_dashboard', label: 'لوح التحكم'),
      HomeIconItem(id: 'activity_logs', label: 'سجل الحركة'),
      HomeIconItem(id: 'dashboard', label: 'Management Dashboard'),
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
