import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wood_and_more_app/models/mos_itp_record_model.dart';
import 'package:wood_and_more_app/models/ms_sd_record_model.dart';
import 'package:wood_and_more_app/models/user_model.dart';
import 'package:wood_and_more_app/services/icon_visibility_service.dart';
import 'package:wood_and_more_app/services/web_storage_service.dart';
import 'package:wood_and_more_app/utils/ms_sd_file_limits.dart';
import 'package:wood_and_more_app/widgets/home_icon_builder.dart';

UserModel _user({
  required String role,
  String email = 'user@example.com',
  int id = 1,
}) {
  return UserModel(id: id, name: 'Test', email: email, role: role);
}

const _tinyPdfData =
    'data:application/pdf;base64,JVBERi0xLjQK'; // minimal stub

void main() {
  group('UserModel — صلاحيات MS-SD و MoS-ITP', () {
    const dc = UserModel(
      id: 10,
      name: 'DC',
      email: 'dc@example.com',
      role: 'document_controller',
    );
    const engineer = UserModel(
      id: 11,
      name: 'Eng',
      email: 'eng@example.com',
      role: 'site_engineer',
    );
    const manager = UserModel(
      id: 12,
      name: 'Mgr',
      email: 'mgr@example.com',
      role: 'site_engineer_manager',
    );
    const opManager = UserModel(
      id: 13,
      name: 'Op',
      email: 'op@example.com',
      role: 'operation_manager',
    );
    const accountant = UserModel(
      id: 14,
      name: 'Acc',
      email: 'acc@example.com',
      role: 'accountant',
    );
    const primaryAdmin = UserModel(
      id: 15,
      name: 'Helal',
      email: UserModel.primaryAppAdminEmail,
      role: 'app_admin',
    );
    const otherAdmin = UserModel(
      id: 16,
      name: 'Admin',
      email: 'other@example.com',
      role: 'app_admin',
    );

    test('DC يرفع ولا يدير بعد الحفظ', () {
      expect(dc.canUploadMsSd, isTrue);
      expect(dc.canUploadMosItp, isTrue);
      expect(dc.canManageMsSdRecords, isFalse);
      expect(dc.canManageMosItpRecords, isFalse);
    });

    test('مهندس/مدير/عمليات يعرضون فقط', () {
      for (final u in [engineer, manager, opManager]) {
        expect(u.canUploadMsSd, isFalse);
        expect(u.canUploadMosItp, isFalse);
        expect(u.canViewMsSd, isTrue);
        expect(u.canViewMosItp, isTrue);
        expect(u.canManageMsSdRecords, isFalse);
        expect(u.canManageMosItpRecords, isFalse);
      }
    });

    test('المحاسب بلا وصول', () {
      expect(accountant.canViewMsSd, isFalse);
      expect(accountant.canViewMosItp, isFalse);
    });

    test('مسؤول التطبيق المحدد فقط يدير السجلات', () {
      expect(primaryAdmin.canManageMsSdRecords, isTrue);
      expect(primaryAdmin.canManageMosItpRecords, isTrue);
      expect(otherAdmin.canManageMsSdRecords, isFalse);
      expect(otherAdmin.canManageMosItpRecords, isFalse);
    });
  });

  group('IconVisibilityService — الأيقونات الجديدة', () {
    test('مهندس الموقع: MS-SD و MoS-ITP', () {
      final ids = IconVisibilityService.roleIcons['site_engineer']!
          .map((e) => e.id)
          .toList();
      expect(ids, containsAll(['ms_sd', 'mos_itp']));
    });

    test('مدير المشروعات والمشرف العام: MS-SD و MoS-ITP', () {
      for (final role in ['site_engineer_manager', 'general_supervisor']) {
        final ids = IconVisibilityService.roleIcons[role]!
            .map((e) => e.id)
            .toList();
        expect(ids, contains('ms_sd'));
        expect(ids, contains('mos_itp'));
      }
    });

    test('مدير العمليات و DC: الأيقونتان', () {
      for (final role in ['operation_manager', 'document_controller']) {
        final ids = IconVisibilityService.roleIcons[role]!
            .map((e) => e.id)
            .toList();
        expect(ids, contains('ms_sd'));
        expect(ids, contains('mos_itp'));
      }
    });

    test('المحاسب بلا MS-SD أو MoS-ITP', () {
      final ids = IconVisibilityService.roleIcons['accountant']!
          .map((e) => e.id)
          .toList();
      expect(ids, isNot(contains('ms_sd')));
      expect(ids, isNot(contains('mos_itp')));
    });

    test('مدير المشروعات: الأرصدة / المصروفات في آخر القائمة', () {
      final ids = IconVisibilityService.roleIcons['site_engineer_manager']!
          .map((e) => e.id)
          .toList();
      expect(ids, contains('accountant_finance'));
      expect(ids.last, 'accountant_finance');
    });

    test('المشرف العام بلا الأرصدة / المصروفات', () {
      final ids = IconVisibilityService.roleIcons['general_supervisor']!
          .map((e) => e.id)
          .toList();
      expect(ids, isNot(contains('accountant_finance')));
    });
  });

  group('نماذج البيانات', () {
    test('MsSdRecordModel.fromMap مع مرفقات', () {
      final m = MsSdRecordModel.fromMap({
        'id': 1,
        'project_id': 5,
        'kind': 'ms',
        'record_name': 'Submittal A',
        'notes': 'note',
        'attachments': [
          {
            'id': 10,
            'record_id': 1,
            'file_name': 'a.pdf',
            'file_mime': 'application/pdf',
            'file_data': _tinyPdfData,
          },
        ],
      });
      expect(m.id, 1);
      expect(m.kind, 'ms');
      expect(m.attachments, hasLength(1));
      expect(MsSdRecordModel.kindLabel('sd'), 'SD');
    });

    test('MosItpRecordModel.fromMap مع مرفقات', () {
      final m = MosItpRecordModel.fromMap({
        'id': 2,
        'project_id': 3,
        'kind': 'itp',
        'record_name': 'Plan B',
        'attachments': [
          {
            'id': 20,
            'record_id': 2,
            'file_name': 'b.pdf',
            'file_mime': 'application/pdf',
            'file_data': _tinyPdfData,
          },
        ],
      });
      expect(m.kind, 'itp');
      expect(MosItpRecordModel.kindLabel('mos'), 'MoS');
      expect(MosItpRecordModel.kindLabel('itp'), 'ITP');
    });
  });

  group('حد حجم الملف 5MB', () {
    test('يقبل 5MB ويرفض ما فوق', () {
      expect(msSdFileWithinLimit(kMsSdMaxFileBytes), isTrue);
      expect(msSdFileWithinLimit(kMsSdMaxFileBytes + 1), isFalse);
      expect(msSdMaxFileSizeLabel(), '5 ميجابايت');
    });
  });

  group('WebStorageService — تدفق MS-SD كامل', () {
    late WebStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = WebStorageService();
      await storage.getProjects(); // triggers _initData
    });

    test('إضافة → عرض بدون تدقيق → تدقيق للمسؤول → تعديل → حذف', () async {
      const dcId = 10;
      const projectId = 1;

      final recordId = await storage.addMsSdRecord(
        projectId: projectId,
        userId: dcId,
        userName: 'DC User',
        kind: MsSdRecordModel.kindMs,
        recordName: 'MS File 1',
        notes: 'test note',
        attachments: [
          {
            'fileName': 'doc.pdf',
            'fileMime': 'application/pdf',
            'fileData': _tinyPdfData,
          },
        ],
      );
      expect(recordId, greaterThan(0));

      final viewerList = await storage.listMsSdRecords(
        projectId: projectId,
        kind: MsSdRecordModel.kindMs,
        requesterEmail: 'viewer@example.com',
      );
      expect(viewerList, hasLength(1));
      expect(viewerList.first.recordName, 'MS File 1');
      expect(viewerList.first.userName, isNull);
      expect(viewerList.first.createdAt, isNull);
      expect(viewerList.first.attachments, hasLength(1));

      final adminList = await storage.listMsSdRecords(
        projectId: projectId,
        kind: MsSdRecordModel.kindMs,
        requesterEmail: UserModel.primaryAppAdminEmail,
      );
      expect(adminList.first.userName, 'DC User');
      expect(adminList.first.createdAt, isNotNull);

      await storage.updateMsSdRecord(
        recordId,
        requesterEmail: UserModel.primaryAppAdminEmail,
        recordName: 'MS File Updated',
        notes: 'updated',
      );
      final updated = await storage.listMsSdRecords(
        projectId: projectId,
        kind: MsSdRecordModel.kindMs,
        requesterEmail: UserModel.primaryAppAdminEmail,
      );
      expect(updated.first.recordName, 'MS File Updated');

      await expectLater(
        storage.updateMsSdRecord(
          recordId,
          requesterEmail: 'not-admin@example.com',
          recordName: 'Hack',
        ),
        throwsA(isA<Exception>()),
      );

      await storage.deleteMsSdRecord(
        recordId,
        requesterEmail: UserModel.primaryAppAdminEmail,
      );
      final empty = await storage.listMsSdRecords(
        projectId: projectId,
        kind: MsSdRecordModel.kindMs,
      );
      expect(empty, isEmpty);
    });

    test('الأحدث أولاً في القائمة', () async {
      await storage.addMsSdRecord(
        projectId: 1,
        userId: 1,
        userName: 'DC',
        kind: MsSdRecordModel.kindSd,
        recordName: 'Older',
        attachments: [
          {
            'fileName': 'a.pdf',
            'fileMime': 'application/pdf',
            'fileData': _tinyPdfData,
          },
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await storage.addMsSdRecord(
        projectId: 1,
        userId: 1,
        userName: 'DC',
        kind: MsSdRecordModel.kindSd,
        recordName: 'Newer',
        attachments: [
          {
            'fileName': 'b.pdf',
            'fileMime': 'application/pdf',
            'fileData': _tinyPdfData,
          },
        ],
      );
      final list = await storage.listMsSdRecords(
        projectId: 1,
        kind: MsSdRecordModel.kindSd,
      );
      expect(list.first.recordName, 'Newer');
      expect(list.last.recordName, 'Older');
    });
  });

  group('WebStorageService — تدفق MoS-ITP كامل', () {
    late WebStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = WebStorageService();
      await storage.getProjects();
    });

    test('MoS و ITP منفصلان حسب النوع', () async {
      await storage.addMosItpRecord(
        projectId: 2,
        userId: 10,
        userName: 'DC',
        kind: MosItpRecordModel.kindMos,
        recordName: 'MoS Doc',
        attachments: [
          {
            'fileName': 'mos.pdf',
            'fileMime': 'application/pdf',
            'fileData': _tinyPdfData,
          },
        ],
      );
      await storage.addMosItpRecord(
        projectId: 2,
        userId: 10,
        userName: 'DC',
        kind: MosItpRecordModel.kindItp,
        recordName: 'ITP Doc',
        attachments: [
          {
            'fileName': 'itp.pdf',
            'fileMime': 'application/pdf',
            'fileData': _tinyPdfData,
          },
        ],
      );

      final mos = await storage.listMosItpRecords(
        projectId: 2,
        kind: MosItpRecordModel.kindMos,
      );
      final itp = await storage.listMosItpRecords(
        projectId: 2,
        kind: MosItpRecordModel.kindItp,
      );
      expect(mos, hasLength(1));
      expect(itp, hasLength(1));
      expect(mos.first.recordName, 'MoS Doc');
      expect(itp.first.recordName, 'ITP Doc');

      await storage.deleteMosItpRecord(
        mos.first.id,
        requesterEmail: UserModel.primaryAppAdminEmail,
      );
      final mosAfter = await storage.listMosItpRecords(
        projectId: 2,
        kind: MosItpRecordModel.kindMos,
      );
      expect(mosAfter, isEmpty);
      expect(
        (await storage.listMosItpRecords(
          projectId: 2,
          kind: MosItpRecordModel.kindItp,
        )),
        hasLength(1),
      );
    });

    test('لا يُحذف آخر مرفق عند التعديل', () async {
      final id = await storage.addMosItpRecord(
        projectId: 3,
        userId: 10,
        userName: 'DC',
        kind: MosItpRecordModel.kindItp,
        recordName: 'Solo',
        attachments: [
          {
            'fileName': 'only.pdf',
            'fileMime': 'application/pdf',
            'fileData': _tinyPdfData,
          },
        ],
      );
      final rec = (await storage.listMosItpRecords(
        projectId: 3,
        kind: MosItpRecordModel.kindItp,
      )).first;
      await expectLater(
        storage.updateMosItpRecord(
          id,
          requesterEmail: UserModel.primaryAppAdminEmail,
          removeAttachmentIds: [rec.attachments.first.id],
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('HomeIconBuilder — بطاقات الأيقونات', () {
    testWidgets('MS-SD لـ DC يعرض وصف الرفع', (tester) async {
      const dc = UserModel(
        id: 1,
        name: 'DC',
        email: 'dc@example.com',
        role: 'document_controller',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: HomeIconBuilder.build(
                context: context,
                user: dc,
                iconId: 'ms_sd',
              ),
            ),
          ),
        ),
      );
      expect(find.text('MS-SD'), findsOneWidget);
      expect(find.textContaining('إضافة MS و SD'), findsOneWidget);
    });

    testWidgets('MoS-ITP لمهندس الموقع يعرض وصف العرض', (tester) async {
      const engineer = UserModel(
        id: 2,
        name: 'Eng',
        email: 'e@example.com',
        role: 'site_engineer',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: HomeIconBuilder.build(
                context: context,
                user: engineer,
                iconId: 'mos_itp',
              ),
            ),
          ),
        ),
      );
      expect(find.text('MoS-ITP'), findsOneWidget);
      expect(find.textContaining('عرض سجلات'), findsOneWidget);
    });
  });
}
