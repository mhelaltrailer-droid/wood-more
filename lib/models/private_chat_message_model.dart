class PrivateChatMessageModel {
  final int id;
  final String senderEmail;
  final String senderName;
  final String receiverEmail;
  final String body;
  final DateTime createdAt;

  const PrivateChatMessageModel({
    required this.id,
    required this.senderEmail,
    required this.senderName,
    required this.receiverEmail,
    required this.body,
    required this.createdAt,
  });

  factory PrivateChatMessageModel.fromMap(Map<String, dynamic> map) {
    return PrivateChatMessageModel(
      id: map['id'] as int,
      senderEmail: (map['sender_email'] ?? '').toString(),
      senderName: (map['sender_name'] ?? '').toString(),
      receiverEmail: (map['receiver_email'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((map['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
