class ProjectsDashboardSheetModel {
  final int id;
  final String fileName;
  final String fileMime;
  final String? fileData;
  final String sheetName;
  final List<List<String>> rowsJson;
  final int uploadedByUserId;
  final String uploadedByUserName;
  final int? updatedByUserId;
  final String? updatedByUserName;
  final String createdAt;
  final String updatedAt;
  final String? updatedAtDisplay;

  const ProjectsDashboardSheetModel({
    required this.id,
    required this.fileName,
    required this.fileMime,
    this.fileData,
    required this.sheetName,
    required this.rowsJson,
    required this.uploadedByUserId,
    required this.uploadedByUserName,
    this.updatedByUserId,
    this.updatedByUserName,
    required this.createdAt,
    required this.updatedAt,
    this.updatedAtDisplay,
  });

  static List<List<String>> _parseRows(dynamic raw) {
    if (raw is! List) return [['']];
    return raw
        .map(
          (row) => (row is List ? row : [])
              .map((cell) => cell?.toString() ?? '')
              .toList(),
        )
        .toList();
  }

  factory ProjectsDashboardSheetModel.fromMap(Map<String, dynamic> m) {
    int? parseOptInt(dynamic v) {
      if (v == null) return null;
      return v is int ? v : int.tryParse(v.toString());
    }

    return ProjectsDashboardSheetModel(
      id: m['id'] is int ? m['id'] as int : int.parse(m['id'].toString()),
      fileName: (m['fileName'] ?? m['file_name'] ?? '').toString(),
      fileMime: (m['fileMime'] ?? m['file_mime'] ?? '').toString(),
      fileData: m['fileData']?.toString() ?? m['file_data']?.toString(),
      sheetName: (m['sheetName'] ?? m['sheet_name'] ?? 'Sheet1').toString(),
      rowsJson: _parseRows(m['rowsJson'] ?? m['rows_json']),
      uploadedByUserId: m['uploadedByUserId'] is int
          ? m['uploadedByUserId'] as int
          : int.parse(m['uploadedByUserId'].toString()),
      uploadedByUserName:
          (m['uploadedByUserName'] ?? m['uploaded_by_user_name'] ?? '').toString(),
      updatedByUserId: parseOptInt(m['updatedByUserId'] ?? m['updated_by_user_id']),
      updatedByUserName:
          (m['updatedByUserName'] ?? m['updated_by_user_name'])?.toString(),
      createdAt: (m['createdAt'] ?? m['created_at'] ?? '').toString(),
      updatedAt: (m['updatedAt'] ?? m['updated_at'] ?? '').toString(),
      updatedAtDisplay:
          (m['updatedAtDisplay'] ?? m['updated_at_display'])?.toString(),
    );
  }
}
