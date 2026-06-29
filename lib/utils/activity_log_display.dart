import 'package:intl/intl.dart';

import '../models/activity_log_model.dart';
import '../models/user_model.dart';

/// تحويل وصف الحركة إلى صيغة «قام … بـ…».
String activityLogActionPhrase(ActivityLogModel log) {
  final label = log.actionLabel.trim();
  if (label.isNotEmpty) {
    return _phraseFromLabel(label);
  }
  return _phraseFromType(log.actionType);
}

String activityLogUserName(
  ActivityLogModel log, {
  List<UserModel> users = const [],
}) {
  final direct = log.userName?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  if (log.userId != null) {
    for (final u in users) {
      if (u.id == log.userId) return u.name;
    }
  }
  final email = log.userEmail?.trim().toLowerCase();
  if (email != null && email.isNotEmpty) {
    for (final u in users) {
      if (u.email.trim().toLowerCase() == email) return u.name;
    }
  }
  return 'مستخدم غير معروف';
}

String activityLogUserEmail(
  ActivityLogModel log, {
  List<UserModel> users = const [],
}) {
  final direct = log.userEmail?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  if (log.userId != null) {
    for (final u in users) {
      if (u.id == log.userId) return u.email;
    }
  }
  return '—';
}

String activityLogNarrative(
  ActivityLogModel log, {
  List<UserModel> users = const [],
  DateFormat? timeFormat,
}) {
  final fmt = timeFormat ?? DateFormat('HH:mm — yyyy/MM/dd');
  final name = activityLogUserName(log, users: users);
  final phrase = activityLogActionPhrase(log);
  final time = fmt.format(log.createdAt.toLocal());
  return 'قام $name $phrase ($time)';
}

String _phraseFromLabel(String label) {
  const map = {
    'تسجيل دخول': 'بتسجيل الدخول',
    'تسجيل حضور': 'بتسجيل الحضور',
    'تسجيل انصراف': 'بتسجيل الانصراف',
    'تسجيل حضور/انصراف': 'بتسجيل الحضور أو الانصراف',
    'حفظ خطة عمل اليوم': 'بحفظ خطة عمل اليوم',
    'تسجيل خطة عمل الغد': 'بتسجيل خطة عمل الغد',
    'تسجيل خطة عمل لاحقة': 'بتسجيل خطة عمل لاحقة',
    'تعديل خطة عمل اليوم': 'بتعديل خطة عمل اليوم',
    'تعديل خطة عمل الغد': 'بتعديل خطة عمل الغد',
    'تعديل خطة عمل لاحقة': 'بتعديل خطة عمل لاحقة',
    'تنفيذ خطة عمل': 'بتنفيذ خطة عمل',
    'تعديل وتنفيذ خطة عمل': 'بتعديل وتنفيذ خطة عمل',
    'تأجيل خطة عمل': 'بتأجيل خطة عمل',
    'عرض تقرير يومي': 'بعرض تقرير يومي',
    'إنشاء تقرير يومي': 'بإنشاء تقرير يومي',
    'تعديل تقرير يومي': 'بتعديل تقرير يومي',
    'حذف تقرير يومي': 'بحذف تقرير يومي',
    'عرض تقرير مفصل': 'بعرض تقرير مفصل',
    'إنشاء تقرير مفصل': 'بإنشاء تقرير مفصل',
    'تعديل تقرير مفصل': 'بتعديل تقرير مفصل',
    'حذف تقرير مفصل': 'بحذف تقرير مفصل',
    'إنشاء مستخدم': 'بإنشاء مستخدم',
    'تعديل مستخدم': 'بتعديل مستخدم',
    'حذف مستخدم': 'بحذف مستخدم',
    'إنشاء مشروع': 'بإنشاء مشروع',
    'تعديل مشروع': 'بتعديل مشروع',
    'حذف مشروع': 'بحذف مشروع',
    'عرض سجل الحركة': 'بعرض سجل الحركة',
    'حركة أخرى': 'بإجراء على النظام',
  };
  return map[label] ?? 'ب$label';
}

