class ShopDarwingNotificationModel {
  final int id;
  final int recipientUserId;
  final String title;
  final String body;
  final int? shopDrawingId;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  const ShopDarwingNotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.title,
    required this.body,
    this.shopDrawingId,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory ShopDarwingNotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      final s = v?.toString() ?? '';
      return DateTime.tryParse(s) ?? DateTime.now();
    }

    DateTime? parseDateOrNull(dynamic v) {
      final s = v?.toString();
      if (s == null || s.trim().isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return ShopDarwingNotificationModel(
      id: map['id'] as int,
      recipientUserId: map['recipient_user_id'] as int,
      title: (map['title'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      shopDrawingId: map['shop_drawing_id'] as int?,
      createdAt: parseDate(map['created_at']),
      isRead: (map['is_read'] == true) || (map['is_read'] == 1),
      readAt: parseDateOrNull(map['read_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_user_id': recipientUserId,
      'title': title,
      'body': body,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead ? 1 : 0,
      'read_at': readAt?.toIso8601String(),
    };
  }
}
