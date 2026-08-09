import 'dart:convert';
import 'dart:typed_data';

/// وصف مرفق واحد كما يعيده الخادم من /attachments — بدون بايتات الملف.
class NotificationAttachmentModel {
  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// 'image' | 'pdf' | 'file' — يحدد طريقة العرض.
  final String kind;

  /// وصف عربي اختياري (مثل "أذن الصرف" أو "بند صرف: ...").
  final String? label;

  /// false لملفات لا تُنقل عبر الواجهة (نسخ APK مثلاً).
  final bool canOpen;

  const NotificationAttachmentModel({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.kind,
    this.label,
    this.canOpen = true,
  });

  bool get isImage => kind == 'image';

  factory NotificationAttachmentModel.fromMap(Map<String, dynamic> map) {
    return NotificationAttachmentModel(
      id: (map['id'] ?? '').toString(),
      fileName: (map['file_name'] ?? 'مرفق').toString(),
      mimeType: (map['mime_type'] ?? 'application/octet-stream').toString(),
      sizeBytes: int.tryParse('${map['size_bytes'] ?? 0}') ?? 0,
      kind: (map['kind'] ?? 'file').toString(),
      label: map['label']?.toString(),
      canOpen: map['can_open'] != false,
    );
  }
}

/// نتيجة سرد مرفقات سجل واحد.
class NotificationAttachmentList {
  final String source;
  final int recordId;
  final String title;
  final List<NotificationAttachmentModel> items;

  const NotificationAttachmentList({
    required this.source,
    required this.recordId,
    required this.title,
    required this.items,
  });

  factory NotificationAttachmentList.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'];
    return NotificationAttachmentList(
      source: (map['source'] ?? '').toString(),
      recordId: int.tryParse('${map['record_id'] ?? 0}') ?? 0,
      title: (map['title'] ?? '').toString(),
      items: rawItems is List
          ? rawItems
              .map((e) => NotificationAttachmentModel.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ))
              .toList()
          : const [],
    );
  }
}

/// بايتات مرفق واحد بعد جلبه من الخادم.
class NotificationAttachmentFile {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const NotificationAttachmentFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  factory NotificationAttachmentFile.fromMap(Map<String, dynamic> map) {
    return NotificationAttachmentFile(
      fileName: (map['file_name'] ?? 'مرفق').toString(),
      mimeType: (map['mime_type'] ?? 'application/octet-stream').toString(),
      bytes: base64Decode((map['data_base64'] ?? '').toString()),
    );
  }
}
