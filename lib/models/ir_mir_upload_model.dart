/// سجل مرفق MIR أو IR (مهندس موقع).
class IrMirUploadModel {
  final int id;
  final int projectId;
  final int userId;
  final String userName;
  /// `mir` | `ir`
  final String kind;
  final String? mirName;
  final int? locationId;
  /// `first_fix` | `second_fix` | `finish` لـ IR فقط
  final String? phase;
  final String fileName;
  final String fileMime;
  /// data URL أو نص الملف كما خُزن
  final String fileData;
  final String? notes;
  final DateTime createdAt;

  const IrMirUploadModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.userName,
    required this.kind,
    this.mirName,
    this.locationId,
    this.phase,
    required this.fileName,
    required this.fileMime,
    required this.fileData,
    this.notes,
    required this.createdAt,
  });

  static const String kindMir = 'mir';
  static const String kindIr = 'ir';

  static const String phaseFirstFix = 'first_fix';
  static const String phaseSecondFix = 'second_fix';
  static const String phaseFinish = 'finish';

  static const List<String> irPhases = [
    phaseFirstFix,
    phaseSecondFix,
    phaseFinish,
  ];

  static String phaseLabelAr(String phase) {
    switch (phase) {
      case phaseFirstFix:
        return 'First fix';
      case phaseSecondFix:
        return 'Second fix';
      case phaseFinish:
        return 'Finish';
      default:
        return phase;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'user_id': userId,
        'user_name': userName,
        'kind': kind,
        'mir_name': mirName,
        'location_id': locationId,
        'phase': phase,
        'file_name': fileName,
        'file_mime': fileMime,
        'file_data': fileData,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory IrMirUploadModel.fromMap(Map<String, dynamic> m) {
    int pInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    int? pIntOpt(dynamic v) {
      if (v == null) return null;
      final i = v is int ? v : int.tryParse(v.toString());
      return i;
    }
    final mn = m['mir_name']?.toString() ?? m['mirName']?.toString();
    return IrMirUploadModel(
      id: pInt(m['id']),
      projectId: pInt(m['project_id'] ?? m['projectId']),
      userId: pInt(m['user_id'] ?? m['userId']),
      userName: (m['user_name'] ?? m['userName'] ?? '').toString(),
      kind: (m['kind'] ?? '').toString(),
      mirName: mn != null && mn.isEmpty ? null : mn,
      locationId: pIntOpt(m['location_id'] ?? m['locationId']),
      phase: m['phase']?.toString(),
      fileName: (m['file_name'] ?? m['fileName'] ?? '').toString(),
      fileMime: (m['file_mime'] ?? m['fileMime'] ?? '').toString(),
      fileData: (m['file_data'] ?? m['fileData'] ?? '').toString(),
      notes: m['notes']?.toString(),
      createdAt: DateTime.tryParse(
            (m['created_at'] ?? m['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}
