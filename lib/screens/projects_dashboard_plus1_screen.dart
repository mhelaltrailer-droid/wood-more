import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/projects_dashboard_constants.dart';
import '../models/projects_dashboard_note_model.dart';
import '../models/projects_dashboard_sheet_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/auth_persistence.dart';
import '../services/storage_service.dart';
import '../utils/projects_dashboard_file_actions.dart';
import '../widgets/projects_dashboard_desktop_gate.dart';
import '../widgets/projects_dashboard_notes_section.dart';
import 'login_screen.dart';

/// Projects Dashboard +1 — download, edit in Excel, re-upload.
class ProjectsDashboardPlus1Screen extends StatefulWidget {
  final UserModel currentUser;

  const ProjectsDashboardPlus1Screen({super.key, required this.currentUser});

  @override
  State<ProjectsDashboardPlus1Screen> createState() =>
      _ProjectsDashboardPlus1ScreenState();
}

class _ProjectsDashboardPlus1ScreenState
    extends State<ProjectsDashboardPlus1Screen> {
  static const _variant = ProjectsDashboardVariant.upload;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  ProjectsDashboardSheetModel? _sheetMeta;

  ProjectsDashboardNoteModel? _latestPeerNote;
  ProjectsDashboardNoteModel? _latestTechnicalOfficeNote;
  ProjectsDashboardNoteModel? _latestOperationManagerNote;

  ApiStorageService get _api {
    final storage = getStorage();
    if (storage is! ApiStorageService) {
      throw StateError('Projects Dashboard يتطلب الاتصال بالخادم');
    }
    return storage;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sheet = await _api.getProjectsDashboardSheet(
        userId: widget.currentUser.id,
        includeData: false,
        variant: _variant,
      );
      ProjectsDashboardNoteModel? latestPeer;
      ProjectsDashboardNoteModel? latestTo;
      ProjectsDashboardNoteModel? latestOm;
      if (widget.currentUser.canViewAllProjectsDashboardNotes) {
        latestTo = await _api.getLatestProjectsDashboardNote(
          userId: widget.currentUser.id,
          authorRole: 'technical_office',
          variant: _variant,
        );
        latestOm = await _api.getLatestProjectsDashboardNote(
          userId: widget.currentUser.id,
          authorRole: 'operation_manager',
          variant: _variant,
        );
      } else if (widget.currentUser.projectsDashboardPeerNotesRole.isNotEmpty) {
        latestPeer = await _api.getLatestProjectsDashboardNote(
          userId: widget.currentUser.id,
          authorRole: widget.currentUser.projectsDashboardPeerNotesRole,
          variant: _variant,
        );
      }

      if (!mounted) return;
      setState(() {
        _sheetMeta = sheet;
        _latestPeerNote = latestPeer;
        _latestTechnicalOfficeNote = latestTo;
        _latestOperationManagerNote = latestOm;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUpload({required bool isInitial}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر قراءة الملف'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final name = file.name.trim().isNotEmpty
          ? file.name.trim()
          : 'projects_dashboard_plus1.xlsx';
      final mime = name.toLowerCase().endsWith('.xls')
          ? 'application/vnd.ms-excel'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      await _api.saveProjectsDashboardSheet(
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        fileName: name,
        fileMime: mime,
        fileData: base64Encode(bytes),
        variant: _variant,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInitial ? 'تم رفع الشيت بنجاح' : 'تم رفع النسخة المحدّثة بنجاح',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _downloadSheet() {
    if (!kIsWeb || _sheetMeta == null) return;
    final url = _api.projectsDashboardSheetDownloadUrl(
      userId: widget.currentUser.id,
      variant: _variant,
    );
    downloadProjectsDashboardFile(url, _sheetMeta!.fileName);
  }

  void _openInExcelDirect() {
    if (!kIsWeb || _sheetMeta == null) return;
    final url = _api.projectsDashboardSheetDownloadUrl(
      userId: widget.currentUser.id,
      variant: _variant,
    );
    final officeUri = 'ms-excel:ofe|u|$url';
    openProjectsDashboardInExcel(officeUri);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'جاري فتح Excel… بعد التعديل ارفع النسخة المحدّثة من الزر أدناه',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من الحساب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await clearCurrentUser();
    await clearLastRoute();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildInitialUpload() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upload_file, size: 72, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'لم يُرفع شيت Excel بعد (+1)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'المكتب الفني يرفع الملف لأول مرة. بعد التعديل في Excel ارفع النسخة المحدّثة.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.currentUser.canUploadProjectsDashboardInitial)
              FilledButton.icon(
                onPressed: _busy ? null : () => _pickAndUpload(isInitial: true),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload_outlined),
                label: const Text('رفع ملف Excel'),
              )
            else
              const Text('بانتظار رفع الملف من المكتب الفني'),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetPanel() {
    final meta = _sheetMeta!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.table_chart_outlined,
                        size: 40,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta.fileName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (meta.updatedAtDisplay != null)
                              Text(
                                'آخر تحديث: ${meta.updatedAtDisplay}'
                                '${meta.updatedByUserName != null ? ' — ${meta.updatedByUserName}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: const Text(
                      'الطريقة: تحميل → تعديل في Excel → رفع النسخة المحدّثة.\n'
                      'بعد الحفظ محلياً على ويندوز، اضغط «رفع النسخة المحدّثة».',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _downloadSheet,
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('تحميل الملف'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _openInExcelDirect,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('فتح مباشرة في Excel'),
                      ),
                      if (widget.currentUser.canEditProjectsDashboardSheet)
                        OutlinedButton.icon(
                          onPressed:
                              _busy ? null : () => _pickAndUpload(isInitial: false),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('رفع النسخة المحدّثة'),
                        ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحديث الحالة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!widget.currentUser.canAccessProjectsDashboard) {
      return const Center(child: Text('غير مصرح'));
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('خطأ: $_error'));
    }
    if (_sheetMeta == null) {
      return _buildInitialUpload();
    }
    return Column(
      children: [
        Expanded(child: _buildSheetPanel()),
        ProjectsDashboardNotesSection(
          currentUser: widget.currentUser,
          variant: _variant,
          api: _api,
          latestPeerNote: _latestPeerNote,
          latestTechnicalOfficeNote: _latestTechnicalOfficeNote,
          latestOperationManagerNote: _latestOperationManagerNote,
          onChanged: _load,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProjectsDashboardDesktopGate(
      title: 'Projects Dashboard +1',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Projects Dashboard +1'),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }
}
