import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/contractor_model.dart';
import 'package:wood_and_more_app/models/detailed_report_model.dart';
import 'package:wood_and_more_app/models/project_location_model.dart';
import 'package:wood_and_more_app/utils/work_plan_tracking_display.dart';

void main() {
  group('formatWorkPlanLocationHierarchy', () {
    test('shows parent and child when nested', () {
      final parent = ProjectLocationModel(
        id: 1,
        projectId: 10,
        name: 'Villa77',
        type: 'folder',
      );
      final child = ProjectLocationModel(
        id: 2,
        projectId: 10,
        parentId: 1,
        name: 'Shed02',
        type: 'work_site',
      );
      final byId = {1: parent, 2: child};
      expect(
        formatWorkPlanLocationHierarchy(child, byId),
        'Villa77 (Shed02)',
      );
    });

    test('shows location name only when no parent', () {
      final loc = ProjectLocationModel(
        id: 3,
        projectId: 10,
        name: 'Block A',
        type: 'work_site',
      );
      expect(formatWorkPlanLocationHierarchy(loc, {3: loc}), 'Block A');
    });
  });

  group('workplaceLevel1ForLine', () {
    test('uses hierarchy when locationId is set', () {
      final parent = ProjectLocationModel(
        id: 1,
        projectId: 10,
        name: 'Zone1',
        type: 'folder',
      );
      final child = ProjectLocationModel(
        id: 2,
        projectId: 10,
        parentId: 1,
        name: 'Unit5',
        type: 'work_site',
      );
      final line = DetailedReportLineModel(
        locationId: 2,
        manualWorkLocation: 'يجب ألا يظهر',
        phaseId: 1,
        workersCount: 3,
      );
      expect(
        workplaceLevel1ForLine(line, {1: parent, 2: child}),
        'Zone1 (Unit5)',
      );
    });

    test('uses manual text when no locationId (project without structure)', () {
      final line = DetailedReportLineModel(
        manualWorkLocation: '  موقع مؤقت شمال الموقع  ',
        phaseId: 1,
        workersCount: 2,
      );
      expect(
        workplaceLevel1ForLine(line, {}),
        'موقع مؤقت شمال الموقع',
      );
    });

    test('falls back to manual when locationId missing from map', () {
      final line = DetailedReportLineModel(
        locationId: 99,
        manualWorkLocation: 'مبنى B يدوي',
        phaseId: 1,
        workersCount: 1,
      );
      expect(workplaceLevel1ForLine(line, {}), 'مبنى B يدوي');
    });

    test('returns em dash when no location and no manual text', () {
      final line = DetailedReportLineModel(phaseId: 1, workersCount: 0);
      expect(workplaceLevel1ForLine(line, {}), '—');
    });
  });

  group('formatExecutedTodaySummaryForReport', () {
    test('returns trimmed text when present', () {
      expect(
        formatExecutedTodaySummaryForReport('  أنجزنا أعمال السباكة  '),
        'أنجزنا أعمال السباكة',
      );
    });

    test('returns em dash when null or blank', () {
      expect(formatExecutedTodaySummaryForReport(null), '—');
      expect(formatExecutedTodaySummaryForReport(''), '—');
      expect(formatExecutedTodaySummaryForReport('   '), '—');
    });
  });

  group('executedTodayCellContent', () {
    test('uses save date and summary body', () {
      final cell = executedTodayCellContent(
        planSavedAt: DateTime(2026, 6, 23, 14, 30),
        executedTodaySummary: ' أنجزنا الدهان ',
      );
      expect(cell.dateLabel, '23/06/2026');
      expect(cell.body, 'أنجزنا الدهان');
      expect(cell.pdfText, '23/06/2026\nأنجزنا الدهان');
    });

    test('shows لايوجد when summary missing', () {
      final cell = executedTodayCellContent(
        planSavedAt: DateTime(2026, 6, 23),
        executedTodaySummary: null,
      );
      expect(cell.dateLabel, '23/06/2026');
      expect(cell.body, kExecutedTodayTrackingEmptyLabel);
    });

    test('date dash when createdAt missing', () {
      final cell = executedTodayCellContent(
        planSavedAt: null,
        executedTodaySummary: 'نص',
      );
      expect(cell.dateLabel, '—');
      expect(cell.body, 'نص');
    });
  });

  group('workPlanTrackingPdfColumnCount', () {
    test('tomorrow plan: base + executed today', () {
      expect(
        workPlanTrackingPdfColumnCount(
          showMaterials: false,
          showExecutedTodaySummary: true,
          showExecution: false,
        ),
        8,
      );
    });

    test('today plan: base + executed today + execution', () {
      expect(
        workPlanTrackingPdfColumnCount(
          showMaterials: false,
          showExecutedTodaySummary: true,
          showExecution: true,
        ),
        9,
      );
    });

    test('all optional columns enabled', () {
      expect(
        workPlanTrackingPdfColumnCount(
          showMaterials: true,
          showExecutedTodaySummary: true,
          showExecution: true,
        ),
        10,
      );
    });
  });

  group('DetailedReportModel.parseExecutedTodaySummary', () {
    test('reads camelCase key', () {
      expect(
        DetailedReportModel.parseExecutedTodaySummary({
          'executedTodaySummary': ' أنجزنا الدهان ',
        }),
        'أنجزنا الدهان',
      );
    });

    test('reads nested plan map from executed_plans snapshot', () {
      expect(
        DetailedReportModel.parseExecutedTodaySummary({
          'plan': {'executedTodaySummary': 'تركيب الأبواب'},
        }),
        'تركيب الأبواب',
      );
    });

    test('reads manual work locations from metadata attachment', () {
      final report = DetailedReportModel.fromMap({
        'id': 40,
        'user_id': 1,
        'user_name': 'مهندس',
        'report_datetime': '2026-06-11T00:00:00.000',
        'attachments': [
          {
            'kind': 'metadata',
            'name': kManualWorkLocationsAttachmentName,
            'data': encodeExecutedTodaySummaryData(
              '["موقع يدوي شمال المشروع"]',
            ),
          },
        ],
        'lines': [
          {
            'contractor_id': 14,
            'phase_id': 8,
            'workers_count': 1,
            'location_id': null,
          },
        ],
      });
      expect(report.lines.single.manualWorkLocation, 'موقع يدوي شمال المشروع');
      expect(
        workplaceLevel1ForLine(report.lines.single, {}),
        'موقع يدوي شمال المشروع',
      );
    });

    test('reads metadata attachment when server column is missing', () {
      final report = DetailedReportModel.fromMap({
        'id': 37,
        'user_id': 1,
        'user_name': 'مهندس',
        'report_datetime': '2026-06-13T00:00:00.000',
        'summary': 'خطة الغد',
        'attachments': [
          {
            'kind': 'metadata',
            'name': kExecutedTodaySummaryAttachmentName,
            'data': encodeExecutedTodaySummaryData('ملخص تجربة'),
          },
        ],
        'lines': [
          {'phase_id': 1, 'workers_count': 1},
        ],
      });
      expect(report.executedTodaySummary, 'ملخص تجربة');
      expect(
        formatExecutedTodaySummaryForReport(report.executedTodaySummary),
        'ملخص تجربة',
      );
    });
  });

  group('contractorDisplayNameForLine', () {
    test('uses embedded contractor_name from API', () {
      final line = DetailedReportLineModel(
        contractorId: 14,
        contractorName: 'حسام حسن',
        phaseId: 1,
        workersCount: 2,
      );
      expect(contractorDisplayNameForLine(line, {}), 'حسام حسن');
    });

    test('falls back to contractorById map', () {
      final line = DetailedReportLineModel(
        contractorId: 3,
        phaseId: 1,
        workersCount: 1,
      );
      final byId = {
        3: const ContractorModel(id: 3, name: 'مقاول تجريبي'),
      };
      expect(contractorDisplayNameForLine(line, byId), 'مقاول تجريبي');
    });

    test('returns dash when no contractor', () {
      final line = DetailedReportLineModel(phaseId: 1, workersCount: 1);
      expect(contractorDisplayNameForLine(line, {}), '—');
    });
  });

  group('end-to-end report row simulation (old server API shape)', () {
    test('tomorrow plan row shows manual location and executed today summary', () {
      final apiPayload = {
        'id': 99,
        'user_id': 667,
        'user_name': 'Test Site Engineer',
        'report_datetime': '2026-06-11T00:00:00.000',
        'project_id': 61,
        'project_name': 'Wood&More(head office)',
        'summary': 'تفاصيل خطة الغد',
        'attachments': [
          {
            'kind': 'metadata',
            'name': kExecutedTodaySummaryAttachmentName,
            'data': encodeExecutedTodaySummaryData('ملخص تنفيذ اليوم'),
          },
          {
            'kind': 'metadata',
            'name': kManualWorkLocationsAttachmentName,
            'data': encodeExecutedTodaySummaryData(
              '["موقع يدوي - الطابق الثاني"]',
            ),
          },
        ],
        'lines': [
          {
            'id': 1,
            'contractor_id': 14,
            'contractor_workers_count': 1,
            'self_workers_count': 1,
            'location_id': null,
            'phase_id': 8,
            'workers_count': 1,
          },
        ],
      };

      final report = DetailedReportModel.fromMap(apiPayload);
      final line = report.lines.single;

      expect(
        formatExecutedTodaySummaryForReport(report.executedTodaySummary),
        'ملخص تنفيذ اليوم',
      );
      expect(
        workplaceLevel1ForLine(line, {}),
        'موقع يدوي - الطابق الثاني',
      );
    });

    test('structured location still uses hierarchy over metadata', () {
      final parent = ProjectLocationModel(
        id: 1,
        projectId: 10,
        name: 'Villa 1',
        type: 'folder',
      );
      final child = ProjectLocationModel(
        id: 2,
        projectId: 10,
        parentId: 1,
        name: 'Shed01',
        type: 'work_site',
      );
      final byId = {1: parent, 2: child};
      final line = DetailedReportLineModel(
        locationId: 2,
        manualWorkLocation: 'يجب تجاهله',
        phaseId: 7,
        workersCount: 0,
      );
      expect(
        workplaceLevel1ForLine(line, byId),
        'Villa 1 (Shed01)',
      );
    });
  });

  group('DetailedReportModel parsing (API shape)', () {
    test('loads executedTodaySummary and manualWorkLocation from snake_case', () {
      final report = DetailedReportModel.fromMap({
        'id': 5,
        'user_id': 2,
        'user_name': 'مهندس',
        'report_datetime': '2026-06-11T00:00:00.000',
        'project_id': 3,
        'executed_today_summary': 'تم تركيب الأبواب',
        'summary': 'خطة الغد: دهان',
        'lines': [
          {
            'contractor_id': 1,
            'phase_id': 2,
            'workers_count': 4,
            'manual_work_location': 'الطابق الثاني يدوياً',
          },
        ],
      });
      expect(report.executedTodaySummary, 'تم تركيب الأبواب');
      expect(report.lines.single.manualWorkLocation, 'الطابق الثاني يدوياً');
      expect(
        workplaceLevel1ForLine(report.lines.single, {}),
        'الطابق الثاني يدوياً',
      );
      expect(
        formatExecutedTodaySummaryForReport(report.executedTodaySummary),
        'تم تركيب الأبواب',
      );
    });
  });
}
