class MeetingFileMeta {
  final String fileType;
  final String fileName;
  final DateTime uploadedAt;
  final String label;

  const MeetingFileMeta({
    required this.fileType,
    required this.fileName,
    required this.uploadedAt,
    required this.label,
  });

  factory MeetingFileMeta.fromMap(Map<String, dynamic> map) {
    return MeetingFileMeta(
      fileType: (map['file_type'] ?? '').toString(),
      fileName: (map['file_name'] ?? '').toString(),
      uploadedAt: DateTime.tryParse('${map['uploaded_at'] ?? ''}') ??
          DateTime.now(),
      label: (map['label'] ?? map['file_type'] ?? '').toString(),
    );
  }
}

class MeetingModel {
  final int id;
  final String meetingNumber;
  final String subject;
  final DateTime scheduledAt;
  final int createdByUserId;
  final String createdByUserName;
  final DateTime createdAt;
  final Map<String, MeetingFileMeta?> files;

  const MeetingModel({
    required this.id,
    required this.meetingNumber,
    required this.subject,
    required this.scheduledAt,
    required this.createdByUserId,
    required this.createdByUserName,
    required this.createdAt,
    required this.files,
  });

  MeetingFileMeta? fileOf(String fileType) => files[fileType];

  factory MeetingModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    final rawFiles = map['files'];
    final files = <String, MeetingFileMeta?>{};
    if (rawFiles is Map) {
      rawFiles.forEach((key, value) {
        final type = key.toString();
        if (value is Map) {
          files[type] = MeetingFileMeta.fromMap(
            Map<String, dynamic>.from(value),
          );
        } else {
          files[type] = null;
        }
      });
    }

    return MeetingModel(
      id: map['id'] as int,
      meetingNumber: (map['meeting_number'] ?? '').toString(),
      subject: (map['subject'] ?? '').toString(),
      scheduledAt: parseDate(map['scheduled_at']),
      createdByUserId: map['created_by_user_id'] as int? ?? 0,
      createdByUserName: (map['created_by_user_name'] ?? '').toString(),
      createdAt: parseDate(map['created_at']),
      files: files,
    );
  }
}
