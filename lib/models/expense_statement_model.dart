/// بيان صرف عهدة (بند واحد) — بانتظار الاعتماد / معتمد / مرفوض
class ExpenseStatementModel {
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  /// البريد المصرح له باعتماد/رفض بيانات الصرف.
  static const String approverEmail = 'abdelrhmanellaithy828@gmail.com';

  final int id;
  final int submitterUserId;
  final String submitterUserName;
  final String submitterRole;
  final int balanceUserId;
  final int? projectId;
  final String? projectName;
  final String description;
  final double amount;
  final String? imagePath;
  final String status;
  final String? rejectionReason;
  final int? respondedByUserId;
  final String? respondedByUserName;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final String source;

  const ExpenseStatementModel({
    required this.id,
    required this.submitterUserId,
    required this.submitterUserName,
    required this.submitterRole,
    required this.balanceUserId,
    this.projectId,
    this.projectName,
    required this.description,
    required this.amount,
    this.imagePath,
    required this.status,
    this.rejectionReason,
    this.respondedByUserId,
    this.respondedByUserName,
    this.respondedAt,
    required this.createdAt,
    this.source = 'engineer',
  });

  bool get isPending => status == statusPending;
  bool get isApproved => status == statusApproved;
  bool get isRejected => status == statusRejected;

  String get statusLabelAr {
    switch (status) {
      case statusApproved:
        return 'معتمد';
      case statusRejected:
        return 'تم الرفض';
      default:
        return 'بانتظار الاعتماد';
    }
  }

  factory ExpenseStatementModel.fromMap(Map<String, dynamic> map) {
    int? pInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    double pDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }

    DateTime? pDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return ExpenseStatementModel(
      id: pInt(map['id']) ?? 0,
      submitterUserId: pInt(map['submitter_user_id'] ?? map['submitterUserId']) ?? 0,
      submitterUserName:
          (map['submitter_user_name'] ?? map['submitterUserName'] ?? '').toString(),
      submitterRole: (map['submitter_role'] ?? map['submitterRole'] ?? '').toString(),
      balanceUserId: pInt(map['balance_user_id'] ?? map['balanceUserId']) ?? 0,
      projectId: pInt(map['project_id'] ?? map['projectId']),
      projectName: map['project_name']?.toString() ?? map['projectName']?.toString(),
      description: (map['description'] ?? '').toString(),
      amount: pDouble(map['amount']),
      imagePath: map['image_path']?.toString() ?? map['imagePath']?.toString(),
      status: (map['status'] ?? statusPending).toString(),
      rejectionReason:
          map['rejection_reason']?.toString() ?? map['rejectionReason']?.toString(),
      respondedByUserId: pInt(map['responded_by_user_id'] ?? map['respondedByUserId']),
      respondedByUserName: map['responded_by_user_name']?.toString() ??
          map['respondedByUserName']?.toString(),
      respondedAt: pDate(map['responded_at'] ?? map['respondedAt']),
      createdAt: pDate(map['created_at'] ?? map['createdAt']) ?? DateTime.now(),
      source: (map['source'] ?? 'engineer').toString(),
    );
  }
}
