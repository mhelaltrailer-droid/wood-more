import 'dart:io';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'app_release_install_messages.dart';
import 'app_release_install_permission.dart';

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

String installSettingsOpenedMessage() {
  return '$installSettingsOpenedPrefixتم فتح إعدادات Android. فعّل «السماح بتثبيت التطبيقات من هذا المصدر» '
      'ثم اضغط «تثبيت الآن» مرة أخرى.';
}

Future<String?> _ensureInstallPermissionOrOpenSettings() async {
  if (!Platform.isAndroid) return null;
  if (await canInstallAppReleases()) return null;
  await openAppReleaseInstallPermissionSettings();
  return installSettingsOpenedMessage();
}

Future<String?> openAppReleaseInstaller(String filePath) async {
  final permissionMessage = await _ensureInstallPermissionOrOpenSettings();
  if (permissionMessage != null) return permissionMessage;

  final result = await OpenFile.open(filePath);
  if (result.type != ResultType.done) {
    final message = result.message;
    if (message.contains('REQUEST_INSTALL_PACKAGES')) {
      await openAppReleaseInstallPermissionSettings();
      return installSettingsOpenedMessage();
    }
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
