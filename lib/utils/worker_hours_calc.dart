import '../models/attendance_record_model.dart';
import '../services/attendance_duplicate_guard.dart';

/// ساعات يوم واحد ضمن تقرير العمال.
class WorkerDayHoursEntry {
  final DateTime day;
  final Duration duration;
  final bool hasActivity;

  const WorkerDayHoursEntry({
    required this.day,
    required this.duration,
    required this.hasActivity,
  });
}

/// ملاحظة حضور/انصراف ضمن التقرير.
class WorkerHoursNoteEntry {
  final DateTime dateTime;
  final String text;

  const WorkerHoursNoteEntry({required this.dateTime, required this.text});
}

/// صف تقرير ساعات العمل لمستخدم واحد.
class WorkerHoursReportRow {
  final int userId;
  final String userName;
  final DateTime dateFrom;
  final DateTime dateTo;
  final List<WorkerDayHoursEntry> days;
  final List<WorkerHoursNoteEntry> notes;

  const WorkerHoursReportRow({
    required this.userId,
    required this.userName,
    required this.dateFrom,
    required this.dateTo,
    required this.days,
    required this.notes,
  });

  Duration get totalDuration =>
      days.fold(Duration.zero, (sum, d) => sum + d.duration);

  /// أيام بها نشاط حضور/انصراف فقط (للعرض المختصر).
  List<WorkerDayHoursEntry> get activeDays =>
      days.where((d) => d.hasActivity).toList();
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// مفتاح مشروع لسجل حضور (معرّف أو اسم).
String attendanceProjectKey(AttendanceRecordModel record) {
  if (record.projectId != null) return 'id:${record.projectId}';
  final name = (record.projectName ?? '').trim();
  if (name.isNotEmpty) return 'name:$name';
  return 'unknown';
}

/// حساب ساعات يوم واحد من سجلات هذا اليوم.
Duration calculateWorkerHoursForDay(List<AttendanceRecordModel> dayRecords) {
  if (dayRecords.isEmpty) return Duration.zero;

  final projectKeys = dayRecords.map(attendanceProjectKey).toSet();
  if (projectKeys.length > 1) {
    return const Duration(hours: 10);
  }

  DateTime? checkIn;
  DateTime? checkOut;
  for (final record in dayRecords) {
    if (record.isCheckIn) {
      if (checkIn == null || record.dateTime.isBefore(checkIn)) {
        checkIn = record.dateTime;
      }
    }
    if (record.isCheckOut) {
      if (checkOut == null || record.dateTime.isAfter(checkOut)) {
        checkOut = record.dateTime;
      }
    }
  }

  if (checkIn != null && checkOut != null) {
    final diff = checkOut.difference(checkIn);
    return diff.isNegative ? Duration.zero : diff;
  }
  if (checkIn != null) {
    return const Duration(hours: 6);
  }
  return Duration.zero;
}

/// تجميع سجلات المستخدم حسب اليوم.
Map<String, List<AttendanceRecordModel>> groupAttendanceByDay(
  Iterable<AttendanceRecordModel> records,
) {
  final grouped = <String, List<AttendanceRecordModel>>{};
  for (final record in records) {
    final key = attendanceLocalCalendarDateKey(record.dateTime);
    grouped.putIfAbsent(key, () => <AttendanceRecordModel>[]).add(record);
  }
  return grouped;
}

List<WorkerDayHoursEntry> buildDailyHoursEntries({
  required DateTime dateFrom,
  required DateTime dateTo,
  required Map<String, List<AttendanceRecordModel>> recordsByDay,
}) {
  final from = dateOnly(dateFrom);
  final to = dateOnly(dateTo);
  final out = <WorkerDayHoursEntry>[];
  for (var day = from; !day.isAfter(to); day = day.add(const Duration(days: 1))) {
    final key = attendanceLocalCalendarDateKey(day);
    final dayRecords = recordsByDay[key] ?? const [];
    out.add(
      WorkerDayHoursEntry(
        day: day,
        duration: calculateWorkerHoursForDay(dayRecords),
        hasActivity: dayRecords.isNotEmpty,
      ),
    );
  }
  return out;
}

List<WorkerHoursNoteEntry> collectWorkerHoursNotes(
  Iterable<AttendanceRecordModel> records,
) {
  final notes = <WorkerHoursNoteEntry>[];
  for (final record in records) {
    final text = (record.notes ?? '').trim();
    if (text.isEmpty) continue;
    notes.add(WorkerHoursNoteEntry(dateTime: record.dateTime, text: text));
  }
  notes.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return notes;
}

List<WorkerHoursReportRow> buildWorkerHoursReport({
  required DateTime dateFrom,
  required DateTime dateTo,
  required Iterable<AttendanceRecordModel> allRecords,
  required Iterable<({int id, String name})> users,
}) {
  final from = dateOnly(dateFrom);
  final to = dateOnly(dateTo);
  final toEnd = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

  final rows = <WorkerHoursReportRow>[];
  for (final user in users) {
    final userRecords = allRecords.where((record) {
      if (record.userId != user.id) return false;
      return !record.dateTime.isBefore(from) && !record.dateTime.isAfter(toEnd);
    }).toList();

    final byDay = groupAttendanceByDay(userRecords);
    rows.add(
      WorkerHoursReportRow(
        userId: user.id,
        userName: user.name,
        dateFrom: from,
        dateTo: to,
        days: buildDailyHoursEntries(
          dateFrom: from,
          dateTo: to,
          recordsByDay: byDay,
        ),
        notes: collectWorkerHoursNotes(userRecords),
      ),
    );
  }
  return rows;
}

/// تنسيق المدة: ساعات:دقائق (مثل 5:30).
String formatWorkerHoursDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '$hours:${minutes.toString().padLeft(2, '0')}';
}

/// تجميع ساعات الأيام للعرض: 5:30 + 6:00 + 10:00
String formatWorkerHoursBreakdown(Iterable<Duration> dailyDurations) {
  if (dailyDurations.isEmpty) return '0:00';
  return dailyDurations.map(formatWorkerHoursDuration).join(' + ');
}

/// المدة الزمنية للتقرير.
String formatWorkerHoursPeriodLabel(DateTime from, DateTime to) {
  String fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  return 'من ${fmt(from)} إلى ${fmt(to)}';
}

/// الملاحظات مرتبة من الأقدم للأحدث.
String formatWorkerHoursNotes(List<WorkerHoursNoteEntry> notes) {
  if (notes.isEmpty) return '—';
  return notes
      .map((note) {
        final d = note.dateTime;
        final dateLabel =
            '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
        return '(${note.text}) - ($dateLabel)';
      })
      .join('\n');
}
