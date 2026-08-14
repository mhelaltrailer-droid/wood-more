class MeetingNotificationModel {
  final int id;
  final int recipientUserId;
  final int meetingId;
  final String fileType;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const MeetingNotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.meetingId,
    required this.fileType,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory MeetingNotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    DateTime? parseDateOrNull(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return MeetingNotificationModel(
      id: map['id'] as int,
      recipientUserId: map['recipient_user_id'] as int,
      meetingId: map['meeting_id'] as int,
      fileType: (map['file_type'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      createdAt: parseDate(map['created_at']),
      isRead: map['is_read'] == true || map['is_read'] == 1,
      readAt: parseDateOrNull(map['read_at']),
    );
  }
}
