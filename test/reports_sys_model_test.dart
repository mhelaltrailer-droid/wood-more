import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/reports_sys_model.dart';
import 'package:wood_and_more_app/models/user_model.dart';

void main() {
  group('ReportsSysModel business rules', () {
    ReportsSysActionModel action({
      required String action,
      int actorId = 20,
      String actorName = 'مراجع',
      String? toName,
      DateTime? at,
    }) {
      return ReportsSysActionModel(
        id: 1,
        actorUserId: actorId,
        actorUserName: actorName,
        action: action,
        toUserName: toName,
        createdAt: at ?? DateTime(2026, 1, 1),
      );
    }

    ReportsSysModel base({
      required String status,
      required int creatorId,
      int? assigneeId,
      List<ReportsSysActionModel> actions = const [],
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
        actions: actions,
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
        actions: [
          action(
            action: ReportsSysActionModel.actionSubmit,
            actorId: 10,
            actorName: 'أحمد',
            toName: 'مراجع',
          ),
        ],
      );
      expect(r.canActBy(20), isTrue);
      expect(r.canEditBy(20), isFalse);
    });

    test('creator can edit pending when assignee has not acted', () {
      final r = base(
        status: ReportsSysModel.statusPendingReview,
        creatorId: 10,
        assigneeId: 20,
        actions: [
          action(
            action: ReportsSysActionModel.actionSubmit,
            actorId: 10,
            actorName: 'أحمد',
            toName: 'مراجع',
          ),
        ],
      );
      expect(r.canEditBy(10), isTrue);
      expect(r.canCreatorResendPendingBy(10), isTrue);
    });

    test('creator cannot edit pending after assignee acted', () {
      final r = base(
        status: ReportsSysModel.statusPendingReview,
        creatorId: 10,
        assigneeId: 30,
        actions: [
          action(
            action: ReportsSysActionModel.actionSubmit,
            actorId: 10,
            actorName: 'أحمد',
            toName: 'مراجع',
          ),
          action(
            action: ReportsSysActionModel.actionForward,
            actorId: 20,
            actorName: 'مراجع',
            toName: 'مدير',
          ),
        ],
      );
      expect(r.canEditBy(10), isFalse);
      expect(r.canCreatorResendPendingBy(10), isFalse);
      expect(r.canActBy(30), isTrue);
    });

    test('creator can edit when returned for edit', () {
      final r = base(
        status: ReportsSysModel.statusReturnedForEdit,
        creatorId: 10,
        assigneeId: 10,
      );
      expect(r.canEditBy(10), isTrue);
    });

    test('creator_edit_resubmit display phrase', () {
      final a = action(
        action: ReportsSysActionModel.actionCreatorEditResubmit,
        actorId: 10,
        actorName: 'أحمد',
        toName: 'محمد',
      );
      expect(
        a.displayPhraseAr,
        'أحمد قام بتعديل التقرير وأعاد إرساله لـ محمد',
      );
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

  group('Reports-SYS activity log visibility', () {
    test('operation manager can view activity log', () {
      final u = UserModel(
        id: 1,
        name: 'OM',
        email: 'om@example.com',
        role: 'operation_manager',
      );
      expect(u.canViewReportsSysActivityLog, isTrue);
    });

    test('primary app admin can view activity log', () {
      final u = UserModel(
        id: 1,
        name: 'Admin',
        email: UserModel.primaryAppAdminEmail,
        role: 'app_admin',
      );
      expect(u.canViewReportsSysActivityLog, isTrue);
    });

    test('site engineer cannot view activity log', () {
      final u = UserModel(
        id: 2,
        name: 'Eng',
        email: 'eng@example.com',
        role: 'site_engineer',
      );
      expect(u.canViewReportsSysActivityLog, isFalse);
    });
  });
}
