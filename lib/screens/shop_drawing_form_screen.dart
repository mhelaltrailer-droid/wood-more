import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/shop_drawing_constants.dart';
import '../models/project_model.dart';
import '../models/shop_drawing_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

class ShopDrawingFormScreen extends StatefulWidget {
  final UserModel currentUser;
  final String documentType;
  final ShopDrawingModel? existing;

  const ShopDrawingFormScreen({
    super.key,
    required this.currentUser,
    required this.documentType,
    this.existing,
  });

  @override
  State<ShopDrawingFormScreen> createState() => _ShopDrawingFormScreenState();
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

class _ShopDrawingFormScreenState extends State<ShopDrawingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _urlController = TextEditingController();
  final _storage = getStorage();

  int? _selectedProjectId;
  bool _loadingProjects = true;
  bool _saving = false;
  String? _projectsError;
  final List<_PendingAttachment> _attachments = [];
  List<ProjectModel> _projects = const [];

  bool get _isEdit => widget.existing != null;

  String get _typeLabel => shopDrawingDocumentTypeLabel(
        widget.existing?.documentType ?? widget.documentType,
      );

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _notesController.text = e.notes ?? '';
      _urlController.text = e.externalUrl ?? '';
      _selectedProjectId = e.projectId;
    }
    _loadProjects();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _urlController.dispose();
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
    final isDmg = m == 'application/x-apple-diskimage' ||
        m == 'application/octet-stream' && n.endsWith('.dmg') ||
        n.endsWith('.dmg');
    final isImage = m.startsWith('image/') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp');
    return isPdf || isDmg || isImage;
  }

  String _mimeFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'dmg':
        return 'application/x-apple-diskimage';
      default:
        return 'image/${extension ?? 'jpeg'}';
    }
  }

  Future<void> _pickFiles() async {
    if (_attachments.length >= shopDrawingMaxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الحد الأقصى $shopDrawingMaxAttachments ملفات'),
        ),
      );
      return;
    }
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'dmg', 'jpg', 'jpeg', 'png', 'gif', 'webp',
      ],
      withData: true,
    );
    if (result == null) return;

    final added = <_PendingAttachment>[];
    for (final f in result.files) {
      if (_attachments.length + added.length >= shopDrawingMaxAttachments) break;
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (bytes.length > shopDrawingMaxAttachmentBytes) {
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
    if (_attachments.isEmpty && _urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أرفق ملفاً أو أدخل رابطاً واحداً على الأقل'),
        ),
      );
      return;
    }

    String? externalUrl;
    try {
      externalUrl = normalizeShopDrawingExternalUrl(_urlController.text);
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرابط غير صالح — استخدم http أو https'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_attachments.isEmpty && externalUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أرفق ملفاً أو أدخل رابطاً واحداً على الأقل'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final notes = _notesController.text.trim();
      if (_isEdit) {
        await _storage.updateShopDrawing(
          drawingId: widget.existing!.id,
          userId: widget.currentUser.id,
          projectId: _selectedProjectId!,
          notes: notes,
          attachments: _attachmentsPayload(),
          externalUrl: externalUrl,
        );
      } else {
        await _storage.createShopDrawing(
          userId: widget.currentUser.id,
          projectId: _selectedProjectId!,
          notes: notes.isEmpty ? null : notes,
          attachments: _attachmentsPayload(),
          documentType: widget.documentType,
          externalUrl: externalUrl,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل $_typeLabel' : 'رفع $_typeLabel'),
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
                items: _projects
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedProjectId = v),
                validator: (v) => v == null ? 'المشروع مطلوب' : null,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            const Text(
              'أرفاق ملف / رابط',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'رابط (URL) — اختياري',
                hintText: 'https://example.com/file',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'الملفات (صور + PDF + DMG)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('إضافة ملفات'),
                ),
              ],
            ),
            if (_attachments.isEmpty)
              const Text('لم تُرفق ملفات — يمكن الاكتفاء بالرابط')
            else
              ...List.generate(_attachments.length, (index) {
                final a = _attachments[index];
                return ListTile(
                  leading: Icon(
                    a.mimeType.contains('pdf')
                        ? Icons.picture_as_pdf
                        : a.fileName.toLowerCase().endsWith('.dmg') ||
                                a.mimeType.contains('diskimage')
                            ? Icons.folder_zip_outlined
                            : Icons.image_outlined,
                  ),
                  title: Text(a.fileName),
                  subtitle: Text('${(a.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () =>
                        setState(() => _attachments.removeAt(index)),
                  ),
                );
              }),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit ? 'إعادة الإرسال' : 'إرسال لمدير المشروعات',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
