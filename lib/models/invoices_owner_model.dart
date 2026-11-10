import '../core/invoices_owner_constants.dart';

String? _optionalText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

bool _asBool(dynamic value) =>
    value == true || value == 1 || value == '1' || value == 'true';

String invoicesOwnerProjectHeading(String projectName, String? extractNumber) {
  final number = extractNumber?.trim() ?? '';
  if (number.isEmpty) return projectName;
  return '$projectName    رقم المستخلص: $number';
}

class InvoicesOwnerAttachmentModel {
  final int id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final String? dataBase64;

  const InvoicesOwnerAttachmentModel({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.dataBase64,
  });

  factory InvoicesOwnerAttachmentModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return InvoicesOwnerAttachmentModel(
      id: map['id'] as int,
      fileName: (map['file_name'] ?? map['fileName'] ?? '').toString(),
      mimeType: (map['mime_type'] ?? map['mimeType'] ?? '').toString(),
      sizeBytes: int.tryParse(
            (map['size_bytes'] ?? map['sizeBytes'] ?? '0').toString(),
          ) ??
          0,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      dataBase64:
          map['data_base64']?.toString() ?? map['dataBase64']?.toString(),
    );
  }

  Map<String, dynamic> toUploadMap() {
    return {
      'file_name': fileName,
      'mime_type': mimeType,
      'data_base64': dataBase64 ?? '',
      'size_bytes': sizeBytes,
    };
  }
}

class InvoicesOwnerActionModel {
  final int id;
  final int actorUserId;
  final String actorUserName;
  final String action;
  final String? comment;
  final DateTime createdAt;

  const InvoicesOwnerActionModel({
    required this.id,
    required this.actorUserId,
    required this.actorUserName,
    required this.action,
    this.comment,
    required this.createdAt,
  });

  factory InvoicesOwnerActionModel.fromMap(Map<String, dynamic> map) {
    return InvoicesOwnerActionModel(
      id: map['id'] as int,
      actorUserId: map['actor_user_id'] as int,
      actorUserName: (map['actor_user_name'] ?? '').toString(),
      action: (map['action'] ?? '').toString(),
      comment: map['comment']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get actionLabelAr {
    switch (action) {
      case 'created':
        return 'إنشاء وإرسال';
      case 'resubmit':
        return 'إعادة إرسال بعد التعديل';
      case 'approve':
        return 'اعتماد';
      case 'return':
        return 'إعادة + مراجعة';
      case 'delete_attachment':
        return 'حذف مرفق';
      case 'add_attachment':
        return 'إضافة مرفق';
      case 'replace_attachment':
        return 'استبدال مرفق';
      case 'update_om_checklist':
        return 'تعديل قائمة المراجعة';
      case 'extract_number':
        return 'تعديل رقم المستخلص';
      default:
        return action;
    }
  }

  /// تعديلات المسؤول الأساسي لا تظهر في مسار المستخلص (شاشة / PDF).
  bool get showOnInvoicePath => action != 'update_om_checklist';
}

/// عنصر في سجل التداول العام لوحدة Invoices (Owner).
class InvoicesOwnerActivityLogItem {
  final int id;
  final int invoiceId;
  final int actorUserId;
  final String actorUserName;
  final String action;
  final String? comment;
  final DateTime createdAt;
  final String projectName;
  final String? extractNumber;
  final String invoiceStatus;

  const InvoicesOwnerActivityLogItem({
    required this.id,
    required this.invoiceId,
    required this.actorUserId,
    required this.actorUserName,
    required this.action,
    this.comment,
    required this.createdAt,
    required this.projectName,
    this.extractNumber,
    required this.invoiceStatus,
  });

  factory InvoicesOwnerActivityLogItem.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic v) =>
        int.tryParse(v?.toString() ?? '') ?? (v is int ? v : 0);
    return InvoicesOwnerActivityLogItem(
      id: asInt(map['id']),
      invoiceId: asInt(map['invoice_id']),
      actorUserId: asInt(map['actor_user_id']),
      actorUserName: (map['actor_user_name'] ?? '').toString(),
      action: (map['action'] ?? '').toString(),
      comment: map['comment']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      projectName: (map['project_name'] ?? '').toString(),
      extractNumber: (map['extract_number'] ?? '').toString().trim().isEmpty
          ? null
          : (map['extract_number'] ?? '').toString().trim(),
      invoiceStatus: (map['invoice_status'] ?? '').toString(),
    );
  }

