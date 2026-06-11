/// مرفق واحد ضمن سجل MS-SD.
class MsSdAttachmentModel {
  final int id;
  final int recordId;
  final String fileName;
  final String fileMime;
  final String fileData;
  final DateTime? createdAt;

  const MsSdAttachmentModel({
    required this.id,
    required this.recordId,
    required this.fileName,
    required this.fileMime,
    required this.fileData,
    this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'record_id': recordId,
        'file_name': fileName,
        'file_mime': fileMime,
        'file_data': fileData,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  factory MsSdAttachmentModel.fromMap(Map<String, dynamic> m) {
    int pInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    final ca = m['created_at'] ?? m['createdAt'];
    return MsSdAttachmentModel(
      id: pInt(m['id']),
      recordId: pInt(m['record_id'] ?? m['recordId']),
      fileName: (m['file_name'] ?? m['fileName'] ?? '').toString(),
      fileMime: (m['file_mime'] ?? m['fileMime'] ?? '').toString(),
      fileData: (m['file_data'] ?? m['fileData'] ?? '').toString(),
      createdAt: ca != null
          ? DateTime.tryParse(ca.toString())
          : null,
    );
  }
}

/// سجل MS أو SD مع مرفقاته.
class MsSdRecordModel {
  final int id;
  final int projectId;
  final int? userId;
  final String? userName;
  /// `ms` | `sd`
  final String kind;
  final String recordName;
  final String? notes;
  final DateTime? createdAt;
  final List<MsSdAttachmentModel> attachments;

  const MsSdRecordModel({
    required this.id,
    required this.projectId,
    this.userId,
    this.userName,
    required this.kind,
    required this.recordName,
    this.notes,
    this.createdAt,
    this.attachments = const [],
  });

  static const String kindMs = 'ms';
  static const String kindSd = 'sd';

  static String kindLabel(String kind) =>
      kind.toLowerCase() == kindSd ? 'SD' : 'MS';

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        if (userId != null) 'user_id': userId,
        if (userName != null) 'user_name': userName,
        'kind': kind,
        'record_name': recordName,
        'notes': notes,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        'attachments': attachments.map((a) => a.toMap()).toList(),
      };

  factory MsSdRecordModel.fromMap(Map<String, dynamic> m) {
    int pInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    int? pIntOpt(dynamic v) {
      if (v == null) return null;
      return v is int ? v : int.tryParse(v.toString());
    }
    final ca = m['created_at'] ?? m['createdAt'];
    final rawAtt = m['attachments'];
    final atts = <MsSdAttachmentModel>[];
    if (rawAtt is List) {
      for (final e in rawAtt) {
        if (e is Map) {
          atts.add(
            MsSdAttachmentModel.fromMap(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return MsSdRecordModel(
      id: pInt(m['id']),
      projectId: pInt(m['project_id'] ?? m['projectId']),
      userId: pIntOpt(m['user_id'] ?? m['userId']),
      userName: m['user_name']?.toString() ?? m['userName']?.toString(),
      kind: (m['kind'] ?? '').toString(),
      recordName: (m['record_name'] ?? m['recordName'] ?? '').toString(),
      notes: m['notes']?.toString(),
      createdAt:
          ca != null ? DateTime.tryParse(ca.toString()) : null,
      attachments: atts,
    );
  }
}
