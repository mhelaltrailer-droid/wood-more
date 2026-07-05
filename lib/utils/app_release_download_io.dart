import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> saveAndOpenAppRelease({
  required List<int> bytes,
  required String fileName,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName = fileName.trim().isEmpty ? 'wood_and_more_update.apk' : fileName;
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFile.open(file.path);
  if (result.type != ResultType.done) {
    return result.message;
  }
  return null;
}

Future<void> triggerBrowserDownload({
  required List<int> bytes,
  required String fileName,
}) async {}
