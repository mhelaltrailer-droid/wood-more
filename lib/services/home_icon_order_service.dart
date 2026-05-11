import 'icon_visibility_service.dart';
import '../models/user_model.dart';

const String homeIconIdIconsControl = 'icons_control';

const List<String> appAdminHomeDefaultIconOrder = [
  'attendance_reports',
  'work_plan_tracking_report',
  'new_icon',
  'operation_reports_tracking',
  homeIconIdIconsControl,
  'daily_movement',
  'reports',
  'aggregated_detailed_daily',
  'contractor_report',
  'ir_mir',
  'warehouses_view',
  'admin_project_structure',
  'admin_dashboard',
  'activity_logs',
  'dashboard',
];

List<String> eligibleAppAdminHomeIconIds({
  required UserModel user,
  required Map<String, bool>? iconConfig,
}) {
  final out = <String>[];
  for (final iconId in appAdminHomeDefaultIconOrder) {
    if (!_isAppAdminHomeIconAvailable(
      iconId: iconId,
      user: user,
      iconConfig: iconConfig,
    )) {
      continue;
    }
    out.add(iconId);
  }
  return out;
}

bool _isAppAdminHomeIconAvailable({
  required String iconId,
  required UserModel user,
  required Map<String, bool>? iconConfig,
}) {
  switch (iconId) {
    case homeIconIdIconsControl:
      return user.canManageIconsControl;
    case 'daily_movement':
    case 'activity_logs':
      return user.canViewActivityLogs &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    default:
      return IconVisibilityService.isVisible(iconConfig, iconId);
  }
}

List<String> resolveAppAdminHomeIconOrder({
  required UserModel user,
  required Map<String, bool>? iconConfig,
  required List<String>? savedOrder,
}) {
  final eligible = eligibleAppAdminHomeIconIds(
    user: user,
    iconConfig: iconConfig,
  );
  if (savedOrder == null || savedOrder.isEmpty) return eligible;

  final eligibleSet = eligible.toSet();
  final ordered = <String>[];
  for (final iconId in savedOrder) {
    if (eligibleSet.contains(iconId) && !ordered.contains(iconId)) {
      ordered.add(iconId);
    }
  }
  for (final iconId in eligible) {
    if (!ordered.contains(iconId)) ordered.add(iconId);
  }
  return ordered;
}

List<String> sanitizeSavedHomeIconOrder(List<dynamic>? raw) {
  if (raw == null || raw.isEmpty) return const [];
  return raw
      .map((value) => value.toString().trim())
      .where((value) => value.isNotEmpty)
      .toList();
}
