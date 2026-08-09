import '../models/withdrawal_request_model.dart';
import 'notification_time_display.dart';

const String withdrawalRoleSem = 'site_engineer_manager';
const String withdrawalRoleOm = 'operation_manager';

/// هل ما زال الطلب بانتظار قرار من صاحب هذا الدور؟
bool withdrawalIsActionableForRole(WithdrawalRequestModel r, String role) {
  if (r.fulfilledAt != null) return false;
  if (r.overallStatus != WithdrawalRequestModel.statusPending) return false;
  if (role == withdrawalRoleSem) {
    return r.semStatus == WithdrawalRequestModel.statusPending;
  }
  if (role == withdrawalRoleOm) {
    return r.omStatus == WithdrawalRequestModel.statusPending &&
        r.semStatus == WithdrawalRequestModel.statusApproved;
  }
  return false;
}

String _statusForRole(WithdrawalRequestModel r, String role) =>
    role == withdrawalRoleSem ? r.semStatus : r.omStatus;

DateTime? _respondedAtForRole(WithdrawalRequestModel r, String role) =>
    role == withdrawalRoleSem ? r.semRespondedAt : r.omRespondedAt;

String? _reasonForRole(WithdrawalRequestModel r, String role) =>
    role == withdrawalRoleSem ? r.semReason : r.omReason;

/// سطر الإجراء الذي اتخذه صاحب الدور نفسه، أو null إن لم يتخذ قراراً بعد.
String? withdrawalOwnActionLine(WithdrawalRequestModel r, String role) {
  final respondedAt = _respondedAtForRole(r, role);
  if (respondedAt == null) return null;
  final at = formatNotificationDateTime(respondedAt);
  if (_statusForRole(r, role) == WithdrawalRequestModel.statusRejected) {
    final reason = (_reasonForRole(r, role) ?? '').trim();
    final suffix = reason.isEmpty ? '' : '\nالسبب: $reason';
    return 'تم رفض طلب السحب بتاريخ $at$suffix';
  }
  return 'تمت الموافقة على طلب السحب بتاريخ $at';
}

/// سطر يوضّح قرار المدير الآخر على نفس الطلب، أو null إن لم يقرر بعد.
String? withdrawalOtherManagerLine(WithdrawalRequestModel r, String role) {
  final otherRole = role == withdrawalRoleSem ? withdrawalRoleOm : withdrawalRoleSem;
  final respondedAt = _respondedAtForRole(r, otherRole);
  if (respondedAt == null) return null;
  final at = formatNotificationDateTime(respondedAt);
  final label = otherRole == withdrawalRoleOm ? 'مدير العمليات' : 'مدير المشروعات';
  if (_statusForRole(r, otherRole) == WithdrawalRequestModel.statusRejected) {
    final reason = (_reasonForRole(r, otherRole) ?? '').trim();
    final suffix = reason.isEmpty ? '' : '\nالسبب: $reason';
    return 'تم رفض طلب السحب من $label بتاريخ $at$suffix';
  }
  return 'تمت موافقة $label على طلب السحب بتاريخ $at';
}

/// نص الشارة اللونية لحالة الطلب من منظور صاحب الدور.
String withdrawalStatusBadgeLabel(WithdrawalRequestModel r, String role) {
  if (withdrawalIsActionableForRole(r, role)) return 'بانتظار قراركم';
  if (r.isRejectedOverall) return 'مرفوض';
  if (r.fulfilledAt != null) return 'تم السحب';
  if (r.isApprovedOverall) return 'معتمد';
  return 'بانتظار قرار مدير آخر';
}
