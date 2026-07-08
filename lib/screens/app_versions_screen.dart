import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_release_info_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/pending_app_release_service.dart';
import '../services/storage_service.dart';
import '../utils/app_release_download.dart';
import '../widgets/app_release_install_bottom_sheet.dart';

/// شاشة إصدارات التطبيق — تحديث للمستخدمين ورفع APK للمسؤول الأساسي.
class AppVersionsScreen extends StatefulWidget {
  final UserModel currentUser;

  const AppVersionsScreen({super.key, required this.currentUser});

  @override
  State<AppVersionsScreen> createState() => _AppVersionsScreenState();
}

class _AppVersionsScreenState extends State<AppVersionsScreen> {
  final _versionController = TextEditingController();
  final _pendingService = PendingAppReleaseService();
  AppReleaseInfoModel? _releaseInfo;
  PendingAppRelease? _pendingInstall;
  String? _deviceVersion;
  String? _pickedFileName;
  List<int>? _pickedBytes;
  bool _loading = true;
  bool _downloading = false;
  bool _uploading = false;
  double? _uploadProgress;
  double? _downloadProgress;
  String? _transferStatus;
  String? _error;

  bool get _usesApi => getStorage() is ApiStorageService;
  bool get _canUpload => widget.currentUser.canManageAppVersions && _usesApi;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPendingInstall();
  }

  Future<void> _loadPendingInstall() async {
    if (kIsWeb) return;
    final pending = await _pendingService.load();
    if (pending == null) {
      if (mounted) setState(() => _pendingInstall = null);
      return;
    }
    final exists = await appReleaseFileExists(pending.apkPath);
    if (!exists) {
      await _pendingService.clear();
      if (mounted) setState(() => _pendingInstall = null);
      return;
    }
    if (mounted) setState(() => _pendingInstall = pending);
  }

  Future<void> _clearPendingInstall() async {
    await _pendingService.clear();
    if (mounted) setState(() => _pendingInstall = null);
  }

  Future<void> _savePendingInstall({
    required String apkPath,
    required String versionLabel,
    required String fileName,
    required int sizeBytes,
  }) async {
    final pending = PendingAppRelease(
      apkPath: apkPath,
      versionLabel: versionLabel,
      fileName: fileName,
      sizeBytes: sizeBytes,
    );
    await _pendingService.save(pending);
    if (mounted) setState(() => _pendingInstall = pending);
  }

  Future<String?> _openPendingInstaller() async {
    final pending = _pendingInstall;
    if (pending == null) return 'لا يوجد ملف محفوظ للتثبيت';
    if (!await appReleaseFileExists(pending.apkPath)) {
      await _clearPendingInstall();
      return 'انتهت صلاحية الملف المحمّل — أعد التنزيل';
    }
    return openAppReleaseInstaller(pending.apkPath);
  }

  Future<void> _showInstallBottomSheet({
    required String versionLabel,
    required int sizeBytes,
  }) async {
    if (!mounted) return;
    await AppReleaseInstallBottomSheet.show(
      context,
      versionLabel: versionLabel,
      fileSizeLabel: _formatBytes(sizeBytes),
      onInstallNow: _openPendingInstaller,
      onVerifyUpdated: () async {
        final updated = await appReleaseVersionMatchesLabel(versionLabel);
        if (updated) await _clearPendingInstall();
        if (mounted) await _load();
        return updated;
      },
    );
    await _loadPendingInstall();
  }

  @override
  void dispose() {
    _versionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      AppReleaseInfoModel info = AppReleaseInfoModel.none();
      if (_usesApi) {
        final storage = getStorage() as ApiStorageService;
        info = await storage.getAppReleaseLatest(widget.currentUser.id);
      }
      if (!mounted) return;
      setState(() {
        _deviceVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        _releaseInfo = info;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pickApk() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['apk'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة ملف APK')),
      );
      return;
    }
    setState(() {
      _pickedFileName = file.name;
      _pickedBytes = bytes;
    });
  }

  void _setTransferProgress({
    required bool uploading,
    required double? progress,
    String? status,
  }) {
    if (!mounted) return;
    setState(() {
      if (uploading) {
        _uploadProgress = progress;
      } else {
        _downloadProgress = progress;
      }
      _transferStatus = status;
    });
  }

  Future<void> _uploadRelease() async {
    if (!_canUpload) return;
    final versionLabel = _versionController.text.trim();
    if (versionLabel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الإصدار (مثل V.10)')),
      );
      return;
    }
    if (_pickedBytes == null || _pickedBytes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر ملف APK أولاً')),
      );
      return;
    }
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _transferStatus = 'جاري تجهيز الملف...';
    });
    try {
      final storage = getStorage() as ApiStorageService;
      await storage.uploadAppRelease(
        requesterEmail: widget.currentUser.email,
        versionLabel: versionLabel,
        fileName: _pickedFileName ?? 'app-release.apk',
        fileBytes: _pickedBytes!,
        onProgress: (progress) {
          final pct = (progress * 100).round();
          final phase = progress < 0.1
              ? 'جاري تجهيز الملف...'
              : 'جاري الرفع إلى الخادم...';
          _setTransferProgress(
            uploading: true,
            progress: progress,
            status: '$phase $pct%',
          );
        },
      );
      if (!mounted) return;
      setState(() {
        _pickedBytes = null;
        _pickedFileName = null;
        _versionController.clear();
        _uploadProgress = null;
        _transferStatus = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع النسخة الجديدة وحذف النسخة السابقة')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الرفع: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = null;
          _transferStatus = null;
        });
      }
    }
  }

  Future<void> _downloadAndUpdate() async {
    if (!_usesApi || _releaseInfo?.hasRelease != true) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _transferStatus = 'جاري التنزيل... 0%';
    });
    try {
      final storage = getStorage() as ApiStorageService;
      final payload = await storage.downloadAppReleaseChunked(
        widget.currentUser.id,
        onProgress: (received, total) {
          final progress = total > 0 ? received / total : 0.0;
          final pct = (progress * 100).round();
          _setTransferProgress(
            uploading: false,
            progress: progress,
            status:
                'جاري التنزيل... $pct% (${_formatBytes(received)} / ${_formatBytes(total)})',
          );
        },
      );
      _setTransferProgress(
        uploading: false,
        progress: 1,
        status: 'جاري حفظ الملف...',
      );
      if (kIsWeb) {
        await triggerBrowserDownload(
          bytes: payload.bytes,
          fileName: payload.fileName,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تنزيل APK — ثبّته على جهاز Android'),
          ),
        );
      } else {
        final apkPath = await saveAppReleaseToFile(
          bytes: payload.bytes,
          fileName: payload.fileName,
        );
        final versionLabel = _releaseInfo?.versionLabel ?? '—';
        final sizeBytes = payload.bytes.length;
        await _savePendingInstall(
          apkPath: apkPath,
          versionLabel: versionLabel,
          fileName: payload.fileName,
          sizeBytes: sizeBytes,
        );
        if (!mounted) return;
        await _load();
        await _showInstallBottomSheet(
          versionLabel: versionLabel,
          sizeBytes: sizeBytes,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التنزيل: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = null;
          _transferStatus = null;
        });
      }
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '—';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildProgressIndicator({
    required double? progress,
    required String? status,
  }) {
    if (progress == null) return const SizedBox.shrink();
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: progress >= 1 ? null : clamped,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF1B5E20),
          ),
          const SizedBox(height: 8),
          Text(
            status ?? '${(progress * 100).round()}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _releaseInfo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Versions'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  if (!_usesApi)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'تحديث التطبيق يتطلب الاتصال بالخادم (apiBaseUrl في الإعدادات).',
                        ),
                      ),
                    ),
                  if (!kIsWeb && _pendingInstall != null)
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.pending_actions,
                                    color: Colors.orange.shade800),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'النسخة ${_pendingInstall!.versionLabel} جاهزة للتثبيت',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'تم تنزيل الملف (${_formatBytes(_pendingInstall!.sizeBytes)}) — أكمل التثبيت.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => _showInstallBottomSheet(
                                versionLabel: _pendingInstall!.versionLabel,
                                sizeBytes: _pendingInstall!.sizeBytes,
                              ),
                              icon: const Icon(Icons.install_mobile),
                              label: const Text('متابعة التثبيت'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!kIsWeb && _pendingInstall != null)
                    const SizedBox(height: 12),
                  if (_canUpload) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'رفع نسخة جديدة (مسؤول التطبيق)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _versionController,
                              enabled: !_uploading,
                              decoration: const InputDecoration(
                                labelText: 'رقم الإصدار',
                                hintText: 'V.10',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : _pickApk,
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _pickedFileName ?? 'اختيار ملف APK',
                              ),
                            ),
                            if (_pickedFileName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'الملف: $_pickedFileName (${_formatBytes(_pickedBytes?.length)})',
                                ),
                              ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _uploading ? null : _uploadRelease,
                              icon: _uploading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload),
                              label: Text(
                                _uploading ? 'جاري الرفع...' : 'رفع النسخة',
                              ),
                            ),
                            if (_uploading)
                              _buildProgressIndicator(
                                progress: _uploadProgress,
                                status: _transferStatus,
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'عند اكتمال الرفع تُحذف النسخة القديمة تلقائياً ويظهر تنبيه التحديث لمن لم يحمّل النسخة الجديدة.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'معلومات الإصدار',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _infoRow('إصدار الجهاز الحالي', _deviceVersion ?? '—'),
                          _infoRow(
                            'آخر نسخة على الخادم',
                            info?.hasRelease == true
                                ? info!.versionLabel ?? '—'
                                : 'لا توجد نسخة مرفوعة',
                          ),
                          if (info?.hasRelease == true) ...[
                            _infoRow('حجم الملف', _formatBytes(info!.sizeBytes)),
                            _infoRow('تاريخ الرفع', info.createdAt ?? '—'),
                          ],
                          const SizedBox(height: 16),
                          if (info?.hasRelease == true && info!.hasUpdate)
                            FilledButton.icon(
                              onPressed: _downloading ? null : _downloadAndUpdate,
                              icon: _downloading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.download),
                              label: Text(
                                _downloading ? 'جاري التنزيل...' : 'Download / Update',
                              ),
                            )
                          else if (info?.hasRelease == true)
                            const ListTile(
                              leading: Icon(Icons.check_circle, color: Colors.green),
                              title: Text('لديك آخر نسخة متاحة (تم التنزيل)'),
                            )
                          else
                            const ListTile(
                              leading: Icon(Icons.info_outline),
                              title: Text('لا توجد نسخة محدثة على الخادم بعد'),
                            ),
                          if (_downloading)
                            _buildProgressIndicator(
                              progress: _downloadProgress,
                              status: _transferStatus,
                            ),
                          if (kIsWeb && info?.hasRelease == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'على الويب: يتم تنزيل APK لتثبيته على جهاز Android.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
