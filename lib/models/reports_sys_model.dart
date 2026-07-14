class ReportsSysAttachmentModel {
  final int id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
  final String? dataBase64;

  const ReportsSysAttachmentModel({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    this.dataBase64,
  });

  factory ReportsSysAttachmentModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return ReportsSysAttachmentModel(
      id: map['id'] as int,
      fileName: (map['file_name'] ?? map['fileName'] ?? '').toString(),
      mimeType: (map['mime_type'] ?? map['mimeType'] ?? '').toString(),
      sizeBytes: int.tryParse(
            (map['size_bytes'] ?? map['sizeBytes'] ?? '0').toString(),
          ) ??
          0,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      dataBase64: map['data_base64']?.toString() ?? map['dataBase64']?.toString(),
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

class ReportsSysReviewerModel {
  final int userId;
  final String userName;
  final DateTime reviewedAt;
  final String action;

  const ReportsSysReviewerModel({
    required this.userId,
    required this.userName,
    required this.reviewedAt,
    required this.action,
  });

  factory ReportsSysReviewerModel.fromMap(Map<String, dynamic> map) {
    return ReportsSysReviewerModel(
      userId: map['user_id'] as int,
      userName: (map['user_name'] ?? '').toString(),
      reviewedAt: DateTime.tryParse(map['reviewed_at']?.toString() ?? '') ??
          DateTime.now(),
      action: (map['action'] ?? '').toString(),
    );
  }
}

class ReportsSysActionModel {
  final int id;
  final int actorUserId;
  final String actorUserName;
  final String action;
  final String? comment;
  final int? fromUserId;
  final int? toUserId;
  final String? toUserName;
  final DateTime createdAt;

  const ReportsSysActionModel({
    required this.id,
    required this.actorUserId,
    required this.actorUserName,
    required this.action,
    this.comment,
    this.fromUserId,
    this.toUserId,
    this.toUserName,
    required this.createdAt,
  });

  factory ReportsSysActionModel.fromMap(Map<String, dynamic> map) {
    return ReportsSysActionModel(
      id: map['id'] as int,
      actorUserId: map['actor_user_id'] as int,
      actorUserName: (map['actor_user_name'] ?? '').toString(),
      action: (map['action'] ?? '').toString(),
      comment: map['comment']?.toString(),
      fromUserId: map['from_user_id'] as int?,
      toUserId: map['to_user_id'] as int?,
      toUserName: map['to_user_name']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get actionLabelAr {
    switch (action) {
      case 'created':
        return 'إنشاء';
      case 'submit':
        return 'إرسال للمراجعة';
      case 'resubmit':
        return 'إعادة إرسال بعد التعديل';
      case 'forward':
        return 'توجيه بعد الاطلاع';
      case 'return':
        return 'إرجاع للتعديل';
      case 'reject':
        return 'رفض';
      case 'archive':
        return 'أرشفة';
      default:
        return action;
    }
  }
}

class ReportsSysModel {
  static const String statusDraft = 'draft';
  static const String statusPendingReview = 'pending_review';
  static const String statusReturnedForEdit = 'returned_for_edit';
  static const String statusArchived = 'archived';
  static const String statusRejected = 'rejected';

  static const List<String> reportTypes = [
    'تقرير معاينة',
    'تقرير إثبات حالة',
    'تقرير تلفيات',
    'تقرير عطلة',
    'استلام /معاينة خامات',
  ];

  static const int otherProjectId = -1;
  static const String otherProjectLabel = 'مشروع اخر';
  static const int maxAttachmentBytes = 5 * 1024 * 1024;

  /// مستخدمون لا يظهرون في قائمة «المسند إليه».
  static const Set<String> hiddenAssigneeEmails = {
    'cipherpath@proton.me', // cipherpath
    'shalaby', // Eng/M.shalaby
    'mahatowab@gmail.com', // Eng/Maha
    'mouhamedhelal.cor@gmail.com', // Manager Tester
  };

  static String _normalizeAssigneeKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s/_-]+'), '');

  /// هل يُستبعد المستخدم من قائمة المسند إليه (بالبريد أو الاسم الظاهر).
  static bool isHiddenFromAssigneeList({
    required String email,
    required String name,
  }) {
    final e = email.trim().toLowerCase();
    if (hiddenAssigneeEmails.contains(e)) return true;
    if (e.contains('cipherpath')) return true;

    final compact = _normalizeAssigneeKey(name);
    const nameNeedles = [
      'cipherpath',
      'engmshalaby',
      'mshalaby',
      'engmaha',
      'managertester',
      'testsitengineer',
    ];
    for (final needle in nameNeedles) {
      if (compact.contains(needle)) return true;
    }
    return false;
  }

  final int id;
  final String reportName;
  final String reportType;
  final String summary;
  final String? notes;
  final String status;
  final int createdByUserId;
  final String createdByUserName;
  final int? currentAssigneeUserId;
  final String? currentAssigneeUserName;
  final int? sourceReportId;
  final int? projectId;
  final String projectName;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? rejectedAt;
  final List<ReportsSysAttachmentModel> attachments;
  final List<ReportsSysActionModel> actions;
  final List<ReportsSysReviewerModel> reviewers;

  const ReportsSysModel({
    required this.id,
    required this.reportName,
    required this.reportType,
    required this.summary,
    this.notes,
    required this.status,
    required this.createdByUserId,
    required this.createdByUserName,
    this.currentAssigneeUserId,
    this.currentAssigneeUserName,
    this.sourceReportId,
    this.projectId,
    this.projectName = '',
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.rejectedAt,
    this.attachments = const [],
    this.actions = const [],
    this.reviewers = const [],
  });

  factory ReportsSysModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    DateTime? parseDateOrNull(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    final attachmentsRaw = map['attachments'];
    final actionsRaw = map['actions'];
    final reviewersRaw = map['reviewers'];

    return ReportsSysModel(
      id: map['id'] as int,
      reportName: (map['report_name'] ?? map['reportName'] ?? '').toString(),
      reportType: (map['report_type'] ?? map['reportType'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      notes: map['notes']?.toString(),
      status: (map['status'] ?? '').toString(),
      createdByUserId: map['created_by_user_id'] as int,
      createdByUserName: (map['created_by_user_name'] ?? '').toString(),
      currentAssigneeUserId: map['current_assignee_user_id'] as int?,
      currentAssigneeUserName: map['current_assignee_user_name']?.toString(),
      sourceReportId: map['source_report_id'] as int?,
      projectId: map['project_id'] as int?,
      projectName: (map['project_name'] ?? map['projectName'] ?? '').toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
      archivedAt: parseDateOrNull(map['archived_at']),
      rejectedAt: parseDateOrNull(map['rejected_at']),
      attachments: attachmentsRaw is List
          ? attachmentsRaw
              .map(
                (e) => ReportsSysAttachmentModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      actions: actionsRaw is List
          ? actionsRaw
              .map(
                (e) => ReportsSysActionModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
      reviewers: reviewersRaw is List
          ? reviewersRaw
              .map(
                (e) => ReportsSysReviewerModel.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
    );
  }

  String get statusLabelAr {
    switch (status) {
      case statusDraft:
        return 'مسودة';
      case statusPendingReview:
        return 'بانتظار المراجعة';
      case statusReturnedForEdit:
        return 'مُعاد للتعديل';
      case statusArchived:
        return 'مؤرشف';
      case statusRejected:
        return 'مرفوض';
      default:
        return status;
    }
  }

  bool canEditBy(int userId) {
    return userId == createdByUserId &&
        (status == statusDraft || status == statusReturnedForEdit) &&
        currentAssigneeUserId == userId;
  }

  bool canActBy(int userId) {
    return status == statusPendingReview && currentAssigneeUserId == userId;
  }

  bool get isTerminal => status == statusArchived || status == statusRejected;
}
