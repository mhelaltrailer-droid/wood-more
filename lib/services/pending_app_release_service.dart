import 'package:shared_preferences/shared_preferences.dart';

class PendingAppRelease {
  final String apkPath;
  final String versionLabel;
  final String fileName;
  final int sizeBytes;

  const PendingAppRelease({
    required this.apkPath,
    required this.versionLabel,
    required this.fileName,
    required this.sizeBytes,
  });
}

class PendingAppReleaseService {
  static const _pathKey = 'pending_apk_path';
  static const _versionKey = 'pending_apk_version';
  static const _fileNameKey = 'pending_apk_file_name';
  static const _sizeKey = 'pending_apk_size_bytes';

  Future<PendingAppRelease?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey);
    if (path == null || path.trim().isEmpty) return null;
    return PendingAppRelease(
      apkPath: path,
      versionLabel: prefs.getString(_versionKey) ?? '',
      fileName: prefs.getString(_fileNameKey) ?? 'app-release.apk',
      sizeBytes: prefs.getInt(_sizeKey) ?? 0,
    );
  }

  Future<void> save(PendingAppRelease pending) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, pending.apkPath);
    await prefs.setString(_versionKey, pending.versionLabel);
    await prefs.setString(_fileNameKey, pending.fileName);
    await prefs.setInt(_sizeKey, pending.sizeBytes);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
    await prefs.remove(_versionKey);
    await prefs.remove(_fileNameKey);
    await prefs.remove(_sizeKey);
  }
}
