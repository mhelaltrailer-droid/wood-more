import 'dart:html' as html;
import 'dart:typed_data';

/// تحميل المرفق على الويب (PDF / DOC / صور).
Future<String?> saveReportsSysAttachment({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  try {
    final blob = html.Blob(
      [bytes],
      mimeType ?? 'application/octet-stream',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return null;
  } catch (e) {
    return '$e';
  }
}
