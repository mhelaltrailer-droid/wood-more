import 'pending_postpone_fine_action_model.dart';

/// صف تقرير تأجيل خطط مع بيانات الغرامة (من الخادم).
class PostponeFineReportRowModel {
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
  final String engineerFineTarget;
  final String? semFineTarget;
  final String? semFineAmount;
  final String? semNoFineReason;
  final String? semResolvedAt;
  final String contractorsInPlanLabel;

  const PostponeFineReportRowModel({
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
    this.semFineTarget,
    this.semFineAmount,
    this.semNoFineReason,
    this.semResolvedAt,
    required this.contractorsInPlanLabel,
  });

  factory PostponeFineReportRowModel.fromMap(Map<String, dynamic> m) {
    int pInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    int? pIntOpt(dynamic v) {
      if (v == null) return null;
      final i = v is int ? v : int.tryParse(v.toString());
      return i;
    }

    return PostponeFineReportRowModel(
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
      semFineTarget: m['sem_fine_target']?.toString(),
      semFineAmount: m['sem_fine_amount']?.toString(),
      semNoFineReason: m['sem_no_fine_reason']?.toString(),
      semResolvedAt: m['sem_resolved_at']?.toString(),
      contractorsInPlanLabel:
          (m['contractors_in_plan_label'] ?? m['contractorsInPlanLabel'] ?? '—')
              .toString(),
    );
  }

  bool get semResolved =>
      semResolvedAt != null && semResolvedAt!.trim().isNotEmpty;

  String get postponeReasonDisplay {
    final c = postponeCustomReason?.trim();
    if (c != null && c.isNotEmpty) return c;
    final l = postponeReasonLabel?.trim();
    if (l != null && l.isNotEmpty) return l;
    return postponeReasonKey?.trim().isNotEmpty == true
        ? postponeReasonKey!.trim()
        : '—';
  }

  String get engineerFineLabelAr =>
      PendingPostponeFineActionModel.fineTargetLabelAr(engineerFineTarget);

  String get semDecisionShort {
    if (!semResolved) return 'بانتظار قرار مدير المشروعات';
    final t = (semFineTarget ?? '').trim().toLowerCase();
    if (t == 'none') {
      final r = semNoFineReason?.trim();
      return r != null && r.isNotEmpty ? 'لا غرامة — $r' : 'لا غرامة';
    }
    if (t == 'owner' || t == 'contractor') {
      final a = semFineAmount?.trim();
      final party =
          t == 'owner' ? 'المالك' : 'المقاول';
      return (a != null && a.isNotEmpty)
          ? 'غرامة على $party: $a'
          : 'غرامة على $party';
    }
    return '—';
  }

  /// قيمة الغرامة الموقعة من مدير المشروعات (إن وُجدت).
  String get signedFineAmountColumn {
    if (!semResolved) return '—';
    final t = (semFineTarget ?? '').trim().toLowerCase();
    if (t == 'owner' || t == 'contractor') {
      final a = semFineAmount?.trim();
      return (a != null && a.isNotEmpty) ? a : '—';
    }
    return '—';
  }

  /// الطرف الموقع عليه الغرامة (بعد قرار مدير المشروعات).
  String get signedFinePartyColumn {
    if (!semResolved) return '—';
    final t = (semFineTarget ?? '').trim().toLowerCase();
    if (t == 'owner') return 'المالك';
    if (t == 'contractor') return 'المقاول';
    if (t == 'none') return '—';
    return '—';
  }
}
