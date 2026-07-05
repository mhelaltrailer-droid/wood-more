import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_release_info_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/app_release_download.dart';

/// شاشة إصدارات التطبيق — تحديث للمستخدمين ورفع APK للمسؤول الأساسي.
class AppVersionsScreen extends StatefulWidget {
  final UserModel currentUser;

  const AppVersionsScreen({super.key, required this.currentUser});

  @override
  State<AppVersionsScreen> createState() => _AppVersionsScreenState();
}

class _AppVersionsScreenState extends State<AppVersionsScreen> {
  final _versionController = TextEditingController();
  AppReleaseInfoModel? _releaseInfo;
  String? _deviceVersion;
  String? _pickedFileName;
  List<int>? _pickedBytes;
  bool _loading = true;
  bool _downloading = false;
  bool _uploading = false;
  String? _error;

  bool get _usesApi => getStorage() is ApiStorageService;
  bool get _canUpload => widget.currentUser.canManageAppVersions && _usesApi;

  @override
  void initState() {
    super.initState();
    _load();
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
    setState(() => _uploading = true);
    try {
      final storage = getStorage() as ApiStorageService;
      await storage.uploadAppRelease(
        requesterEmail: widget.currentUser.email,
        versionLabel: versionLabel,
        fileName: _pickedFileName ?? 'app-release.apk',
        fileDataBase64: base64Encode(_pickedBytes!),
      );
      if (!mounted) return;
      setState(() {
        _pickedBytes = null;
        _pickedFileName = null;
        _versionController.clear();
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
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadAndUpdate() async {
    if (!_usesApi || _releaseInfo?.hasRelease != true) return;
    setState(() => _downloading = true);
    try {
      final storage = getStorage() as ApiStorageService;
      final payload = await storage.downloadAppRelease(widget.currentUser.id);
      var fileData = payload.fileData.trim();
      if (fileData.startsWith('data:')) {
        final comma = fileData.indexOf(',');
        if (comma >= 0) fileData = fileData.substring(comma + 1);
      }
      final bytes = base64Decode(fileData);
      if (kIsWeb) {
        await triggerBrowserDownload(
          bytes: bytes,
          fileName: payload.fileName,
        );
      } else {
        final openError = await saveAndOpenAppRelease(
          bytes: bytes,
          fileName: payload.fileName,
        );
        if (openError != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(openError)),
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'تم تنزيل APK — ثبّته على جهاز Android'
                : 'تم التنزيل — أكمل التثبيت من شاشة النظام',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التنزيل: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '—';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
