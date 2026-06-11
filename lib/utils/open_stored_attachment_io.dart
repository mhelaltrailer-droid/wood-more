import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// يكتب الملف مؤقتاً ويفتحه بتطبيق النظام. يُرجع null عند النجاح أو رسالة خطأ.
Future<String?> openStoredAttachment({
  required Uint8List bytes,
  required String fileName,
  String? dataUrl,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File(p.join(dir.path, safeName));
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFile.open(file.path);
  if (result.type == ResultType.done) return null;
  return result.message;
}
