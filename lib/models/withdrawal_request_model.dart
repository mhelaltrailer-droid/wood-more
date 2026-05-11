/// طلب سحب خامات بانتظار موافقة مدير التشغيل ومدير المشروعات.
class WithdrawalRequestModel {
  final int id;
  final int projectId;
  final int locationId;
  final String phase;
  final int engineerUserId;
  final String engineerUserName;
  final String locationPathLabel;
  final String semStatus;
  final String omStatus;
  final String? semReason;
  final String? omReason;
  final DateTime? semRespondedAt;
  final DateTime? omRespondedAt;
  final String overallStatus;
  final DateTime? fulfilledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// يُملأ من API عند قائمة الطلبات للمدير (اسم المشروع).
  final String? projectName;

  const WithdrawalRequestModel({
    required this.id,
    required this.projectId,
    required this.locationId,
    required this.phase,
    required this.engineerUserId,
    required this.engineerUserName,
    required this.locationPathLabel,
    required this.semStatus,
    required this.omStatus,
    this.semReason,
    this.omReason,
    this.semRespondedAt,
    this.omRespondedAt,
    required this.overallStatus,
    this.fulfilledAt,
    required this.createdAt,
    required this.updatedAt,
    this.projectName,
  });

  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  bool get isOpen =>
      fulfilledAt == null &&
      (overallStatus == statusPending || overallStatus == statusApproved);

  bool get isPendingOverall => overallStatus == statusPending;
  bool get isApprovedOverall => overallStatus == statusApproved;
  bool get isRejectedOverall => overallStatus == statusRejected;

  factory WithdrawalRequestModel.fromMap(Map<String, dynamic> m) {
    DateTime? p(dynamic v) {
      final s = v?.toString();
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    int pInt(dynamic v) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return WithdrawalRequestModel(
      id: pInt(m['id']),
      projectId: pInt(m['project_id'] ?? m['projectId']),
      locationId: pInt(m['location_id'] ?? m['locationId']),
      phase: (m['phase'] ?? 'first_fix').toString(),
      engineerUserId: pInt(m['engineer_user_id'] ?? m['engineerUserId']),
      engineerUserName:
          (m['engineer_user_name'] ?? m['engineerUserName'] ?? '').toString(),
      locationPathLabel:
          (m['location_path_label'] ?? m['locationPathLabel'] ?? '').toString(),
      semStatus: (m['sem_status'] ?? m['semStatus'] ?? statusPending).toString(),
      omStatus: (m['om_status'] ?? m['omStatus'] ?? statusPending).toString(),
      semReason: m['sem_reason']?.toString() ?? m['semReason']?.toString(),
      omReason: m['om_reason']?.toString() ?? m['omReason']?.toString(),
      semRespondedAt: p(m['sem_responded_at'] ?? m['semRespondedAt']),
      omRespondedAt: p(m['om_responded_at'] ?? m['omRespondedAt']),
      overallStatus:
          (m['overall_status'] ?? m['overallStatus'] ?? statusPending).toString(),
      fulfilledAt: p(m['fulfilled_at'] ?? m['fulfilledAt']),
      createdAt: p(m['created_at'] ?? m['createdAt']) ?? DateTime.now(),
      updatedAt: p(m['updated_at'] ?? m['updatedAt']) ?? DateTime.now(),
      projectName: m['project_name']?.toString() ?? m['projectName']?.toString(),
    );
  }
}
