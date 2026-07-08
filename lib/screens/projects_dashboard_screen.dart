import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/projects_dashboard_note_model.dart';
import '../models/projects_dashboard_sheet_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/auth_persistence.dart';
import '../services/storage_service.dart';
import '../widgets/excel_sheet_view.dart';
import 'login_screen.dart';

class ProjectsDashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const ProjectsDashboardScreen({super.key, required this.currentUser});

  @override
  State<ProjectsDashboardScreen> createState() =>
      _ProjectsDashboardScreenState();
}

class _ProjectsDashboardScreenState extends State<ProjectsDashboardScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  ProjectsDashboardSheetModel? _sheetMeta;
  String _fileName = 'projects_dashboard.xlsx';
  String? _fileData;
  bool _sheetViewReady = false;
  final ExcelSheetController _excelController = ExcelSheetController();

  ProjectsDashboardNoteModel? _latestPeerNote;
  ProjectsDashboardNoteModel? _latestTechnicalOfficeNote;
  ProjectsDashboardNoteModel? _latestOperationManagerNote;
  final _noteController = TextEditingController();
  bool _postingNote = false;

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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _applySheet(ProjectsDashboardSheetModel sheet) {
    _sheetMeta = sheet;
    _fileName = sheet.fileName;
    _fileData = sheet.fileData;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sheetViewReady = false;
    });
    try {
      final sheet = await _api.getProjectsDashboardSheet(
        userId: widget.currentUser.id,
        includeData: true,
      );
      ProjectsDashboardNoteModel? latestPeer;
      ProjectsDashboardNoteModel? latestTo;
      ProjectsDashboardNoteModel? latestOm;
      if (widget.currentUser.canViewAllProjectsDashboardNotes) {
        latestTo = await _api.getLatestProjectsDashboardNote(
          userId: widget.currentUser.id,
          authorRole: 'technical_office',
        );
        latestOm = await _api.getLatestProjectsDashboardNote(
          userId: widget.currentUser.id,
          authorRole: 'operation_manager',
        );
      } else if (widget.currentUser.projectsDashboardPeerNotesRole.isNotEmpty) {
        latestPeer = await _api.getLatestProjectsDashboardNote(
          userId: widget.currentUser.id,
          authorRole: widget.currentUser.projectsDashboardPeerNotesRole,
        );
      }

      if (!mounted) return;
      setState(() {
        if (sheet != null) _applySheet(sheet);
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

  Future<void> _pickAndUploadInitial() async {
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

    setState(() => _saving = true);
    try {
      final name = file.name.trim().isNotEmpty
          ? file.name.trim()
          : 'projects_dashboard.xlsx';
      final mime = name.toLowerCase().endsWith('.xls')
          ? 'application/vnd.ms-excel'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final b64 = base64Encode(bytes);
      await _api.saveProjectsDashboardSheet(
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        fileName: name,
        fileMime: mime,
        fileData: b64,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الشيت بنجاح')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveSheet() async {
    if (!_sheetViewReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتظر اكتمال تحميل الشيت أولاً')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final b64 = await _excelController.exportXlsx();
      if (b64.isEmpty) {
        throw Exception('تعذر تصدير محتوى الشيت');
      }
      final name = _fileName.toLowerCase().endsWith('.xlsx')
          ? _fileName
          : '${_fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}.xlsx';
      await _api.saveProjectsDashboardSheet(
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        fileName: name,
        fileMime:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fileData: b64,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الشيت')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _postNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    setState(() => _postingNote = true);
    try {
      await _api.addProjectsDashboardNote(
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        body: text,
      );
      _noteController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الملاحظة')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _postingNote = false);
    }
  }

  Future<void> _openAllNotes() async {
    try {
      final List<ProjectsDashboardNoteModel> notes;
      if (widget.currentUser.canViewAllProjectsDashboardNotes) {
        final toNotes = await _api.listProjectsDashboardNotes(
          userId: widget.currentUser.id,
          authorRole: 'technical_office',
        );
        final omNotes = await _api.listProjectsDashboardNotes(
          userId: widget.currentUser.id,
          authorRole: 'operation_manager',
        );
        notes = [...toNotes, ...omNotes]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        notes = await _api.listProjectsDashboardNotes(
          userId: widget.currentUser.id,
          authorRole: widget.currentUser.projectsDashboardPeerNotesRole,
        );
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _AllNotesSheet(
          notes: notes,
          canDelete: widget.currentUser.canDeleteProjectsDashboardNotes,
          onDelete: (id) async {
            await _api.deleteProjectsDashboardNote(
              noteId: id,
              requesterEmail: widget.currentUser.email,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            await _load();
            if (mounted) _openAllNotes();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
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

  String get _peerLabel {
    if (widget.currentUser.isTechnicalOffice) return 'مدير العمليات';
    if (widget.currentUser.isOperationManager) return 'المكتب الفني';
    return 'الطرف الآخر';
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
              'لم يُرفع شيت Excel بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'المكتب الفني يرفع الملف لأول مرة فقط عند فتح الأيقونة.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.currentUser.canUploadProjectsDashboardInitial)
              FilledButton.icon(
                onPressed: _saving ? null : _pickAndUploadInitial,
                icon: _saving
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

  Widget _buildSheetGrid() {
    final data = _fileData;
    if (data == null || data.trim().isEmpty) {
      return const Center(child: Text('لا يمكن عرض الشيت (لا توجد بيانات ملف)'));
    }
    return Stack(
      children: [
        ExcelSheetView(
          base64Data: data,
          editable: widget.currentUser.canEditProjectsDashboardSheet,
          controller: _excelController,
          onReady: () {
            if (mounted) setState(() => _sheetViewReady = true);
          },
          onError: (message) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطأ في عرض الشيت: $message'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
        if (!_sheetViewReady)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _notePreviewTile({
    required String? title,
    required ProjectsDashboardNoteModel? note,
  }) {
    if (note == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title ?? 'لا توجد ملاحظات بعد'),
        subtitle: title == null ? null : const Text('لا توجد ملاحظات بعد'),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title != null ? '$title: ${note.body}' : note.body),
      subtitle: Text(note.createdAtDisplay),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentUser.canViewAllProjectsDashboardNotes) ...[
              const Text(
                'آخر الملاحظات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _notePreviewTile(
                title: 'المكتب الفني',
                note: _latestTechnicalOfficeNote,
              ),
              const SizedBox(height: 8),
              _notePreviewTile(
                title: 'مدير العمليات',
                note: _latestOperationManagerNote,
              ),
            ] else ...[
              Text(
                'ملاحظات $_peerLabel',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _notePreviewTile(title: null, note: _latestPeerNote),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _openAllNotes,
                child: Text(
                  widget.currentUser.canViewAllProjectsDashboardNotes
                      ? 'عرض جميع الملاحظات (الطرفين)'
                      : 'عرض جميع الملاحظات',
                ),
              ),
            ),
            const Divider(),
            const Text(
              'إضافة ملاحظة',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب ملاحظتك هنا…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _postingNote ? null : _postNote,
                child: _postingNote
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إرسال الملاحظة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.canAccessProjectsDashboard) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Projects Dashboard'),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'تسجيل الخروج',
            ),
          ],
        ),
        body: const Center(child: Text('غير مصرح')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects Dashboard'),
        actions: [
          if (_sheetMeta != null &&
              widget.currentUser.canEditProjectsDashboardSheet)
            IconButton(
              onPressed: _saving ? null : _saveSheet,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              tooltip: 'حفظ الشيت',
            ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('خطأ: $_error'))
              : _sheetMeta == null
                  ? _buildInitialUpload()
                  : Column(
                      children: [
                        if (_sheetMeta!.updatedAtDisplay != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                'آخر تحديث: ${_sheetMeta!.updatedAtDisplay}'
                                '${_sheetMeta!.updatedByUserName != null ? ' — ${_sheetMeta!.updatedByUserName}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        Expanded(child: _buildSheetGrid()),
                        _buildNotesSection(),
                      ],
                    ),
    );
  }
}

class _AllNotesSheet extends StatelessWidget {
  final List<ProjectsDashboardNoteModel> notes;
  final bool canDelete;
  final Future<void> Function(int id) onDelete;

  const _AllNotesSheet({
    required this.notes,
    required this.canDelete,
    required this.onDelete,
  });

  String _roleLabel(String role) {
    switch (role) {
      case 'technical_office':
        return 'المكتب الفني';
      case 'operation_manager':
        return 'مدير العمليات';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'جميع الملاحظات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: notes.isEmpty
                    ? const Center(child: Text('لا توجد ملاحظات'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: notes.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return ListTile(
                            title: Text(note.body),
                            subtitle: Text(
                              '${_roleLabel(note.authorRole)} — ${note.userName}\n${note.createdAtDisplay}',
                            ),
                            isThreeLine: true,
                            trailing: canDelete
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('حذف الملاحظة'),
                                          content: const Text(
                                            'هل تريد حذف هذه الملاحظة؟',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('إلغاء'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('حذف'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) await onDelete(note.id);
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
