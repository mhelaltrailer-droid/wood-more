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

/// اسم مرفق داخلي لحفظ «ملخص ما تم تنفيذه اليوم» عندما لا يدعم الخادم العمود بعد.
const String kExecutedTodaySummaryAttachmentName = '__executed_today_summary__';
const String kManualWorkLocationsAttachmentName = '__manual_work_locations__';

bool isExecutedTodaySummaryAttachment(DetailedReportAttachment a) =>
    a.fileName == kExecutedTodaySummaryAttachmentName;

bool isManualWorkLocationsAttachment(DetailedReportAttachment a) =>
    a.fileName == kManualWorkLocationsAttachmentName;

bool isReportMetadataAttachment(DetailedReportAttachment a) =>
    isExecutedTodaySummaryAttachment(a) || isManualWorkLocationsAttachment(a);

String? decodeExecutedTodaySummaryData(String data) {
  final d = data.trim();
  if (d.isEmpty) return null;
  const utf8Prefix = 'data:text/plain;charset=utf-8,';
  if (d.startsWith(utf8Prefix)) {
    return Uri.decodeComponent(d.substring(utf8Prefix.length));
  }
  const b64Prefix = 'data:text/plain;base64,';
  if (d.startsWith(b64Prefix)) {
    try {
      return utf8.decode(base64Decode(d.substring(b64Prefix.length)));
    } catch (_) {}
  }
  return d;
}

String encodeExecutedTodaySummaryData(String text) =>
    'data:text/plain;charset=utf-8,${Uri.encodeComponent(text)}';

String? executedTodaySummaryFromAttachments(
  List<DetailedReportAttachment> attachments,
) {
  for (final a in attachments) {
    if (!isExecutedTodaySummaryAttachment(a)) continue;
    final decoded = decodeExecutedTodaySummaryData(a.data);
    if (decoded != null && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }
  }
  return null;
}

List<DetailedReportAttachment> withExecutedTodaySummaryAttachment(
  List<DetailedReportAttachment> attachments,
  String? summary,
) {
  final kept = attachments
      .where((a) => !isExecutedTodaySummaryAttachment(a))
      .toList();
  final text = summary?.trim();
  if (text == null || text.isEmpty) return kept;
  return [
    ...kept,
    DetailedReportAttachment(
      kind: 'metadata',
      fileName: kExecutedTodaySummaryAttachmentName,
      data: encodeExecutedTodaySummaryData(text),
    ),
  ];
}

List<String> manualWorkLocationsFromAttachments(
  List<DetailedReportAttachment> attachments,
) {
  for (final a in attachments) {
    if (!isManualWorkLocationsAttachment(a)) continue;
    final decoded = decodeExecutedTodaySummaryData(a.data);
    if (decoded == null || decoded.trim().isEmpty) continue;
    try {
      final list = jsonDecode(decoded) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {}
  }
  return const [];
}

List<DetailedReportLineModel> enrichLinesWithManualWorkLocations(
  List<DetailedReportLineModel> lines,
  List<DetailedReportAttachment> attachments,
) {
  final manualList = manualWorkLocationsFromAttachments(attachments);
  if (manualList.isEmpty) return lines;
  final out = <DetailedReportLineModel>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final fromDb = line.manualWorkLocation?.trim();
    if (fromDb != null && fromDb.isNotEmpty) {
      out.add(line);
      continue;
    }
    final fromMeta = i < manualList.length ? manualList[i].trim() : '';
    if (fromMeta.isEmpty) {
      out.add(line);
      continue;
    }
    out.add(
      DetailedReportLineModel(
        id: line.id,
        contractorId: line.contractorId,
        contractorWorkersCount: line.contractorWorkersCount,
        selfWorkersCount: line.selfWorkersCount,
        zoneId: line.zoneId,
        buildingId: line.buildingId,
        locationId: line.locationId,
        manualWorkLocation: fromMeta,
        phaseId: line.phaseId,
        workersCount: line.workersCount,
      ),
    );
  }
  return out;
}

List<DetailedReportAttachment> withManualWorkLocationsAttachment(
  List<DetailedReportAttachment> attachments,
  List<DetailedReportLineModel> lines,
) {
  final kept = attachments
      .where((a) => !isManualWorkLocationsAttachment(a))
      .toList();
  final payload = lines.map((l) => (l.manualWorkLocation ?? '').trim()).toList();
  if (payload.every((s) => s.isEmpty)) return kept;
  return [
    ...kept,
    DetailedReportAttachment(
      kind: 'metadata',
      fileName: kManualWorkLocationsAttachmentName,
      data: encodeExecutedTodaySummaryData(jsonEncode(payload)),
    ),
  ];
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
  /// موقع عمل يدوي مؤقت عند غياب هيكلة المشروع (خطة عمل الغد).
  final String? manualWorkLocation;
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
    this.manualWorkLocation,
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
        if (manualWorkLocation != null && manualWorkLocation!.trim().isNotEmpty) ...{
          'manualWorkLocation': manualWorkLocation!.trim(),
          'manual_work_location': manualWorkLocation!.trim(),
        },
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
      manualWorkLocation:
          m['manual_work_location']?.toString() ??
          m['manualWorkLocation']?.toString(),
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
  /// ملخص ما تم تنفيذه اليوم (خطة عمل الغد).
  final String? executedTodaySummary;
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
    this.executedTodaySummary,
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
        ...executedTodaySummaryJsonEntries(),
        'lines': lines.map((e) => e.toJson()).toList(),
        if (expenses.isNotEmpty) 'expenses': expenses.map((e) => e.toJson()).toList(),
        if (attachments.isNotEmpty) 'attachments': attachments.map((e) => e.toJson()).toList(),
      };

  /// إرسال الحقل بصيغتي camelCase و snake_case لتوافق الخادم.
  Map<String, String> executedTodaySummaryJsonEntries() {
    final t = executedTodaySummary?.trim();
    if (t == null || t.isEmpty) return const {};
    return {
      'executedTodaySummary': t,
      'executed_today_summary': t,
    };
  }

  static String? parseExecutedTodaySummary(
    Map<String, dynamic> m, {
    List<DetailedReportAttachment>? attachments,
  }) {
    for (final key in ['executed_today_summary', 'executedTodaySummary']) {
      final raw = m[key];
      if (raw == null) continue;
      final t = raw.toString().trim();
      if (t.isNotEmpty) return t;
    }
    final fromAttachments = executedTodaySummaryFromAttachments(
      attachments ?? parseDetailedReportAttachments(m),
    );
    if (fromAttachments != null) return fromAttachments;
    final plan = m['plan'];
    if (plan is Map) {
      return parseExecutedTodaySummary(Map<String, dynamic>.from(plan));
    }
    return null;
  }

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
      executedTodaySummary: parseExecutedTodaySummary(
        m,
        attachments: attachmentModels,
      ),
      lines: enrichLinesWithManualWorkLocations(
        lineModels,
        attachmentModels,
      ),
      expenses: expenseModels,
      attachments: attachmentModels,
    );
  }
}
