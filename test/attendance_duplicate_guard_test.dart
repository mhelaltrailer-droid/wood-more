import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/attendance_record_model.dart';
import 'package:wood_and_more_app/services/attendance_duplicate_guard.dart';

void main() {
  test('check-in at same project blocked without visit to another project', () {
    final existing = [
      AttendanceRecordModel(
        id: 1,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 8, 0),
        location: '0,0',
        projectId: 5,
        projectName: 'S',
      ),
    ];
    final msg = duplicateAttendanceMessageIfAny(
      userRecords: existing,
      userId: 10,
      projectId: 5,
      projectName: 'S',
      type: 'check_in',
      onDate: DateTime(2026, 5, 20, 9, 0),
    );
    expect(msg, isNotNull);
    expect(msg, contains('الحضور'));
  });

  test('check-in at same project allowed after check-in at another project', () {
    final existing = [
      AttendanceRecordModel(
        id: 1,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 8, 0),
        location: '0,0',
        projectId: 5,
        projectName: 'S',
      ),
      AttendanceRecordModel(
        id: 2,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 10, 0),
        location: '0,0',
        projectId: 99,
        projectName: 'ص',
      ),
    ];
    final msg = duplicateAttendanceMessageIfAny(
      userRecords: existing,
      userId: 10,
      projectId: 5,
      projectName: 'S',
      type: 'check_in',
      onDate: DateTime(2026, 5, 20, 11, 0),
    );
    expect(msg, isNull);
  });

  test('second return to same project blocked without another project visit in between', () {
    final existing = [
      AttendanceRecordModel(
        id: 1,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 8, 0),
        location: '0,0',
        projectId: 5,
        projectName: 'S',
      ),
      AttendanceRecordModel(
        id: 2,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 10, 0),
        location: '0,0',
        projectId: 99,
        projectName: 'ص',
      ),
      AttendanceRecordModel(
        id: 3,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 11, 0),
        location: '0,0',
        projectId: 5,
        projectName: 'S',
      ),
    ];
    final msg = duplicateAttendanceMessageIfAny(
      userRecords: existing,
      userId: 10,
      projectId: 5,
      projectName: 'S',
      type: 'check_in',
      onDate: DateTime(2026, 5, 20, 12, 0),
    );
    expect(msg, isNotNull);
  });

  test('duplicateAttendanceMessageIfAny detects same project check_in same day', () {
    final day = DateTime(2026, 5, 20, 8, 0);
    final existing = [
      AttendanceRecordModel(
        id: 1,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 7, 0),
        location: '0,0',
        projectId: 5,
        projectName: 'P',
      ),
    ];
    final msg = duplicateAttendanceMessageIfAny(
      userRecords: existing,
      userId: 10,
      projectId: 5,
      projectName: 'P',
      type: 'check_in',
      onDate: day,
    );
    expect(msg, isNotNull);
    expect(msg, contains('الحضور'));
  });

  test('same user two projects same day: duplicate check is per project', () {
    final existing = [
      AttendanceRecordModel(
        id: 1,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 7, 0),
        location: '0,0',
        projectId: 5,
        projectName: 'P1',
      ),
    ];
    final msg = duplicateAttendanceMessageIfAny(
      userRecords: existing,
      userId: 10,
      projectId: 99,
      projectName: 'P2',
      type: 'check_in',
      onDate: DateTime(2026, 5, 20, 9, 0),
    );
    expect(msg, isNull);
  });

  test('different type same day same project is allowed', () {
    final existing = [
      AttendanceRecordModel(
        id: 1,
        userId: 10,
        userName: 'A',
        type: 'check_in',
        dateTime: DateTime(2026, 5, 20, 7, 0),
        location: '0,0',
        projectId: 5,
        projectName: 'P',
      ),
    ];
    final msg = duplicateAttendanceMessageIfAny(
      userRecords: existing,
      userId: 10,
      projectId: 5,
      projectName: 'P',
      type: 'check_out',
      onDate: DateTime(2026, 5, 20, 18, 0),
    );
    expect(msg, isNull);
  });
}
