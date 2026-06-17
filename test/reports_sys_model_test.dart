import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/reports_sys_model.dart';

void main() {
  group('ReportsSysModel business rules', () {
    ReportsSysModel base({
      required String status,
      required int creatorId,
      int? assigneeId,
    }) {
      return ReportsSysModel(
        id: 1,
        reportName: 'تقرير 1',
        reportType: 'تقرير معاينة',
        summary: 'ملخص',
        status: status,
        createdByUserId: creatorId,
        createdByUserName: 'أحمد',
        currentAssigneeUserId: assigneeId,
        projectName: 'مشروع أ',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    }

    test('creator can edit draft when assignee is self', () {
      final r = base(
        status: ReportsSysModel.statusDraft,
        creatorId: 10,
        assigneeId: 10,
      );
      expect(r.canEditBy(10), isTrue);
      expect(r.canActBy(10), isFalse);
    });

    test('assignee can act when pending review', () {
      final r = base(
        status: ReportsSysModel.statusPendingReview,
        creatorId: 10,
        assigneeId: 20,
      );
      expect(r.canActBy(20), isTrue);
      expect(r.canEditBy(20), isFalse);
      expect(r.canEditBy(10), isFalse);
    });

    test('creator can edit when returned for edit', () {
      final r = base(
        status: ReportsSysModel.statusReturnedForEdit,
        creatorId: 10,
        assigneeId: 10,
      );
      expect(r.canEditBy(10), isTrue);
    });

    test('terminal states', () {
      expect(
        base(
          status: ReportsSysModel.statusArchived,
          creatorId: 1,
          assigneeId: null,
        ).isTerminal,
        isTrue,
      );
      expect(
        base(
          status: ReportsSysModel.statusRejected,
          creatorId: 1,
          assigneeId: 1,
        ).isTerminal,
        isTrue,
      );
      expect(
        base(
          status: ReportsSysModel.statusPendingReview,
          creatorId: 1,
          assigneeId: 2,
        ).isTerminal,
        isFalse,
      );
    });

    test('fromMap parses project fields', () {
      final m = ReportsSysModel.fromMap({
        'id': 5,
        'report_name': 'X',
        'report_type': 'تقرير معاينة',
        'summary': 's',
        'status': 'draft',
        'created_by_user_id': 1,
        'created_by_user_name': 'n',
        'project_id': 3,
        'project_name': 'Z1_EMAAR_F',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      });
      expect(m.projectId, 3);
      expect(m.projectName, 'Z1_EMAAR_F');
    });
  });
}
