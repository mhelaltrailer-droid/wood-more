/// تأجيل خطة عمل بانتظار قرار مدير المشروعات بشأن الغرامة.
class PendingPostponeFineActionModel {
  final int id;
  final int userId;
  final String userName;
  final int? projectId;
  final String? projectName;
  final String planDate;
  final String? postponeReasonKey;
  final String? postponeReasonLabel;
  final String? postponeCustomReason;
  final String? postponeNotes;
  final String? postponeReopenDate;
  /// owner | contractor | none
  final String engineerFineTarget;
  final DateTime createdAt;

  const PendingPostponeFineActionModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.projectId,
    this.projectName,
    required this.planDate,
    this.postponeReasonKey,
    this.postponeReasonLabel,
    this.postponeCustomReason,
    this.postponeNotes,
    this.postponeReopenDate,
    required this.engineerFineTarget,
    required this.createdAt,
  });

  factory PendingPostponeFineActionModel.fromMap(Map<String, dynamic> m) {
    int pInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    int? pIntOpt(dynamic v) {
      if (v == null) return null;
      final i = v is int ? v : int.tryParse(v.toString());
      return i;
    }

    return PendingPostponeFineActionModel(
      id: pInt(m['id']),
      userId: pInt(m['user_id'] ?? m['userId']),
      userName: (m['user_name'] ?? m['userName'] ?? '').toString(),
      projectId: pIntOpt(m['project_id'] ?? m['projectId']),
      projectName: m['project_name']?.toString() ?? m['projectName']?.toString(),
      planDate: (m['plan_date'] ?? m['planDate'] ?? '').toString(),
      postponeReasonKey: m['postpone_reason_key']?.toString(),
      postponeReasonLabel: m['postpone_reason_label']?.toString(),
      postponeCustomReason: m['postpone_custom_reason']?.toString(),
      postponeNotes: m['postpone_notes']?.toString(),
      postponeReopenDate: m['postpone_reopen_date']?.toString(),
      engineerFineTarget:
          (m['engineer_fine_target'] ?? m['engineerFineTarget'] ?? 'none')
              .toString(),
      createdAt: DateTime.tryParse(
            (m['created_at'] ?? m['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  static String fineTargetLabelAr(String key) {
    switch (key.trim()) {
      case 'owner':
        return 'المالك';
      case 'contractor':
        return 'المقاول';
      case 'none':
        return 'لا تستدعي';
      default:
        return key;
    }
  }

  String get postponeReasonDisplay {
    final c = postponeCustomReason?.trim();
    if (c != null && c.isNotEmpty) return c;
    final l = postponeReasonLabel?.trim();
    if (l != null && l.isNotEmpty) return l;
    return postponeReasonKey?.trim().isNotEmpty == true
        ? postponeReasonKey!.trim()
        : '—';
  }
}
