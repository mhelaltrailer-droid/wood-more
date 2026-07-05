// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String> saveAppReleaseToFile({
  required List<int> bytes,
  required String fileName,
}) async {
  await triggerBrowserDownload(bytes: bytes, fileName: fileName);
  return '';
}

Future<String?> openAppReleaseInstaller(String filePath) async {
  return null;
}

Future<bool> appReleaseFileExists(String filePath) async => false;

Future<String?> saveAndOpenAppRelease({
  required List<int> bytes,
  required String fileName,
}) async {
  await triggerBrowserDownload(bytes: bytes, fileName: fileName);
  return null;
}

Future<void> triggerBrowserDownload({
  required List<int> bytes,
  required String fileName,
}) async {
  final safeName =
      fileName.trim().isEmpty ? 'wood_and_more_update.apk' : fileName;
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', safeName)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
