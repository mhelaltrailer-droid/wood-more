import 'dart:convert';

import 'daily_report_model.dart';

/// مرفق اختياري مع التقرير المفصل (صورة أو ملف كـ data URI)
class DetailedReportAttachment {
  final String kind; // 'image' | 'file'
  final String? fileName;
  final String data;

  const DetailedReportAttachment({
    required this.kind,
    this.fileName,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (fileName != null && fileName!.trim().isNotEmpty) 'name': fileName!.trim(),
        'data': data,
      };

  factory DetailedReportAttachment.fromJson(Map<String, dynamic> m) {
    return DetailedReportAttachment(
      kind: (m['kind'] ?? 'file').toString(),
      fileName: m['name']?.toString(),
      data: (m['data'] ?? '').toString(),
    );
  }
}

List<DetailedReportAttachment> parseDetailedReportAttachments(Map<String, dynamic> m) {
  dynamic raw = m['attachments'] ?? m['attachments_json'];
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return [];
    }
  }
  if (raw is! List) return [];
  final out = <DetailedReportAttachment>[];
  for (final e in raw) {
    final a = DetailedReportAttachment.fromJson(Map<String, dynamic>.from(e as Map));
    if (a.data.isNotEmpty) {
      out.add(a);
    }
  }
  return out;
}

/// سطر واحد في التقرير المفصل: مرحلة + عدد عمال (المقاول والموقع اختياريان)
class DetailedReportLineModel {
  final int? id;
  final int? contractorId;
  final int contractorWorkersCount;
  final int selfWorkersCount;
  final int? zoneId;
  final int? buildingId;
  final int? locationId;
  final int phaseId;
  final int workersCount;

  const DetailedReportLineModel({
    this.id,
    this.contractorId,
    this.contractorWorkersCount = 0,
    this.selfWorkersCount = 0,
    this.zoneId,
    this.buildingId,
    this.locationId,
    required this.phaseId,
    required this.workersCount,
  });

  Map<String, dynamic> toJson() => {
        if (contractorId != null) 'contractorId': contractorId,
        'contractorWorkersCount': contractorWorkersCount,
        'selfWorkersCount': selfWorkersCount,
        if (zoneId != null) 'zoneId': zoneId,
        if (buildingId != null) 'buildingId': buildingId,
        if (locationId != null) 'locationId': locationId,
        'phaseId': phaseId,
        'workersCount': workersCount,
      };

  factory DetailedReportLineModel.fromMap(Map<String, dynamic> m) {
    int parse(dynamic v) => v is int ? v : int.parse(v.toString());
    final contractorIdRaw = m['contractor_id'] ?? m['contractorId'];
    return DetailedReportLineModel(
      id: m['id'] != null ? parse(m['id']) : null,
      contractorId: contractorIdRaw != null ? parse(contractorIdRaw) : null,
      contractorWorkersCount: parse(m['contractor_workers_count'] ?? m['contractorWorkersCount'] ?? 0),
      selfWorkersCount: parse(m['self_workers_count'] ?? m['selfWorkersCount'] ?? 0),
      zoneId: m['zone_id'] != null || m['zoneId'] != null ? parse(m['zone_id'] ?? m['zoneId']) : null,
      buildingId: m['building_id'] != null || m['buildingId'] != null ? parse(m['building_id'] ?? m['buildingId']) : null,
      locationId: m['location_id'] != null || m['locationId'] != null ? parse(m['location_id'] ?? m['locationId']) : null,
      phaseId: parse(m['phase_id'] ?? m['phaseId']),
      workersCount: parse(m['workers_count'] ?? m['workersCount']),
    );
  }
}

/// التقرير المفصل: رأس التقرير + السطور + ملخص الأعمال
/// عند اختيار "أخرى" يكون projectId فارغاً و projectName = "أخرى (ما كتبه المستخدم)"
class DetailedReportModel {
  final int? id;
  final int userId;
  final String userName;
  final DateTime reportDatetime;
  /// فارغ عند اختيار "أخرى" (يُستخدم projectName بدلاً منه)
  final int? projectId;
  /// عند "أخرى": "أخرى (النص المدخل)"؛ يُستخدم في التقارير بديلاً لاسم المشروع
  final String? projectName;
  final int? supervisorId;
  final DateTime? createdAt;
  final String? summary;
  final List<DetailedReportLineModel> lines;
  /// بنود الماليات (اختياري، عند استخدام صفحة التقرير المفصل - الماليات)
  final List<ExpenseItem> expenses;
  /// صور وملفات مرفقة مع الملخص (اختياري)
  final List<DetailedReportAttachment> attachments;

  const DetailedReportModel({
    this.id,
    required this.userId,
    required this.userName,
    required this.reportDatetime,
    this.projectId,
    this.projectName,
    this.supervisorId,
    this.createdAt,
    this.summary,
    this.lines = const [],
    this.expenses = const [],
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'reportDatetime': reportDatetime.toIso8601String(),
        if (projectId != null) 'projectId': projectId,
        if (projectName != null && projectName!.trim().isNotEmpty) 'projectName': projectName!.trim(),
        'supervisorId': supervisorId,
        if (summary != null && summary!.trim().isNotEmpty) 'summary': summary!.trim(),
        'lines': lines.map((e) => e.toJson()).toList(),
        if (expenses.isNotEmpty) 'expenses': expenses.map((e) => e.toJson()).toList(),
        if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(),
      };

  factory DetailedReportModel.fromMap(Map<String, dynamic> m) {
    int parse(dynamic v) => v is int ? v : int.parse(v.toString());
    final linesList = m['lines'] as List<dynamic>?;
    final lineModels = linesList != null
        ? linesList.map((e) => DetailedReportLineModel.fromMap(Map<String, dynamic>.from(e as Map))).toList()
        : <DetailedReportLineModel>[];
    final expensesList = m['expenses'] as List<dynamic>?;
    final expenseModels = expensesList != null
        ? expensesList.map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()
        : <ExpenseItem>[];
    final attachmentModels = parseDetailedReportAttachments(m);
    final projectIdRaw = m['project_id'] ?? m['projectId'];
    return DetailedReportModel(
      id: m['id'] != null ? parse(m['id']) : null,
      userId: parse(m['user_id'] ?? m['userId']),
      userName: m['user_name'] ?? m['userName'] as String,
      reportDatetime: DateTime.parse(m['report_datetime'] ?? m['reportDatetime'] as String),
      projectId: projectIdRaw != null ? parse(projectIdRaw) : null,
      projectName: m['project_name'] ?? m['projectName']?.toString(),
      supervisorId: m['supervisor_id'] != null || m['supervisorId'] != null
          ? parse(m['supervisor_id'] ?? m['supervisorId'])
          : null,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
      summary: m['summary']?.toString(),
      lines: lineModels,
      expenses: expenseModels,
      attachments: attachmentModels,
    );
  }
}
