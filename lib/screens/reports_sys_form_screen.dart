import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../models/reports_sys_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/reports_sys_attachments_panel.dart';

class ReportsSysFormScreen extends StatefulWidget {
  final UserModel currentUser;
  final ReportsSysModel? existing;
  final int? sourceReportId;

  const ReportsSysFormScreen({
    super.key,
    required this.currentUser,
    this.existing,
    this.sourceReportId,
  });

  @override
  State<ReportsSysFormScreen> createState() => _ReportsSysFormScreenState();
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

class _ReportsSysFormScreenState extends State<ReportsSysFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();
  final _otherProjectController = TextEditingController();
  final _storage = getStorage();

  String? _reportType;
  int? _selectedProjectId;
  bool _loadingProjects = true;
  bool _saving = false;
  bool _checkingName = false;
  String? _nameError;
  String? _projectsError;
  final List<_PendingAttachment> _attachments = [];
  List<ProjectModel> _projects = const [];
  List<UserModel> _users = const [];
  int? _forwardToUserId;

  bool get _isOtherProject =>
      _selectedProjectId == ReportsSysModel.otherProjectId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.reportName;
      _summaryController.text = e.summary;
      _notesController.text = e.notes ?? '';
      _reportType = e.reportType;
      if (e.projectId != null) {
        _selectedProjectId = e.projectId;
      } else if (e.projectName.trim().isNotEmpty) {
        _selectedProjectId = ReportsSysModel.otherProjectId;
        _otherProjectController.text = e.projectName;
      }
    }
    _loadProjects();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _summaryController.dispose();
    _notesController.dispose();
    _otherProjectController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loadingProjects = true;
      _projectsError = null;
    });
    try {
      final projects = await _storage.getProjects() as List<ProjectModel>;
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projects = const [];
        _loadingProjects = false;
        _projectsError = 'تعذر تحميل المشاريع';
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _storage.getUsers(
        requesterEmail: widget.currentUser.email,
      ) as List<UserModel>;
      if (!mounted) return;
      setState(() {
        _users = users.where((u) => u.id != widget.currentUser.id).toList();
      });
    } catch (_) {}
  }

  String _mimeFromName(String? fileName) {
    final ext = (fileName?.split('.').last ?? '').toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      int added = 0;
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        if (bytes.length > ReportsSysModel.maxAttachmentBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('الملف ${f.name} يتجاوز 5 ميجابايت'),
              backgroundColor: Colors.red,
            ),
          );
          continue;
        }
        _attachments.add(
          _PendingAttachment(
            fileName: f.name,
            mimeType: _mimeFromName(f.name),
            dataBase64: base64Encode(bytes),
            sizeBytes: bytes.length,
          ),
        );
        added++;
      }
      if (!mounted || added == 0) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرفاق الملفات: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _validateName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return false;
    if (_storage is! ApiStorageService) return true;
    setState(() {
      _checkingName = true;
      _nameError = null;
    });
    try {
      final ok = await _storage.checkReportsSysNameAvailable(
        name: name,
        excludeId: widget.existing?.id,
      );
      if (!ok) {
        setState(() => _nameError = 'اسم التقرير مستخدم مسبقاً');
        return false;
      }
      return true;
    } catch (_) {
      return true;
    } finally {
      if (mounted) setState(() => _checkingName = false);
    }
  }

  ({int? projectId, String? projectName}) _projectPayload() {
    if (_isOtherProject) {
      return (
        projectId: ReportsSysModel.otherProjectId,
        projectName: _otherProjectController.text.trim(),
      );
    }
    return (projectId: _selectedProjectId, projectName: null);
  }

  Future<void> _save({required bool andSubmit}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_reportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر نوع التقرير')),
      );
      return;
    }
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المشروع')),
      );
      return;
    }
    if (andSubmit && _forwardToUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المسند إليه')),
      );
      return;
    }
    if (!await _validateName()) return;
    if (_storage is! ApiStorageService) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reports-SYS يتطلب اتصال API'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      ReportsSysModel report;
      final name = _nameController.text.trim();
      final summary = _summaryController.text.trim();
      final notes = _notesController.text.trim();
      final project = _projectPayload();
      final attachmentMaps = _attachments
          .map(
            (a) => {
              'file_name': a.fileName,
              'mime_type': a.mimeType,
              'data_base64': a.dataBase64,
              'size_bytes': a.sizeBytes,
            },
          )
          .toList();

      if (widget.existing == null) {
        report = await _storage.createReportsSys(
          userId: widget.currentUser.id,
          reportName: name,
          reportType: _reportType!,
          summary: summary,
          notes: notes.isEmpty ? null : notes,
          sourceReportId: widget.sourceReportId,
          projectId: project.projectId,
          projectName: project.projectName,
        );
        if (attachmentMaps.isNotEmpty) {
          report = await _storage.updateReportsSys(
            reportId: report.id,
            userId: widget.currentUser.id,
            reportName: name,
            reportType: _reportType!,
            summary: summary,
            notes: notes,
            projectId: project.projectId,
            projectName: project.projectName,
            attachments: attachmentMaps,
          );
        }
      } else {
        report = await _storage.updateReportsSys(
          reportId: widget.existing!.id,
          userId: widget.currentUser.id,
          reportName: name,
          reportType: _reportType!,
          summary: summary,
          notes: notes,
          projectId: project.projectId,
          projectName: project.projectName,
          attachments: attachmentMaps.isEmpty ? null : attachmentMaps,
        );
      }

      if (andSubmit) {
        await _storage.submitReportsSys(
          reportId: report.id,
          userId: widget.currentUser.id,
          toUserId: _forwardToUserId!,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(andSubmit ? 'تم إرسال التقرير' : 'تم حفظ المسودة'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('name_taken')
          ? 'اسم التقرير مستخدم مسبقاً'
          : e.toString().contains('project_name_required')
              ? 'اسم المشروع مطلوب'
              : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل التقرير' : 'تقرير جديد'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'اسم التقرير',
                errorText: _nameError,
                suffixIcon: _checkingName
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            if (_loadingProjects)
              const LinearProgressIndicator()
            else if (_projectsError != null)
              Text(_projectsError!, style: TextStyle(color: Colors.red.shade700))
            else
              DropdownButtonFormField<int>(
                value: _selectedProjectId,
                decoration: const InputDecoration(labelText: 'المشروع'),
                items: [
                  ..._projects.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: ReportsSysModel.otherProjectId,
                    child: Text(ReportsSysModel.otherProjectLabel),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedProjectId = v),
                validator: (v) => v == null ? 'مطلوب' : null,
              ),
            if (_isOtherProject) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _otherProjectController,
                decoration: const InputDecoration(
                  labelText: 'اسم المشروع',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _reportType,
              decoration: const InputDecoration(labelText: 'نوع التقرير'),
              items: ReportsSysModel.reportTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: isEdit &&
                      widget.existing!.status != ReportsSysModel.statusDraft
                  ? null
                  : (v) => setState(() => _reportType = v),
              validator: (v) => v == null ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _summaryController,
              decoration: const InputDecoration(labelText: 'ملخص التقرير'),
              maxLines: 4,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file),
              label: const Text('إرفاق صور أو مستندات (حد أقصى 5 ميجا لكل ملف)'),
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              ReportsSysLocalAttachmentsPanel(
                items: _attachments
                    .map(
                      (a) => (
                        fileName: a.fileName,
                        mimeType: a.mimeType,
                        dataBase64: a.dataBase64,
                        sizeBytes: a.sizeBytes,
                      ),
                    )
                    .toList(),
                onRemove: (index) => setState(() => _attachments.removeAt(index)),
              ),
            ],
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              value: _forwardToUserId,
              decoration: const InputDecoration(
                labelText: 'المسند إليه (عند الحفظ والإرسال)',
              ),
              items: _users
                  .map(
                    (u) => DropdownMenuItem(
                      value: u.id,
                      child: Text(u.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _forwardToUserId = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : () => _save(andSubmit: true),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('إرسال للتوجيه'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
