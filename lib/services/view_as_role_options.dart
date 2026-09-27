import 'icon_visibility_service.dart';
import 'view_as_role_session.dart';

/// خيارات قائمة View as (المسؤول الأساسي أولاً، ثم باقي الأدوار بدون app_admin).
class ViewAsRoleOption {
  final String value;
  final String label;

  const ViewAsRoleOption({required this.value, required this.label});
}

List<ViewAsRoleOption> buildViewAsRoleOptions(
  String Function(String role) labelForRole,
) {
  final options = <ViewAsRoleOption>[
    const ViewAsRoleOption(
      value: ViewAsRoleSession.primaryOptionValue,
      label: ViewAsRoleSession.primaryLabel,
    ),
  ];
  final roles = IconVisibilityService.roleIcons.keys.toList()
    ..remove(IconVisibilityService.roleAppAdmin)
    ..sort();
  for (final role in roles) {
    final label = labelForRole(role);
    options.add(
      ViewAsRoleOption(
        value: role,
        label: label.isNotEmpty ? label : role,
      ),
    );
  }
  return options;
}
