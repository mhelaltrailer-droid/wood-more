import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/invoices_owner_constants.dart';
import '../models/invoices_owner_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

class InvoicesOwnerFormScreen extends StatefulWidget {
  final UserModel currentUser;
  final InvoicesOwnerModel? existing;

  const InvoicesOwnerFormScreen({
    super.key,
    required this.currentUser,
    this.existing,
  });

  @override
  State<InvoicesOwnerFormScreen> createState() =>
      _InvoicesOwnerFormScreenState();
}

class _PendingAttachment {
  final String fileName;
  final String mimeType;
  final String dataBase64;
  final int sizeBytes;

  _PendingAttachment({
    required this.fileName,
    required this.mimeType,
    required this.dataBase64,
    required this.sizeBytes,
  });
}

class _InvoicesOwnerFormScreenState extends State<InvoicesOwnerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _customProjectNameController = TextEditingController();
  final _storage = getStorage();

  int? _selectedProjectId;
  bool _loadingProjects = true;
  bool _saving = false;
  String? _projectsError;
  final List<_PendingAttachment> _attachments = [];
  List<ProjectModel> _projects = const [];

  bool get _isEdit => widget.existing != null;

  bool get _isOtherProject =>
      _selectedProjectId == invoicesOwnerOtherProjectDropdownValue;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _notesController.text = e.notes ?? '';
      if (e.projectId == null && e.projectName.trim().isNotEmpty) {
        _selectedProjectId = invoicesOwnerOtherProjectDropdownValue;
        _customProjectNameController.text = e.projectName.trim();
      } else {
        _selectedProjectId = e.projectId;
      }
    }
    _loadProjects();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customProjectNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loadingProjects = true;
      _projectsError = null;
    });
    try {
      final projects = await _storage.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loadingProjects = false;
        if (_selectedProjectId == null && projects.isNotEmpty) {
          _selectedProjectId = projects.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProjects = false;
        _projectsError = '$e';
      });
    }
  }

  bool _isAllowedFile(String name, String? mime) {
    final n = name.toLowerCase();
    final m = (mime ?? '').toLowerCase();
    final isPdf = m == 'application/pdf' || n.endsWith('.pdf');
    final isExcel = m.contains('excel') ||
        m.contains('spreadsheet') ||
        n.endsWith('.xls') ||
        n.endsWith('.xlsx') ||
        n.endsWith('.xlsm');
    return isPdf || isExcel;
  }

  String _mimeFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xlsm':
        return 'application/vnd.ms-excel.sheet.macroenabled.12';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickFiles() async {
    if (_attachments.length >= invoicesOwnerMaxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الحد الأقصى $invoicesOwnerMaxAttachments ملفات'),
        ),
      );
      return;
    }
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'xls', 'xlsx', 'xlsm'],
      withData: true,
    );
    if (result == null) return;

    final added = <_PendingAttachment>[];
    for (final f in result.files) {
      if (_attachments.length + added.length >= invoicesOwnerMaxAttachments) {
        break;
      }
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (bytes.length > invoicesOwnerMaxAttachmentBytes) {
        if (!mounted) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الملف ${f.name} أكبر من 5 ميجا'),
            backgroundColor: Colors.red,
          ),
        );
        continue;
      }
      final mime = _mimeFromExtension(f.extension);
      if (!_isAllowedFile(f.name, mime)) continue;
      added.add(
        _PendingAttachment(
          fileName: f.name,
          mimeType: mime,
          dataBase64: base64Encode(bytes),
          sizeBytes: bytes.length,
        ),
      );
    }
    if (added.isEmpty) return;
    setState(() => _attachments.addAll(added));
  }

  List<Map<String, dynamic>> _attachmentsPayload() {
    return _attachments
        .map(
          (a) => {
            'file_name': a.fileName,
            'mime_type': a.mimeType,
            'data_base64': a.dataBase64,
            'size_bytes': a.sizeBytes,
          },
        )
        .toList();
  }

  Future<void> _save() async {
    if (_storage is! ApiStorageService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يتطلب اتصال API')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المشروع')),
      );
      return;
    }
    final customProjectName = _customProjectNameController.text.trim();
    if (_isOtherProject && customProjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسم المشروع')),
      );
      return;
    }
    if (_attachments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أرفق ملفاً واحداً على الأقل (PDF أو Excel)')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final notes = _notesController.text.trim();
      final projectId = _isOtherProject ? null : _selectedProjectId;
      final projectName = _isOtherProject ? customProjectName : null;
      if (_isEdit) {
        await _storage.updateInvoicesOwner(
          invoiceId: widget.existing!.id,
          userId: widget.currentUser.id,
          projectId: projectId,
          projectName: projectName,
          notes: notes,
          attachments: _attachmentsPayload(),
        );
      } else {
        await _storage.createInvoicesOwner(
          userId: widget.currentUser.id,
          projectId: projectId,
          projectName: projectName,
          notes: notes.isEmpty ? null : notes,
          attachments: _attachmentsPayload(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customProjectName = _customProjectNameController.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل Progress' : 'New Progress +'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loadingProjects)
              const Center(child: CircularProgressIndicator())
            else if (_projectsError != null)
              Text(_projectsError!, style: const TextStyle(color: Colors.red))
            else
              DropdownButtonFormField<int>(
                value: _selectedProjectId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'المشروع *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  ..._projects.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: invoicesOwnerOtherProjectDropdownValue,
                    child: Text(
                      _isOtherProject && customProjectName.isNotEmpty
                          ? '$invoicesOwnerOtherProjectDropdownLabel ($customProjectName)'
                          : invoicesOwnerOtherProjectDropdownLabel,
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedProjectId = v),
              ),
            if (_isOtherProject) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customProjectNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المشروع *',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'المرفقات (PDF / Excel)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            if (_attachments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('لا مرفقات بعد', style: TextStyle(color: Colors.grey)),
              )
            else
              ...List.generate(_attachments.length, (i) {
                final a = _attachments[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(a.fileName),
                  subtitle: Text('${(a.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _attachments.removeAt(i)),
                  ),
                );
              }),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'إعادة إرسال' : 'إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}
