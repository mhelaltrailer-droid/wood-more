import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// حفظ وفتح أو مشاركة المرفق (PDF / DOC / صور) على الأجهزة المحلية.
Future<String?> saveReportsSysAttachment({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(dir.path, safeName));
    await file.writeAsBytes(bytes, flush: true);

    final lower = safeName.toLowerCase();
    final isDoc = lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx');

    if (isDoc) {
      final result = await OpenFile.open(file.path);
      if (result.type == ResultType.done) return null;
    }

    await Share.shareXFiles([XFile(file.path)], subject: fileName);
    return null;
  } catch (e) {
    return '$e';
  }
}
