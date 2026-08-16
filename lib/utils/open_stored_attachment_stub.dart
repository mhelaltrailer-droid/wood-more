import 'dart:html' as html;
import 'dart:typed_data';

/// على الويب: فتح المرفق عبر Blob في تبويب جديد (data URL غير مدعوم في url_launcher).
Future<String?> openStoredAttachment({
  required Uint8List bytes,
  required String fileName,
  String? dataUrl,
}) async {
  if (bytes.isEmpty) return 'empty';
  try {
    final mime = _mimeType(fileName: fileName, dataUrl: dataUrl);
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..rel = 'noopener noreferrer'
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    // لا نلغي الرابط فوراً حتى يكتمل تحميل التبويب الجديد.
    Future<void>.delayed(const Duration(minutes: 2), () {
      html.Url.revokeObjectUrl(url);
    });
    return null;
  } catch (e) {
    return '$e';
  }
}

String _mimeType({required String fileName, String? dataUrl}) {
  final fromUrl = _mimeFromDataUrl(dataUrl);
  if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;
  return _mimeFromFileName(fileName);
}

String? _mimeFromDataUrl(String? dataUrl) {
  if (dataUrl == null || !dataUrl.startsWith('data:')) return null;
  final comma = dataUrl.indexOf(',');
  if (comma <= 5) return null;
  final header = dataUrl.substring(5, comma);
  for (final part in header.split(';')) {
    final value = part.trim();
    if (value.contains('/')) return value;
  }
  return null;
}

String _mimeFromFileName(String fileName) {
  final ext = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'txt':
      return 'text/plain';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    default:
      return 'application/octet-stream';
  }
}
