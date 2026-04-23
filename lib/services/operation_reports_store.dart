import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OperationTrackingReport {
  final String reportNo;
  final String reportType;
  final String projectName;
  final String engineerName;
  final String stage;
  final String status;
  final String dateText;
  final String? submittedAtIso;

  const OperationTrackingReport({
    required this.reportNo,
    required this.reportType,
    required this.projectName,
    required this.engineerName,
    required this.stage,
    required this.status,
    required this.dateText,
    this.submittedAtIso,
  });

  Map<String, dynamic> toMap() {
    return {
      'reportNo': reportNo,
      'reportType': reportType,
      'projectName': projectName,
      'engineerName': engineerName,
      'stage': stage,
      'status': status,
      'dateText': dateText,
      'submittedAtIso': submittedAtIso,
    };
  }

  factory OperationTrackingReport.fromMap(Map<String, dynamic> map) {
    return OperationTrackingReport(
      reportNo: map['reportNo'] as String? ?? '',
      reportType: map['reportType'] as String? ?? '',
      projectName: map['projectName'] as String? ?? '',
      engineerName: map['engineerName'] as String? ?? '',
      stage: map['stage'] as String? ?? '',
      status: map['status'] as String? ?? '',
      dateText: map['dateText'] as String? ?? '',
      submittedAtIso: map['submittedAtIso'] as String?,
    );
  }
}

class OperationReportsStore {
  OperationReportsStore._();
  static const String _prefsKey = 'operation_tracking_reports_v1';
  static bool _loaded = false;

  static final ValueNotifier<List<OperationTrackingReport>> reports =
      ValueNotifier<List<OperationTrackingReport>>(_seedReports);

  static int _sequence = 2406;

  static const List<OperationTrackingReport> _seedReports = [
    OperationTrackingReport(
      reportNo: 'OP-2401',
      reportType: 'تقرير معاينة',
      projectName: 'مشروع التجمع',
      engineerName: 'أحمد علي',
      stage: 'مراجعة فنية',
      status: 'تحت المراجعة',
      dateText: '2026-04-12',
    ),
    OperationTrackingReport(
      reportNo: 'OP-2402',
      reportType: 'تقرير إثبات حالة',
      projectName: 'فيلا النخيل',
      engineerName: 'محمد سمير',
      stage: 'قرار المدير',
      status: 'بانتظار المدير',
      dateText: '2026-04-12',
    ),
    OperationTrackingReport(
      reportNo: 'OP-2403',
      reportType: 'تقرير تلفيات',
      projectName: 'مشروع الساحل',
      engineerName: 'محمود حسن',
      stage: 'تم الإغلاق',
      status: 'معتمد',
      dateText: '2026-04-11',
    ),
    OperationTrackingReport(
      reportNo: 'OP-2404',
      reportType: 'تقرير تلفيات',
      projectName: 'مشروع الجونة',
      engineerName: 'خالد عادل',
      stage: 'تعديل من المهندس',
      status: 'مرتجع للتعديل',
      dateText: '2026-04-10',
    ),
    OperationTrackingReport(
      reportNo: 'OP-2405',
      reportType: 'تقرير معاينة',
      projectName: 'فيلا الياسمين',
      engineerName: 'سعيد رفعت',
      stage: 'تم الإغلاق',
      status: 'مرفوض',
      dateText: '2026-04-10',
    ),
  ];

  static String _nextReportNo() {
    final no = 'OP-$_sequence';
    _sequence++;
    return no;
  }

  static Future<void> ensureLoaded({bool force = false}) async {
    if (force) _loaded = false;
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      reports.value = List<OperationTrackingReport>.from(_seedReports);
      _loaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final parsed = decoded
          .map((item) => OperationTrackingReport.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
      reports.value = parsed.isEmpty ? List<OperationTrackingReport>.from(_seedReports) : parsed;
      _syncSequenceFromReports(reports.value);
      _loaded = true;
    } catch (_) {
      reports.value = List<OperationTrackingReport>.from(_seedReports);
      _loaded = true;
    }
  }

  static void _syncSequenceFromReports(List<OperationTrackingReport> rows) {
    int maxNo = 2405;
    for (final row in rows) {
      final parts = row.reportNo.split('-');
      if (parts.length != 2) continue;
      final number = int.tryParse(parts[1]);
      if (number != null && number > maxNo) {
        maxNo = number;
      }
    }
    _sequence = maxNo + 1;
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(reports.value.map((r) => r.toMap()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  static Future<void> addSubmittedReport({
    required String reportType,
    required String projectName,
    required String engineerName,
    required DateTime submittedAt,
  }) async {
    await ensureLoaded();
    final current = List<OperationTrackingReport>.from(reports.value);
    current.insert(
      0,
      OperationTrackingReport(
        reportNo: _nextReportNo(),
        reportType: reportType,
        projectName: projectName,
        engineerName: engineerName,
        stage: 'مراجعة فنية',
        status: 'مرسل',
        dateText: submittedAt.toIso8601String().split('T').first,
        submittedAtIso: submittedAt.toIso8601String(),
      ),
    );
    reports.value = current;
    await _persist();
  }
}
