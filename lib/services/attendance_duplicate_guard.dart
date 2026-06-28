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

const _kDuplicateCheckInMessage =
    'تم تسجيل الحضور مسبقاً لهذا المشروع اليوم. لا داعي لإعادة التسجيل مرة أخرى.';

const _kDuplicateCheckOutMessage =
    'تم تسجيل الانصراف مسبقاً لهذا المشروع اليوم. لا داعي لإعادة التسجيل مرة أخرى.';

/// حضور مكرر لنفس المشروع يُسمح فقط إذا سجّل المستخدم حضوراً في مشروع آخر بعد آخر حضور في هذا المشروع.
String? _duplicateCheckInMessageIfAny({
  required Iterable<AttendanceRecordModel> userRecords,
  required int userId,
  required int? projectId,
  required String? projectName,
  required DateTime onDate,
}) {
  final dayCheckIns = userRecords
      .where(
        (r) =>
            r.userId == userId &&
            r.type == 'check_in' &&
            _sameCalendarDay(r.dateTime, onDate),
      )
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  AttendanceRecordModel? lastSameProject;
  for (final r in dayCheckIns) {
    if (attendanceSameProject(r, projectId, projectName)) {
      lastSameProject = r;
    }
  }
  if (lastSameProject == null) return null;

  final lastTime = lastSameProject.dateTime;
  final visitedOtherProjectAfter = dayCheckIns.any(
    (r) =>
        r.dateTime.isAfter(lastTime) &&
        !attendanceSameProject(r, projectId, projectName),
  );
  if (visitedOtherProjectAfter) return null;

  return _kDuplicateCheckInMessage;
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
  if (type == 'check_in') {
    return _duplicateCheckInMessageIfAny(
      userRecords: userRecords,
      userId: userId,
      projectId: projectId,
      projectName: projectName,
      onDate: onDate,
    );
  }

  for (final r in userRecords) {
    if (r.userId != userId) continue;
    if (r.type != type) continue;
    if (!_sameCalendarDay(r.dateTime, onDate)) continue;
    if (!attendanceSameProject(r, projectId, projectName)) continue;
    if (type == 'check_out') {
      return _kDuplicateCheckOutMessage;
    }
  }
  return null;
}
