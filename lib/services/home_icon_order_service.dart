import 'icon_visibility_service.dart';
import '../models/user_model.dart';

const String homeIconIdIconsControl = 'icons_control';

List<String> defaultHomeIconOrderForUser(UserModel user) {
  final roleItems = IconVisibilityService.roleIcons[user.role] ?? const [];
  final out = roleItems.map((item) => item.id).toList();
  if (user.canManageIconsControl && !out.contains(homeIconIdIconsControl)) {
    final trackingIndex = out.indexOf('operation_reports_tracking');
    if (trackingIndex >= 0) {
      out.insert(trackingIndex + 1, homeIconIdIconsControl);
    } else {
      out.add(homeIconIdIconsControl);
    }
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
    case 'postpone_fines_reports':
      return user.canAccessPostponeFinesReports &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case 'daily_movement':
    case 'activity_logs':
      return user.canViewActivityLogs &&
          IconVisibilityService.isVisible(iconConfig, iconId);
    case 'reports_sys':
      return user.canParticipateInReportsSys &&
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
