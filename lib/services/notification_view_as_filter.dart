/// فلترة إشعارات المسؤول الأساسي حسب الدور المعروض (View as).
bool isNotificationVisibleForViewAsRole({
  required String eventType,
  required String? viewAsRole,
}) {
  final role = viewAsRole?.trim();
  if (role == null || role.isEmpty) return true;

  final t = eventType.trim();
  if (t.startsWith('reports_sys_')) return true;

  switch (role) {
    case 'site_engineer':
      return t == 'balance_added' ||
          t == 'balance_withdrawn' ||
          t == 'withdrawal_request_approved' ||
          t == 'withdrawal_request_rejected' ||
          t == 'expense_statement_approved' ||
          t == 'expense_statement_rejected';
    case 'site_engineer_manager':
    case 'projects_manager':
      return t == 'withdrawal_request_created' ||
          t == 'withdrawal_request_approved' ||
          t == 'withdrawal_request_rejected' ||
          t == 'expense_statement_submitted' ||
          t == 'expense_statement_approved' ||
          t == 'expense_statement_rejected' ||
          t == 'expense_statement_attachment' ||
          t.startsWith('operation_report') ||
          t == 'attendance_alert' ||
          t.contains('attendance') ||
          t.contains('work_plan') ||
          t.contains('file_upload') ||
          t.contains('attachment') ||
          t.startsWith('ir_mir') ||
          t.startsWith('ms_sd') ||
          t.startsWith('mos_itp');
    case 'operation_manager':
      return t == 'withdrawal_request_created' ||
          t == 'withdrawal_request_approved' ||
          t == 'withdrawal_request_rejected' ||
          t.contains('shop') ||
          t.contains('meeting') ||
          t.startsWith('invoices_owner') ||
          t.contains('attachment') ||
          t.contains('file_upload') ||
          t.contains('work_plan') ||
          t.contains('attendance') ||
          t.startsWith('operation_report') ||
          t.startsWith('projects_dashboard');
    case 'general_supervisor':
      return t.contains('work_plan') ||
          t.contains('attendance') ||
          t.contains('attachment') ||
          t.startsWith('operation_report');
    case 'document_controller':
      return t.startsWith('ir_mir') ||
          t.startsWith('ms_sd') ||
          t.startsWith('mos_itp') ||
          t.contains('attachment') ||
          t.contains('file_upload');
    case 'accountant':
      return t == 'balance_added' ||
          t == 'balance_withdrawn' ||
          t.contains('expense') ||
          t.contains('custody') ||
          t.startsWith('invoices_owner');
    case 'finance':
    case 'qs':
    case 'technical_office':
      return t.startsWith('invoices_owner') ||
          t.contains('shop') ||
          t.startsWith('projects_dashboard') ||
          t.contains('attachment');
    case 'top_management':
      return t.contains('shop');
    case 'op_coordinator':
      return t.contains('meeting');
    default:
      return true;
  }
}
