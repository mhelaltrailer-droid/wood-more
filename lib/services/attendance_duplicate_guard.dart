import '../models/attendance_record_model.dart';

/// يُرمى عند محاولة تسجيل حضور أو انصراف مكرر لنفس المشروع في نفس اليوم.
class DuplicateAttendanceException implements Exception {
  final String message;

  DuplicateAttendanceException(this.message);

  @override
  String toString() => message;
}

/// مفتاح اليوم حسب تقويم الجهاز المحلي (نفس منطق [getAttendanceForUserOnDate]).
String attendanceLocalCalendarDateKey(DateTime dateTime) {
  return '${dateTime.year.toString().padLeft(4, '0')}-'
      '${dateTime.month.toString().padLeft(2, '0')}-'
      '${dateTime.day.toString().padLeft(2, '0')}';
}

bool _sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// هل السجل [r] يخص نفس المشروع المقصود (معرّفاً أو اسماً لمشروع آخر).
bool attendanceSameProject(
  AttendanceRecordModel r,
  int? projectId,
  String? projectName,
) {
  final wantName = (projectName ?? '').trim();
  if (projectId != null) {
    if (r.projectId == projectId) return true;
    if (r.projectId == null && (r.projectName ?? '').trim() == wantName) {
      return true;
    }
    return false;
  }
  return (r.projectName ?? '').trim() == wantName;
}

/// رسالة إن وُجد تسجيل سابق من نفس النوع لنفس المستخدم والمشروع في نفس اليوم؛ وإلا null.
String? duplicateAttendanceMessageIfAny({
  required Iterable<AttendanceRecordModel> userRecords,
  required int userId,
  required int? projectId,
  required String? projectName,
  required String type,
  required DateTime onDate,
}) {
  for (final r in userRecords) {
    if (r.userId != userId) continue;
    if (r.type != type) continue;
    if (!_sameCalendarDay(r.dateTime, onDate)) continue;
    if (!attendanceSameProject(r, projectId, projectName)) continue;
    if (type == 'check_in') {
      return 'تم تسجيل الحضور مسبقاً لهذا المشروع اليوم. لا داعي لإعادة التسجيل مرة أخرى.';
    }
    if (type == 'check_out') {
      return 'تم تسجيل الانصراف مسبقاً لهذا المشروع اليوم. لا داعي لإعادة التسجيل مرة أخرى.';
    }
  }
  return null;
}
