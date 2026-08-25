/// صف تقرير سحب الخامات: مشروع + موقع عمل + مرحلة، مع التمييز بين طلب السحب
/// وإتمام السحب الفعلي وحالة إرفاق أذن الصرف &التسليم (من الخادم).
class MaterialWithdrawalReportRowModel {
  final int? projectId;
  final String projectName;
  final int? locationId;
  final String locationName;
  final String locationPath;
  final String locationType;
  final String phase;
  final String phaseLabel;
  final int? requestId;
  final String? requestCreatedAt;
  final String engineerUserName;
  final String semStatusLabel;
  final String? semReason;
  final String omStatusLabel;
  final String? omReason;
  final String? overallStatus;
  final String? fulfilledAt;
  final int? withdrawalId;
  final String? withdrawalCreatedAt;
  final String withdrawalUserName;
  final int disbursementFilesCount;
  final int deliveryFilesCount;
  final int attachmentsCount;
  final bool isCompleted;
  final String status;
  final String statusLabel;

  const MaterialWithdrawalReportRowModel({
    this.projectId,
    required this.projectName,
    this.locationId,
    required this.locationName,
    required this.locationPath,
    required this.locationType,
    required this.phase,
    required this.phaseLabel,
    this.requestId,
    this.requestCreatedAt,
    required this.engineerUserName,
    required this.semStatusLabel,
    this.semReason,
    required this.omStatusLabel,
    this.omReason,
    this.overallStatus,
    this.fulfilledAt,
    this.withdrawalId,
    this.withdrawalCreatedAt,
    required this.withdrawalUserName,
    required this.disbursementFilesCount,
    required this.deliveryFilesCount,
    required this.attachmentsCount,
    required this.isCompleted,
    required this.status,
    required this.statusLabel,
  });

  factory MaterialWithdrawalReportRowModel.fromMap(Map<String, dynamic> m) {
    int pInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    int? pIntOpt(dynamic v) =>
        v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    String pStr(dynamic v) => (v ?? '').toString();
    String? pStrOpt(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return MaterialWithdrawalReportRowModel(
      projectId: pIntOpt(m['project_id']),
      projectName: pStr(m['project_name']),
      locationId: pIntOpt(m['location_id']),
      locationName: pStr(m['location_name']),
      locationPath: pStr(m['location_path']),
      locationType: pStr(m['location_type']),
      phase: pStr(m['phase']),
      phaseLabel: pStr(m['phase_label']),
      requestId: pIntOpt(m['request_id']),
      requestCreatedAt: pStrOpt(m['request_created_at']),
      engineerUserName: pStr(m['engineer_user_name']),
      semStatusLabel: pStr(m['sem_status_label']),
      semReason: pStrOpt(m['sem_reason']),
      omStatusLabel: pStr(m['om_status_label']),
      omReason: pStrOpt(m['om_reason']),
      overallStatus: pStrOpt(m['overall_status']),
      fulfilledAt: pStrOpt(m['fulfilled_at']),
      withdrawalId: pIntOpt(m['withdrawal_id']),
      withdrawalCreatedAt: pStrOpt(m['withdrawal_created_at']),
      withdrawalUserName: pStr(m['withdrawal_user_name']),
      disbursementFilesCount: pInt(m['disbursement_files_count']),
      deliveryFilesCount: pInt(m['delivery_files_count']),
      attachmentsCount: pInt(m['attachments_count']),
      isCompleted: m['is_completed'] == true,
      status: pStr(m['status']),
      statusLabel: pStr(m['status_label']),
    );
  }

  /// نصّ عمود المرفقات: أذن الصرف &التسليم فقط.
  String get attachmentsLabel {
    if (withdrawalId == null) return 'لا يوجد';
    if (attachmentsCount == 0) return 'بدون مرفقات';
    return 'أذن الصرف &التسليم: $disbursementFilesCount';
  }

  /// من نفّذ السحب فعلياً، أو من طلبه إن لم يكتمل بعد.
  String get responsibleUserName {
    if (withdrawalUserName.trim().isNotEmpty) return withdrawalUserName;
    if (engineerUserName.trim().isNotEmpty) return engineerUserName;
    return '—';
  }

  /// سبب الرفض إن وُجد (من مدير المشروعات أو مدير العمليات).
  String? get rejectionReason => semReason ?? omReason;
}
