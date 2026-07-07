class ProjectsDashboardNoteModel {
  final int id;
  final String authorRole;
  final int userId;
  final String userName;
  final String body;
  final String createdAt;
  final String createdAtDisplay;

  const ProjectsDashboardNoteModel({
    required this.id,
    required this.authorRole,
    required this.userId,
    required this.userName,
    required this.body,
    required this.createdAt,
    required this.createdAtDisplay,
  });

  factory ProjectsDashboardNoteModel.fromMap(Map<String, dynamic> m) {
    return ProjectsDashboardNoteModel(
      id: m['id'] is int ? m['id'] as int : int.parse(m['id'].toString()),
      authorRole: (m['authorRole'] ?? m['author_role'] ?? '').toString(),
      userId: m['userId'] is int
          ? m['userId'] as int
          : int.parse(m['userId'].toString()),
      userName: (m['userName'] ?? m['user_name'] ?? '').toString(),
      body: (m['body'] ?? '').toString(),
      createdAt: (m['createdAt'] ?? m['created_at'] ?? '').toString(),
      createdAtDisplay:
          (m['createdAtDisplay'] ?? m['created_at_display'] ?? '').toString(),
    );
  }
}
