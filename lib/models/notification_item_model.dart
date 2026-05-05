class NotificationItemModel {
  final int id;
  final int recipientUserId;
  final String recipientRole;
  final String title;
  final String body;
  final String eventType;
  final int? actorUserId;
  final String? actorUserName;
  final String? projectName;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const NotificationItemModel({
    required this.id,
    required this.recipientUserId,
    required this.recipientRole,
    required this.title,
    required this.body,
    required this.eventType,
    this.actorUserId,
    this.actorUserName,
    this.projectName,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory NotificationItemModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      final s = v?.toString() ?? '';
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    DateTime? parseDateOrNull(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return NotificationItemModel(
      id: map['id'] as int,
      recipientUserId: map['recipient_user_id'] as int,
      recipientRole: (map['recipient_role'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      eventType: (map['event_type'] ?? '').toString(),
      actorUserId: map['actor_user_id'] as int?,
      actorUserName: map['actor_user_name']?.toString(),
      projectName: map['project_name']?.toString(),
      createdAt: parseDate(map['created_at']),
      isRead: (map['is_read'] == true) || (map['is_read'] == 1),
      readAt: parseDateOrNull(map['read_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_user_id': recipientUserId,
      'recipient_role': recipientRole,
      'title': title,
      'body': body,
      'event_type': eventType,
      'actor_user_id': actorUserId,
      'actor_user_name': actorUserName,
      'project_name': projectName,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'read_at': readAt?.toIso8601String(),
    };
  }
}
