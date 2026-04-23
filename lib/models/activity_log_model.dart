class ActivityLogModel {
  final int id;
  final DateTime createdAt;
  final String actionType;
  final String actionLabel;
  final String endpoint;
  final String method;
  final String? userName;
  final String? userEmail;
  final int? userId;
  final int statusCode;
  final String details;

  const ActivityLogModel({
    required this.id,
    required this.createdAt,
    required this.actionType,
    required this.actionLabel,
    required this.endpoint,
    required this.method,
    required this.statusCode,
    required this.details,
    this.userName,
    this.userEmail,
    this.userId,
  });

  factory ActivityLogModel.fromMap(Map<String, dynamic> m) {
    int parseInt(dynamic v, {int fallback = 0}) {
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    final createdRaw = (m['created_at'] ?? m['createdAt'] ?? '').toString();
    final parsed = DateTime.tryParse(createdRaw) ?? DateTime.now();
    return ActivityLogModel(
      id: parseInt(m['id']),
      createdAt: parsed.toLocal(),
      actionType: (m['action_type'] ?? m['actionType'] ?? '').toString(),
      actionLabel: (m['action_label'] ?? m['actionLabel'] ?? '').toString(),
      endpoint: (m['endpoint'] ?? '').toString(),
      method: (m['method'] ?? '').toString(),
      statusCode: parseInt(m['status_code'] ?? m['statusCode']),
      details: (m['details'] ?? '').toString(),
      userName: m['user_name']?.toString(),
      userEmail: m['user_email']?.toString(),
      userId: m['user_id'] == null ? null : parseInt(m['user_id']),
    );
  }
}
