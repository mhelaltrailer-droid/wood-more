import '../core/shop_drawing_constants.dart';

class ShopDrawingAttachmentModel {
  final int id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final String? dataBase64;

  const ShopDrawingAttachmentModel({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.dataBase64,
  });

  factory ShopDrawingAttachmentModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return ShopDrawingAttachmentModel(
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

class ShopDrawingActionModel {
  final int id;
  final int actorUserId;
  final String actorUserName;
  final String action;
  final String? comment;
  final DateTime createdAt;

  const ShopDrawingActionModel({
    required this.id,
    required this.actorUserId,
    required this.actorUserName,
    required this.action,
    this.comment,
    required this.createdAt,
  });

  factory ShopDrawingActionModel.fromMap(Map<String, dynamic> map) {
    return ShopDrawingActionModel(
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
      case 'pm_approve':
        return 'اعتماد مدير المشروعات';
      case 'pm_return':
        return 'إعادة + مراجعة';
      case 'om_approve':
        return 'اعتماد / حفظ نهائي';
      default:
        return action;
    }
  }
}

class ShopDrawingModel {
  static const String statusPendingPm = 'pending_pm';
  static const String statusReturnedToTo = 'returned_to_to';
  static const String statusPendingOm = 'pending_om';
  static const String statusApproved = 'approved';

  final int id;
  final int? projectId;
  final String projectName;
  final String? notes;
  final String status;
  final String documentType;
  final int createdByUserId;
  final String createdByUserName;
  final int? currentAssigneeUserId;
  final String? currentAssigneeUserName;
  final String? returnReason;
  final String? externalUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final List<ShopDrawingAttachmentModel> attachments;
  final List<ShopDrawingActionModel> actions;

  const ShopDrawingModel({
    required this.id,
    this.projectId,
    required this.projectName,
    this.notes,
    required this.status,
    this.documentType = shopDrawingDocumentTypeShopDrawing,
    required this.createdByUserId,
    required this.createdByUserName,
    this.currentAssigneeUserId,
    this.currentAssigneeUserName,
    this.returnReason,
    this.externalUrl,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.attachments = const [],
    this.actions = const [],
  });

  factory ShopDrawingModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    DateTime? parseDateOrNull(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final attachmentsRaw = map['attachments'];
    final actionsRaw = map['actions'];

    return ShopDrawingModel(
      id: map['id'] as int,
      projectId: map['project_id'] as int?,
      projectName: (map['project_name'] ?? map['projectName'] ?? '').toString(),
      notes: map['notes']?.toString(),
      status: (map['status'] ?? '').toString(),
      documentType: shopDrawingNormalizeDocumentTypeFromMap(map),
      createdByUserId: map['created_by_user_id'] as int,
      createdByUserName: (map['created_by_user_name'] ?? '').toString(),
      currentAssigneeUserId: map['current_assignee_user_id'] as int?,
      currentAssigneeUserName:
          map['current_assignee_user_name']?.toString(),
      returnReason: map['return_reason']?.toString(),
      externalUrl: map['external_url']?.toString() ?? map['externalUrl']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      approvedAt: parseDateOrNull(map['approved_at']),
      attachments: attachmentsRaw is List
          ? attachmentsRaw
              .map(
                (e) => ShopDrawingAttachmentModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      actions: actionsRaw is List
          ? actionsRaw
              .map(
                (e) => ShopDrawingActionModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
    );
  }

  String get documentTypeLabel => shopDrawingDocumentTypeLabel(documentType);

  String get statusLabelAr {
    switch (status) {
      case statusPendingPm:
        return 'بانتظار مدير المشروعات';
      case statusReturnedToTo:
        return 'معاد للمكتب الفني';
      case statusPendingOm:
        return 'بانتظار مدير العمليات';
      case statusApproved:
        return 'معتمد';
      default:
        return status;
    }
  }
}

String shopDrawingNormalizeDocumentTypeFromMap(Map<String, dynamic> map) {
  final raw = (map['document_type'] ?? map['documentType'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  if (raw == shopDrawingDocumentTypePo) return shopDrawingDocumentTypePo;
  return shopDrawingDocumentTypeShopDrawing;
}