  String get actionLabelAr {
    switch (action) {
      case 'created':
        return 'إنشاء وإرسال';
      case 'resubmit':
        return 'إعادة إرسال بعد التعديل';
      case 'approve':
        return 'اعتماد';
      case 'return':
        return 'إعادة + مراجعة';
      case 'delete_attachment':
        return 'حذف مرفق';
      case 'add_attachment':
        return 'إضافة مرفق';
      case 'replace_attachment':
        return 'استبدال مرفق';
      case 'update_om_checklist':
        return 'تعديل قائمة المراجعة';
      case 'extract_number':
        return 'تعديل رقم المستخلص';
      default:
        return action;
    }
  }

  String get invoiceStatusLabelAr {
    switch (invoiceStatus) {
      case invoicesOwnerStatusPendingQs:
        return 'بانتظار QS';
      case invoicesOwnerStatusPendingTo:
        return 'بانتظار المكتب الفني';
      case invoicesOwnerStatusPendingPm:
        return 'بانتظار Projects Manager';
      case invoicesOwnerStatusPendingFinance:
        return 'بانتظار Finance';
      case invoicesOwnerStatusPendingOm:
        return 'بانتظار مدير العمليات';
      case invoicesOwnerStatusReturnedCreator:
        return 'معاد للمنشئ';
      case invoicesOwnerStatusApproved:
        return 'معتمد';
      default:
        return invoiceStatus;
    }
  }
}

class InvoicesOwnerOmChecklistEntry {
  final bool checked;
  final String note;

  const InvoicesOwnerOmChecklistEntry({
    this.checked = false,
    this.note = '',
  });

  factory InvoicesOwnerOmChecklistEntry.fromRaw(dynamic raw) {
    if (raw is Map) {
      final checkedRaw = raw['checked'] ?? raw['value'];
      final noteRaw = raw['note'] ?? raw['notes'] ?? '';
      return InvoicesOwnerOmChecklistEntry(
        checked: checkedRaw == true ||
            checkedRaw == 1 ||
            '$checkedRaw' == 'true',
        note: invoicesOwnerClampOmChecklistNote(noteRaw.toString()),
      );
    }
    return InvoicesOwnerOmChecklistEntry(
      checked: raw == true || raw == 1 || '$raw' == 'true',
    );
  }

  Map<String, dynamic> toMap() => {
        'checked': checked,
        'note': note,
      };
}

class InvoicesOwnerModel {
  final int id;
  final int? projectId;
  final String projectName;
  final String? extractNumber;
  final bool extractNumberLocked;
  final String? notes;
  final String status;
  final int createdByUserId;
  final String createdByUserName;
  final int? currentAssigneeUserId;
  final String? currentAssigneeUserName;
  final String? returnReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  /// إرسال المستخلص للعميل (يدوي — Monthly Checklist).
  final bool sentToClient;
  /// رد العميل على المستخلص (يدوي — يتطلب الإرسال أولاً).
  final bool clientReplied;
  /// تم التحصيل (يدوي — يتطلب رد العميل أولاً).
  final bool collected;
  /// قائمة مراجعة OM المحفوظة مع الاعتماد النهائي (✓ + ملاحظة البند).
  final Map<String, InvoicesOwnerOmChecklistEntry> omChecklist;
  final List<InvoicesOwnerAttachmentModel> attachments;
  final List<InvoicesOwnerActionModel> actions;

  const InvoicesOwnerModel({
    required this.id,
    this.projectId,
    required this.projectName,
    this.extractNumber,
    this.extractNumberLocked = false,
    this.notes,
    required this.status,
    required this.createdByUserId,
    required this.createdByUserName,
    this.currentAssigneeUserId,
    this.currentAssigneeUserName,
    this.returnReason,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.sentToClient = false,
    this.clientReplied = false,
    this.collected = false,
    this.omChecklist = const {},
    this.attachments = const [],
    this.actions = const [],
  });

  bool get hasOmChecklistSaved => omChecklist.isNotEmpty;

  List<InvoicesOwnerActionModel> get pathActions =>
      actions.where((a) => a.showOnInvoicePath).toList();
  /// ملاحظات المراحل للعرض التراكمي (منشئ + معتمدون).
  List<({String title, String body, DateTime at})> get stageNotesForDisplay {
    final out = <({String title, String body, DateTime at})>[];
    final creatorNotes = notes?.trim() ?? '';
    if (creatorNotes.isNotEmpty) {
      out.add((
        title: 'ملاحظات المنشئ ($createdByUserName)',
        body: creatorNotes,
        at: createdAt,
      ));
    }
    for (final a in actions) {
      if (a.action != 'approve') continue;
      final c = a.comment?.trim() ?? '';
      if (c.isEmpty) continue;
      out.add((
        title: 'ملاحظات ${a.actorUserName}',
        body: c,
        at: a.createdAt,
      ));
    }
    return out;
  }

