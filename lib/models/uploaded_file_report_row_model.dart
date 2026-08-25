/// صف تقرير الملفات المرفوعة: اسم المشروع، تاريخ الرفع، المستخدم الرافع،
/// ونوع المرفق (IR / MIR / MS / SD / MoS / ITP / Shop-Drawing / PO / أذون السحب).
class UploadedFileReportRowModel {
  final String source;
  final int? recordId;
  final String attachmentRef;
  final int? projectId;
  final String projectName;
  final String? uploadedAt;
  final int? userId;
  final String userName;
  final String kindCode;
  final String kindLabel;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// سياق إضافي حسب المصدر: مسار موقع العمل، أو اسم السجل (MIR-002 / SD-001)...
  final String contextLabel;

  const UploadedFileReportRowModel({
    required this.source,
    this.recordId,
    required this.attachmentRef,
    this.projectId,
    required this.projectName,
    this.uploadedAt,
    this.userId,
    required this.userName,
    required this.kindCode,
    required this.kindLabel,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.contextLabel,
  });

  factory UploadedFileReportRowModel.fromMap(Map<String, dynamic> m) {
    int pInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
    int? pIntOpt(dynamic v) =>
        v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    String pStr(dynamic v) => (v ?? '').toString();

    return UploadedFileReportRowModel(
      source: pStr(m['source']),
      recordId: pIntOpt(m['record_id']),
      attachmentRef: pStr(m['attachment_ref']),
      projectId: pIntOpt(m['project_id']),
      projectName: pStr(m['project_name']),
      uploadedAt: m['uploaded_at']?.toString(),
      userId: pIntOpt(m['user_id']),
      userName: pStr(m['user_name']),
      kindCode: pStr(m['kind_code']),
      kindLabel: pStr(m['kind_label']),
      fileName: pStr(m['file_name']),
      mimeType: pStr(m['mime_type']),
      sizeBytes: pInt(m['size_bytes']),
      contextLabel: pStr(m['context_label']),
    );
  }

  String get sizeLabel {
    if (sizeBytes <= 0) return '—';
    if (sizeBytes < 1024) return '$sizeBytes بايت';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} ك.ب';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} م.ب';
  }
}

/// أنواع المرفقات المتاحة في فلتر تقرير الملفات (نفس رموز الخادم).
const uploadedFileKindFilters = <String, String>{
  'IR': 'IR',
  'MIR': 'MIR',
  'MS': 'MS',
  'SD': 'SD',
  'MOS': 'MoS',
  'ITP': 'ITP',
  'SHOP_DRAWING': 'Shop-Drawing',
  'PO': 'PO',
  'DISBURSEMENT_PERMIT': 'أذن الصرف &التسليم',
};