String _phraseFromType(String actionType) {
  const map = {
    'login': 'بتسجيل الدخول',
    'attendance_check_in': 'بتسجيل الحضور',
    'attendance_check_out': 'بتسجيل الانصراف',
    'attendance_record': 'بتسجيل الحضور أو الانصراف',
    'plan_save_today': 'بحفظ خطة عمل اليوم',
    'plan_save_tomorrow': 'بتسجيل خطة عمل الغد',
    'plan_save_future': 'بتسجيل خطة عمل لاحقة',
    'plan_update_today': 'بتعديل خطة عمل اليوم',
    'plan_update_tomorrow': 'بتعديل خطة عمل الغد',
    'plan_update_future': 'بتعديل خطة عمل لاحقة',
    'plan_execute': 'بتنفيذ خطة عمل',
    'plan_execute_edited': 'بتعديل وتنفيذ خطة عمل',
    'plan_postpone': 'بتأجيل خطة عمل',
    'daily_report_view': 'بعرض تقرير يومي',
    'daily_report_create': 'بإنشاء تقرير يومي',
    'daily_report_update': 'بتعديل تقرير يومي',
    'daily_report_delete': 'بحذف تقرير يومي',
    'detailed_report_view': 'بعرض تقرير مفصل',
    'detailed_report_create': 'بإنشاء تقرير مفصل',
    'detailed_report_update': 'بتعديل تقرير مفصل',
    'detailed_report_delete': 'بحذف تقرير مفصل',
    'user_create': 'بإنشاء مستخدم',
    'user_update': 'بتعديل مستخدم',
    'user_delete': 'بحذف مستخدم',
    'project_create': 'بإنشاء مشروع',
    'project_update': 'بتعديل مشروع',
    'project_delete': 'بحذف مشروع',
    'activity_log_view': 'بعرض سجل الحركة',
    'other': 'بإجراء على النظام',
  };
  return map[actionType] ?? 'بإجراء على النظام';
}

/// خيارات فلتر «نوع الحركة» في شاشة سجل الحركة.
const List<Map<String, String>> activityLogFilterActionTypes = [
  {'value': '', 'label': 'كل أنواع الحركة'},
  {'value': 'login', 'label': 'تسجيل دخول'},
  {'value': 'attendance_check_in', 'label': 'تسجيل حضور'},
  {'value': 'attendance_check_out', 'label': 'تسجيل انصراف'},
  {'value': 'plan_save_today', 'label': 'حفظ خطة عمل اليوم'},
  {'value': 'plan_save_tomorrow', 'label': 'تسجيل خطة عمل الغد'},
  {'value': 'plan_update_today', 'label': 'تعديل خطة عمل اليوم'},
  {'value': 'plan_update_tomorrow', 'label': 'تعديل خطة عمل الغد'},
  {'value': 'plan_execute', 'label': 'تنفيذ خطة عمل'},
  {'value': 'plan_execute_edited', 'label': 'تعديل وتنفيذ خطة عمل'},
  {'value': 'plan_postpone', 'label': 'تأجيل خطة عمل'},
  {'value': 'daily_report_create', 'label': 'إنشاء تقرير يومي'},
  {'value': 'daily_report_update', 'label': 'تعديل تقرير يومي'},
  {'value': 'daily_report_delete', 'label': 'حذف تقرير يومي'},
  {'value': 'detailed_report_create', 'label': 'إنشاء تقرير مفصل'},
  {'value': 'detailed_report_update', 'label': 'تعديل تقرير مفصل'},
  {'value': 'detailed_report_delete', 'label': 'حذف تقرير مفصل'},
  {'value': 'user_create', 'label': 'إنشاء مستخدم'},
  {'value': 'user_update', 'label': 'تعديل مستخدم'},
  {'value': 'user_delete', 'label': 'حذف مستخدم'},
  {'value': 'project_create', 'label': 'إنشاء مشروع'},
  {'value': 'project_update', 'label': 'تعديل مشروع'},
  {'value': 'project_delete', 'label': 'حذف مشروع'},
  {'value': 'activity_log_view', 'label': 'عرض سجل الحركة'},
  {'value': 'other', 'label': 'حركة أخرى'},
];