  factory InvoicesOwnerModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    DateTime? parseDateOrNull(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final attachmentsRaw = map['attachments'];
    final actionsRaw = map['actions'];
    final omChecklistParsed = <String, InvoicesOwnerOmChecklistEntry>{};
    final rawCl = map['om_checklist'] ?? map['omChecklist'];
    if (rawCl is Map) {
      for (final e in rawCl.entries) {
        omChecklistParsed[e.key.toString()] =
            InvoicesOwnerOmChecklistEntry.fromRaw(e.value);
      }
    }

    return InvoicesOwnerModel(
      id: map['id'] as int,
      projectId: map['project_id'] as int?,
      projectName: (map['project_name'] ?? map['projectName'] ?? '').toString(),
      extractNumber: _optionalText(map['extract_number'] ?? map['extractNumber']),
      extractNumberLocked: _asBool(
        map['extract_number_locked'] ?? map['extractNumberLocked'],
      ),
      notes: map['notes']?.toString(),
      status: (map['status'] ?? '').toString(),
      createdByUserId: map['created_by_user_id'] as int,
      createdByUserName: (map['created_by_user_name'] ?? '').toString(),
      currentAssigneeUserId: map['current_assignee_user_id'] as int?,
      currentAssigneeUserName:
          map['current_assignee_user_name']?.toString(),
      returnReason: map['return_reason']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      approvedAt: parseDateOrNull(map['approved_at']),
      sentToClient: _asBool(map['sent_to_client'] ?? map['sentToClient']),
      clientReplied: _asBool(map['client_replied'] ?? map['clientReplied']),
      collected: _asBool(map['collected']),
      omChecklist: omChecklistParsed,
      attachments: attachmentsRaw is List
          ? attachmentsRaw
              .map(
                (e) => InvoicesOwnerAttachmentModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      actions: actionsRaw is List
          ? actionsRaw
              .map(
                (e) => InvoicesOwnerActionModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
    );
  }

  String get statusLabelAr {
    switch (status) {
      case invoicesOwnerStatusPendingQs:
        return 'بانتظار QS';
      case invoicesOwnerStatusPendingTo:
        return 'بانتظار المكتب الفني';
      case invoicesOwnerStatusPendingPm:
        return 'بانتظار Projects Manager';
      case invoicesOwnerStatusPendingFinance:
        return 'بانتظار Finance';
      case invoicesOwnerStatusPendingOm:
        return 'بانتظار مدير العمليات';
      case invoicesOwnerStatusReturnedCreator:
        return 'معاد للمنشئ';
      case invoicesOwnerStatusApproved:
        return 'معتمد';
      default:
        return status;
    }
  }
}

class InvoicesOwnerChainMember {
  final int userId;
  final String name;
  final String role;
  final String status;
  final String label;

  const InvoicesOwnerChainMember({
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    required this.label,
  });

  factory InvoicesOwnerChainMember.fromMap(Map<String, dynamic> map) {
    return InvoicesOwnerChainMember(
      userId: (map['user_id'] as num?)?.toInt() ?? 0,
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      label: (map['label'] ?? map['name'] ?? '').toString(),
    );
  }
}

class InvoicesOwnerChainRoute {
  final List<InvoicesOwnerChainMember> members;
  final int? defaultApproveUserId;
  final int? defaultReturnUserId;

  const InvoicesOwnerChainRoute({
    required this.members,
    this.defaultApproveUserId,
    this.defaultReturnUserId,
  });

  factory InvoicesOwnerChainRoute.fromMap(Map<String, dynamic> map) {
    final raw = map['members'];
    return InvoicesOwnerChainRoute(
      members: raw is List
          ? raw
              .map(
                (e) => InvoicesOwnerChainMember.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      defaultApproveUserId: (map['default_approve_user_id'] as num?)?.toInt(),
      defaultReturnUserId: (map['default_return_user_id'] as num?)?.toInt(),
    );
  }
}

/// صف في تبويب Monthly Checklist (مشروع نشط + حالة مستخلص الشهر).
class InvoicesOwnerMonthlyChecklistItem {
  final int checklistId;
  final int? projectId;
  final String projectName;
  final bool isOtherProject;
  final bool hasExtractThisMonth;
  final int? invoiceId;
  final String? extractNumber;
  final String? invoiceStatus;
  final bool started;
  final bool omApproved;
  final bool sentToClient;
  final bool clientReplied;
  final bool collected;
  final bool allStagesComplete;

  const InvoicesOwnerMonthlyChecklistItem({
    required this.checklistId,
    this.projectId,
    required this.projectName,
    this.isOtherProject = false,
    required this.hasExtractThisMonth,
    this.invoiceId,
    this.extractNumber,
    this.invoiceStatus,
    required this.started,
    required this.omApproved,
    required this.sentToClient,
    required this.clientReplied,
    this.collected = false,
    this.allStagesComplete = false,
  });

  String get displayProjectName {
    if (!isOtherProject) return projectName;
    final base = projectName.trim();
    if (base.isEmpty) return 'مشروع آخر';
    if (base.contains('مشروع آخر')) return base;
    return '$base (مشروع آخر)';
  }

  factory InvoicesOwnerMonthlyChecklistItem.fromMap(Map<String, dynamic> map) {
    return InvoicesOwnerMonthlyChecklistItem(
      checklistId: (map['checklist_id'] as num?)?.toInt() ??
          (map['checklistId'] as num?)?.toInt() ??
          0,
      projectId: (map['project_id'] as num?)?.toInt() ??
          (map['projectId'] as num?)?.toInt(),
      projectName: (map['project_name'] ?? map['projectName'] ?? '').toString(),
      isOtherProject: _asBool(
        map['is_other_project'] ?? map['isOtherProject'],
      ),
      hasExtractThisMonth: _asBool(
        map['has_extract_this_month'] ?? map['hasExtractThisMonth'],
      ),
      invoiceId: (map['invoice_id'] as num?)?.toInt() ??
          (map['invoiceId'] as num?)?.toInt(),
      extractNumber:
          _optionalText(map['extract_number'] ?? map['extractNumber']),
      invoiceStatus: _optionalText(
        map['invoice_status'] ?? map['invoiceStatus'],
      ),
      started: _asBool(map['started']),
      omApproved: _asBool(map['om_approved'] ?? map['omApproved']),
      sentToClient: _asBool(map['sent_to_client'] ?? map['sentToClient']),
      clientReplied: _asBool(map['client_replied'] ?? map['clientReplied']),
      collected: _asBool(map['collected']),
      allStagesComplete: _asBool(
        map['all_stages_complete'] ?? map['allStagesComplete'],
      ),
    );
  }

  InvoicesOwnerMonthlyChecklistItem copyWith({
    bool? sentToClient,
    bool? clientReplied,
    bool? collected,
    bool? allStagesComplete,
  }) {
    final nextSent = sentToClient ?? this.sentToClient;
    final nextReplied = clientReplied ?? this.clientReplied;
    final nextCollected = collected ?? this.collected;
    return InvoicesOwnerMonthlyChecklistItem(
      checklistId: checklistId,
      projectId: projectId,
      projectName: projectName,
      isOtherProject: isOtherProject,
      hasExtractThisMonth: hasExtractThisMonth,
      invoiceId: invoiceId,
      extractNumber: extractNumber,
      invoiceStatus: invoiceStatus,
      started: started,
      omApproved: omApproved,
      sentToClient: nextSent,
      clientReplied: nextReplied,
      collected: nextCollected,
      allStagesComplete: allStagesComplete ??
          (started &&
              omApproved &&
              nextSent &&
              nextReplied &&
              nextCollected),
    );
  }
}

class InvoicesOwnerMonthlyChecklistResult {
  final String month;
  final int year;
  final int monthNumber;
  final bool monthEnded;
  final bool completionColoringApplies;
  final List<InvoicesOwnerMonthlyChecklistItem> items;

  const InvoicesOwnerMonthlyChecklistResult({
    required this.month,
    required this.year,
    required this.monthNumber,
    this.monthEnded = false,
    this.completionColoringApplies = false,
    required this.items,
  });

  factory InvoicesOwnerMonthlyChecklistResult.fromMap(
    Map<String, dynamic> map,
  ) {
    final raw = map['items'];
    final month = (map['month'] ?? '').toString();
    final parts = month.split('-');
    final parsedYear = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final parsedMonth = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return InvoicesOwnerMonthlyChecklistResult(
      month: month,
      year: (map['year'] as num?)?.toInt() ?? parsedYear ?? DateTime.now().year,
      monthNumber: (map['month_number'] as num?)?.toInt() ??
          (map['monthNumber'] as num?)?.toInt() ??
          parsedMonth ??
          DateTime.now().month,
      monthEnded: _asBool(map['month_ended'] ?? map['monthEnded']),
      completionColoringApplies: _asBool(
        map['completion_coloring_applies'] ?? map['completionColoringApplies'],
      ),
      items: raw is List
          ? raw
              .map(
                (e) => InvoicesOwnerMonthlyChecklistItem.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
    );
  }
}
