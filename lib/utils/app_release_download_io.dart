import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

Future<String> saveAppReleaseToFile({
  required List<int> bytes,
  required String fileName,
}) async {
  final dir = await getTemporaryDirectory();
  final safeName =
      fileName.trim().isEmpty ? 'wood_and_more_update.apk' : fileName;
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String?> openAppReleaseInstaller(String filePath) async {
  final result = await OpenFile.open(filePath);
  if (result.type != ResultType.done) {
    return result.message;
  }
  return null;
}

Future<bool> appReleaseFileExists(String filePath) async {
  if (filePath.trim().isEmpty) return false;
  return File(filePath).exists();
}

Future<String?> saveAndOpenAppRelease({
  required List<int> bytes,
  required String fileName,
}) async {
  final path = await saveAppReleaseToFile(bytes: bytes, fileName: fileName);
  return openAppReleaseInstaller(path);
}

Future<void> triggerBrowserDownload({
  required List<int> bytes,
  required String fileName,
}) async {}
