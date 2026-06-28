import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/attendance_record_model.dart';
import 'package:wood_and_more_app/utils/worker_hours_calc.dart';

AttendanceRecordModel _rec({
  required int id,
  required int userId,
  required String type,
  required DateTime dateTime,
  int? projectId,
  String? projectName,
  String? notes,
}) {
  return AttendanceRecordModel(
    id: id,
    userId: userId,
    userName: 'Test',
    type: type,
    dateTime: dateTime,
    location: '',
    projectId: projectId,
    projectName: projectName,
    notes: notes,
  );
}

void main() {
  group('calculateWorkerHoursForDay', () {
    test('empty day returns zero', () {
      expect(calculateWorkerHoursForDay([]), Duration.zero);
    });

    test('check-in without check-out returns 6 hours', () {
      final hours = calculateWorkerHoursForDay([
        _rec(
          id: 1,
          userId: 1,
          type: 'check_in',
          dateTime: DateTime(2026, 5, 21, 8),
          projectId: 10,
        ),
      ]);
      expect(hours, const Duration(hours: 6));
    });

    test('check-in and check-out returns actual duration', () {
      final hours = calculateWorkerHoursForDay([
        _rec(
          id: 1,
          userId: 1,
          type: 'check_in',
          dateTime: DateTime(2026, 5, 21, 8, 0),
          projectId: 10,
        ),
        _rec(
          id: 2,
          userId: 1,
          type: 'check_out',
          dateTime: DateTime(2026, 5, 21, 13, 30),
          projectId: 10,
        ),
      ]);
      expect(hours, const Duration(hours: 5, minutes: 30));
    });

    test('actual duration can exceed 10 hours on single project', () {
      final hours = calculateWorkerHoursForDay([
        _rec(
          id: 1,
          userId: 1,
          type: 'check_in',
          dateTime: DateTime(2026, 5, 21, 7, 0),
          projectId: 10,
        ),
        _rec(
          id: 2,
          userId: 1,
          type: 'check_out',
          dateTime: DateTime(2026, 5, 21, 20, 0),
          projectId: 10,
        ),
      ]);
      expect(hours, const Duration(hours: 13));
    });

    test('multiple projects returns 10 hours', () {
      final hours = calculateWorkerHoursForDay([
        _rec(
          id: 1,
          userId: 1,
          type: 'check_in',
          dateTime: DateTime(2026, 5, 21, 8),
          projectId: 10,
        ),
        _rec(
          id: 2,
          userId: 1,
          type: 'check_out',
          dateTime: DateTime(2026, 5, 21, 12),
          projectId: 20,
        ),
      ]);
      expect(hours, const Duration(hours: 10));
    });

    test('multiple projects with only check-outs returns 10 hours', () {
      final hours = calculateWorkerHoursForDay([
        _rec(
          id: 1,
          userId: 1,
          type: 'check_out',
          dateTime: DateTime(2026, 5, 21, 12),
          projectId: 10,
        ),
        _rec(
          id: 2,
          userId: 1,
          type: 'check_out',
          dateTime: DateTime(2026, 5, 21, 16),
          projectId: 20,
        ),
      ]);
      expect(hours, const Duration(hours: 10));
    });
  });

  group('buildWorkerHoursReport', () {
    test('sums daily hours including zero days in total', () {
      final rows = buildWorkerHoursReport(
        dateFrom: DateTime(2026, 5, 20),
        dateTo: DateTime(2026, 5, 23),
        users: [(id: 1, name: 'هاني')],
        allRecords: [
          _rec(
            id: 1,
            userId: 1,
            type: 'check_in',
            dateTime: DateTime(2026, 5, 20, 8),
            projectId: 1,
          ),
          _rec(
            id: 2,
            userId: 1,
            type: 'check_out',
            dateTime: DateTime(2026, 5, 20, 13),
            projectId: 1,
          ),
          _rec(
            id: 3,
            userId: 1,
            type: 'check_in',
            dateTime: DateTime(2026, 5, 22, 8),
            projectId: 1,
          ),
        ],
      );
      expect(rows.length, 1);
      final row = rows.single;
      expect(row.days.length, 4);
      expect(row.days[0].duration, const Duration(hours: 5));
      expect(row.days[1].duration, Duration.zero);
      expect(row.days[2].duration, const Duration(hours: 6));
      expect(row.days[3].duration, Duration.zero);
      expect(row.totalDuration, const Duration(hours: 11));
    });

    test('notes sorted oldest first', () {
      final rows = buildWorkerHoursReport(
        dateFrom: DateTime(2026, 3, 20),
        dateTo: DateTime(2026, 5, 25),
        users: [(id: 1, name: 'هاني')],
        allRecords: [
          _rec(
            id: 1,
            userId: 1,
            type: 'check_in',
            dateTime: DateTime(2026, 5, 21, 8),
            projectId: 1,
            notes: 'عطل السيارة',
          ),
          _rec(
            id: 2,
            userId: 1,
            type: 'check_in',
            dateTime: DateTime(2026, 3, 20, 8),
            projectId: 1,
            notes: 'الذهاب للإدارة',
          ),
        ],
      );
      expect(rows.single.notes.map((n) => n.text).toList(), [
        'الذهاب للإدارة',
        'عطل السيارة',
      ]);
    });
  });

  group('formatting', () {
    test('formatWorkerHoursDuration', () {
      expect(
        formatWorkerHoursDuration(const Duration(hours: 5, minutes: 30)),
        '5:30',
      );
      expect(formatWorkerHoursDuration(const Duration(hours: 27)), '27:00');
    });

    test('formatWorkerHoursBreakdown', () {
      expect(
        formatWorkerHoursBreakdown([
          const Duration(hours: 5),
          const Duration(hours: 6),
          const Duration(hours: 10),
        ]),
        '5:00 + 6:00 + 10:00',
      );
    });
  });
}
