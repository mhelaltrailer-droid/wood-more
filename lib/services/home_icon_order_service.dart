import 'icon_visibility_service.dart';
import '../models/user_model.dart';

const String homeIconIdIconsControl = 'icons_control';
const String homeIconIdSiteEngineerExpensesReport = 'site_engineer_expenses_report';
const String homeIconIdShopDrawing = 'shop_drawing';
const String homeIconIdCustodyExpensesView = 'custody_expenses_view';

List<String> defaultHomeIconOrderForUser(UserModel user) {
  final roleItems = IconVisibilityService.roleIcons[user.role] ?? const [];
  final out = roleItems.map((item) => item.id).toList();
  if (user.canManageIconsControl && !out.contains(homeIconIdIconsControl)) {
    final anchorIndex = out.indexOf('new_icon');
    if (anchorIndex >= 0) {
      out.insert(anchorIndex + 1, homeIconIdIconsControl);
    } else {
      out.add(homeIconIdIconsControl);
    }
  }
  if (user.canManageSiteEngineerExpensesReport &&
      !out.contains(homeIconIdSiteEngineerExpensesReport)) {
    final anchorIndex = out.indexOf('reports');
    if (anchorIndex >= 0) {
      out.insert(anchorIndex + 1, homeIconIdSiteEngineerExpensesReport);
    } else {
      out.add(homeIconIdSiteEngineerExpensesReport);
    }
  }
  if (user.canViewCustodyExpensesArchive &&
      !out.contains(homeIconIdCustodyExpensesView)) {
    out.add(homeIconIdCustodyExpensesView);
  }
  if (user.canAccessShopDrawingHomeIcon && !out.contains(homeIconIdShopDrawing)) {
    out.insert(0, homeIconIdShopDrawing);
  }
  return out;
}

List<String> eligibleHomeIconIds({
  required UserModel user,
  required Map<String, bool>? iconConfig,
}) {
  final out = <String>[];
  for (final iconId in defaultHomeIconOrderForUser(user)) {
    if (!_isHomeIconAvailable(
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

bool _isHomeIconAvailable({
  required String iconId,
  required UserModel user,
  required Map<String, bool>? iconConfig,
}) {
  switch (iconId) {
    case homeIconIdIconsControl:
      return user.canManageIconsControl;
    case homeIconIdSiteEngineerExpensesReport:
      return user.canManageSiteEngineerExpensesReport;
    case homeIconIdCustodyExpensesView:
      return user.canViewCustodyExpensesArchive &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case 'postpone_fines_reports':
      return user.canAccessPostponeFinesReports &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case 'activity_logs':
      return user.canViewActivityLogs &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case 'reports_sys':
      return user.canParticipateInReportsSys &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case homeIconIdShopDrawing:
      return user.canAccessShopDrawingHomeIcon &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case 'projects_dashboard':
      return user.canAccessProjectsDashboard &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case 'projects_dashboard_plus1':
      return user.canAccessProjectsDashboard &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    default:
      return IconVisibilityService.isVisible(iconConfig, iconId);
  }
}

List<String> resolveHomeIconOrder({
  required UserModel user,
  required Map<String, bool>? iconConfig,
  required List<String>? savedOrder,
}) {
  final eligible = eligibleHomeIconIds(user: user, iconConfig: iconConfig);
  if (savedOrder == null || savedOrder.isEmpty) return eligible;

  const legacyDocControlIds = {'ir_mir', 'ms_sd', 'qs_invs', 'mos_itp'};
  final eligibleSet = eligible.toSet();
  final ordered = <String>[];
  var insertedDocControl = false;
  for (final iconId in savedOrder) {
    if (legacyDocControlIds.contains(iconId)) {
      if (!insertedDocControl &&
          eligibleSet.contains('document_control') &&
          !ordered.contains('document_control')) {
        ordered.add('document_control');
        insertedDocControl = true;
      }
      continue;
    }
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
