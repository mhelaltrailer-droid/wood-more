import '../core/invoices_owner_constants.dart';

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
      default:
        return action;
    }
  }
}

class InvoicesOwnerModel {
  final int id;
  final int? projectId;
  final String projectName;
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
  final List<InvoicesOwnerAttachmentModel> attachments;
  final List<InvoicesOwnerActionModel> actions;

  const InvoicesOwnerModel({
    required this.id,
    this.projectId,
    required this.projectName,
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
    this.attachments = const [],
    this.actions = const [],
  });

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

    return InvoicesOwnerModel(
      id: map['id'] as int,
      projectId: map['project_id'] as int?,
      projectName: (map['project_name'] ?? map['projectName'] ?? '').toString(),
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
