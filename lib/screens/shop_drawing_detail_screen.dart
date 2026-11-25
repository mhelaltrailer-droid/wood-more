import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../core/shop_drawing_constants.dart';
import '../models/reports_sys_model.dart';
import '../models/shop_drawing_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/reports_sys_attachments_panel.dart';
import '../widgets/shop_drawing_content_flags_panel.dart';
import '../widgets/shop_drawing_timeline.dart';
import 'shop_drawing_form_screen.dart';

class _OmPendingAttachment {
  final String fileName;
  final String mimeType;
  final String dataBase64;
  final int sizeBytes;

  const _OmPendingAttachment({
    required this.fileName,
    required this.mimeType,
    required this.dataBase64,
    required this.sizeBytes,
  });
}

class ShopDrawingDetailScreen extends StatefulWidget {
  final UserModel currentUser;
  final int drawingId;

  const ShopDrawingDetailScreen({
    super.key,
    required this.currentUser,
    required this.drawingId,
  });

  @override
  State<ShopDrawingDetailScreen> createState() =>
      _ShopDrawingDetailScreenState();
}

class _ShopDrawingDetailScreenState extends State<ShopDrawingDetailScreen> {
  final _storage = getStorage();
  final _returnReasonController = TextEditingController();
  final _omNotesController = TextEditingController();
  final _omUrlController = TextEditingController();

  ShopDrawingModel? _drawing;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  bool _editContentSd = false;
  bool _editContentQs = false;
  bool _editContentDashboard = false;
  final List<_OmPendingAttachment> _omReplacementAttachments = [];

  void _syncOmNotesController(ShopDrawingModel drawing) {
    _omNotesController.text = drawing.omNotes?.trim() ?? '';
  }

  void _syncOmEditFields(ShopDrawingModel drawing) {
    _editContentSd = drawing.contentSd;
    _editContentQs = drawing.contentQs;
    _editContentDashboard = drawing.contentDashboard;
    _omUrlController.text = drawing.externalUrl?.trim() ?? '';
    _omReplacementAttachments.clear();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _returnReasonController.dispose();
    _omNotesController.dispose();
    _omUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_storage is! ApiStorageService) {
        throw Exception('Shop-drawing يتطلب اتصال API');
      }
      final drawing = await _storage.getShopDrawingDetail(widget.drawingId);
      if (!mounted) return;
      setState(() {
        _drawing = drawing;
        _loading = false;
      });
      _syncOmNotesController(drawing);
      _syncOmEditFields(drawing);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<ReportsSysAttachmentModel> _asReportsSysAttachments(
    List<ShopDrawingAttachmentModel> list,
  ) {
    return list
        .map(
          (a) => ReportsSysAttachmentModel(
            id: a.id,
            fileName: a.fileName,
            mimeType: a.mimeType,
            sizeBytes: a.sizeBytes,
            createdAt: a.createdAt,
          ),
        )
        .toList();
  }

  Future<void> _pmApprove() async {
    if (_storage is! ApiStorageService) return;
    setState(() => _acting = true);
    try {
      await _storage.pmApproveShopDrawing(
        drawingId: widget.drawingId,
        userId: widget.currentUser.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _pmReturn() async {
    if (_storage is! ApiStorageService) return;
    final reason = _returnReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سبب الإعادة مطلوب')),
      );
      return;
    }
    setState(() => _acting = true);
    try {
      await _storage.pmReturnShopDrawing(
        drawingId: widget.drawingId,
        userId: widget.currentUser.id,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _omApprove() async {
    if (_storage is! ApiStorageService) return;
    setState(() => _acting = true);
    try {
      final notes = _omNotesController.text.trim();
      await _storage.omApproveShopDrawing(
        drawingId: widget.drawingId,
        userId: widget.currentUser.id,
        omNotes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _omReturn() async {
    if (_storage is! ApiStorageService) return;
    final reason = _returnReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سبب الإعادة مطلوب')),
      );
      return;
    }
    setState(() => _acting = true);
    try {
      await _storage.omReturnShopDrawing(
        drawingId: widget.drawingId,
        userId: widget.currentUser.id,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
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

  Future<void> _pickOmReplacementFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'dmg', 'jpg', 'jpeg', 'png', 'gif', 'webp',
      ],
      withData: true,
    );
    if (result == null) return;

    final added = <_OmPendingAttachment>[];
    for (final f in result.files) {
      if (added.length >= shopDrawingMaxAttachments) break;
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
        _OmPendingAttachment(
          fileName: f.name,
          mimeType: mime,
          dataBase64: base64Encode(bytes),
          sizeBytes: bytes.length,
        ),
      );
    }
    if (added.isEmpty) return;
    setState(() {
      _omReplacementAttachments
        ..clear()
        ..addAll(added);
    });
  }

  Future<void> _omSaveEdits() async {
    if (_storage is! ApiStorageService) return;
    final drawing = _drawing;
    if (drawing == null) return;

    String? externalUrl;
    try {
      externalUrl = normalizeShopDrawingExternalUrl(_omUrlController.text);
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرابط غير صالح — استخدم http أو https'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final replacing = _omReplacementAttachments.isNotEmpty;
    final hasExistingFiles = drawing.attachments.isNotEmpty;
    if (!replacing && !hasExistingFiles && externalUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أبقِ مرفقاً أو رابطاً واحداً على الأقل'),
        ),
      );
      return;
    }
    if (replacing && _omReplacementAttachments.isEmpty && externalUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أرفق ملفاً أو أدخل رابطاً واحداً على الأقل'),
        ),
      );
      return;
    }

    setState(() => _acting = true);
    try {
      final updated = await _storage.omEditShopDrawing(
        drawingId: widget.drawingId,
        userId: widget.currentUser.id,
        contentSd: _editContentSd,
        contentQs: _editContentQs,
        contentDashboard: _editContentDashboard,
        externalUrl: externalUrl,
        attachments: replacing
            ? _omReplacementAttachments
                .map(
                  (a) => {
                    'file_name': a.fileName,
                    'mime_type': a.mimeType,
                    'data_base64': a.dataBase64,
                    'size_bytes': a.sizeBytes,
                  },
                )
                .toList()
            : null,
      );
      if (!mounted) return;
      setState(() => _drawing = updated);
      _syncOmNotesController(updated);
      _syncOmEditFields(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التعديلات')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _saveOmNotes() async {
    if (_storage is! ApiStorageService) return;
    setState(() => _acting = true);
    try {
      final notes = _omNotesController.text.trim();
      final updated = await _storage.updateShopDrawingOmNotes(
        drawingId: widget.drawingId,
        userId: widget.currentUser.id,
        omNotes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      setState(() => _drawing = updated);
      _syncOmNotesController(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ ملاحظات مدير العمليات')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _buildOmNotesReadOnlyCard(String notes) {
    return Card(
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملاحظات مدير العمليات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(notes),
          ],
        ),
      ),
    );
  }

  Widget _buildOmNotesEditor({
    required bool readOnly,
    String? saveLabel,
    VoidCallback? onSave,
  }) {
    return Card(
      color: readOnly ? null : const Color(0xFFF1F8E9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              readOnly
                  ? 'ملاحظات مدير العمليات'
                  : 'ملاحظات مدير العمليات (اختياري)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _omNotesController,
              readOnly: readOnly,
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظاتك هنا...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            if (onSave != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _acting ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                ),
                child: Text(saveLabel ?? 'حفظ الملاحظات'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOmEditPanel(ShopDrawingModel drawing) {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تعديل قبل الاعتماد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ShopDrawingContentFlagsPanel(
              contentSd: _editContentSd,
              contentQs: _editContentQs,
              contentDashboard: _editContentDashboard,
              onSdChanged: (v) => setState(() => _editContentSd = v),
              onQsChanged: (v) => setState(() => _editContentQs = v),
              onDashboardChanged: (v) =>
                  setState(() => _editContentDashboard = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _omUrlController,
              decoration: const InputDecoration(
                labelText: 'رابط خارجي (اختياري)',
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            Text(
              _omReplacementAttachments.isEmpty
                  ? 'المرفقات الحالية: ${drawing.attachments.length} — اتركها كما هي أو استبدلها دفعة واحدة'
                  : 'سيتم استبدال المرفقات بـ ${_omReplacementAttachments.length} ملف جديد',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _acting ? null : _pickOmReplacementFiles,
              icon: const Icon(Icons.attach_file),
              label: Text(
                _omReplacementAttachments.isEmpty
                    ? 'استبدال المرفقات'
                    : 'تغيير الملفات المختارة',
              ),
            ),
            if (_omReplacementAttachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._omReplacementAttachments.map(
                (a) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(a.fileName),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _acting
                        ? null
                        : () => setState(
                              () => _omReplacementAttachments.remove(a),
                            ),
                  ),
                ),
              ),
              TextButton(
                onPressed: _acting
                    ? null
                    : () => setState(_omReplacementAttachments.clear),
                child: const Text('إلغاء الاستبدال والاحتفاظ بالمرفقات الحالية'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDrawing() async {
    if (_storage is! ApiStorageService) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطلب'),
        content: const Text('هل تريد حذف هذا الطلب نهائياً؟ لا يمكن التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _acting = true);
    try {
      await _storage.deleteShopDrawing(
        drawingId: widget.drawingId,
        userId: widget.currentUser.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _openEdit() async {
    final drawing = _drawing;
    if (drawing == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShopDrawingFormScreen(
          currentUser: widget.currentUser,
          documentType: drawing.documentType,
          existing: drawing,
        ),
      ),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرابط غير صالح')),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح الرابط')),
      );
    }
  }

  Widget _buildExternalUrlCard(String url) {
    return Card(
      color: const Color(0xFFE3F2FD),
      child: InkWell(
        onTap: () => _openExternalUrl(url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.link, color: Color(0xFF1565C0)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'رابط مرفق',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      url,
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        decoration: TextDecoration.underline,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اضغط للفتح في المتصفح',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Color(0xFF1565C0)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: Text(_drawing?.documentTypeLabel ?? 'Shop-Drawing'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (_drawing != null && widget.currentUser.canManageShopDrawingApproved)
            IconButton(
              tooltip: 'حذف',
              onPressed: _acting ? null : _deleteDrawing,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _buildBody(fmt),
    );
  }

  Widget _buildBody(DateFormat fmt) {
    final d = _drawing!;
    final user = widget.currentUser;
    final canPmAct = user.canActAsShopDrawingProjectManager &&
        d.status == ShopDrawingModel.statusPendingPm;
    final canOmAct = user.canEditOrReturnShopDrawingAsOm &&
        d.status == ShopDrawingModel.statusPendingOm;
    final canOmEditNotes = user.canApproveShopDrawingAsOm &&
        d.status == ShopDrawingModel.statusApproved;
    final showOmNotesReadOnly = d.status == ShopDrawingModel.statusApproved &&
        !canOmEditNotes &&
        d.omNotes != null &&
        d.omNotes!.trim().isNotEmpty;
    final canEdit = user.isTechnicalOffice &&
        d.status == ShopDrawingModel.statusReturnedToTo &&
        d.createdByUserId == user.id;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(
              d.projectName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text('${d.statusLabelAr} — ${fmt.format(d.updatedAt)}'),
          ),
        ),
        if (d.notes != null && d.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الملاحظات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(d.notes!),
                ],
              ),
            ),
          ),
        ],
        if (d.returnReason != null && d.returnReason!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سبب الإعادة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(d.returnReason!),
                ],
              ),
            ),
          ),
        ],
        if (!canOmAct &&
            d.externalUrl != null &&
            d.externalUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildExternalUrlCard(d.externalUrl!.trim()),
        ],
        if (d.attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReportsSysAttachmentsPanel(
            reportId: d.id,
            attachments: _asReportsSysAttachments(d.attachments),
            loadAttachment: _storage is ApiStorageService
                ? (attachmentId) => _storage.getShopDrawingAttachmentData(
                      drawingId: d.id,
                      attachmentId: attachmentId,
                    )
                : null,
            readOnly: true,
          ),
        ],
        if (!canOmAct) ...[
          const SizedBox(height: 20),
          ShopDrawingContentFlagsPanel(
            contentSd: d.contentSd,
            contentQs: d.contentQs,
            contentDashboard: d.contentDashboard,
            readOnly: true,
          ),
        ],
        const SizedBox(height: 12),
        ShopDrawingTimeline(actions: d.actions),
        if (showOmNotesReadOnly) ...[
          const SizedBox(height: 12),
          _buildOmNotesReadOnlyCard(d.omNotes!.trim()),
        ],
        if (canEdit) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _acting ? null : _openEdit,
            icon: const Icon(Icons.edit),
            label: const Text('تعديل وإعادة الإرسال'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
            ),
          ),
        ],
        if (canPmAct) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _returnReasonController,
            decoration: const InputDecoration(
              labelText: 'سبب الإعادة (عند الإرجاع)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _acting ? null : _pmApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                  ),
                  child: const Text('اعتماد'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _acting ? null : _pmReturn,
                  child: const Text('إعادة + مراجعة'),
                ),
              ),
            ],
          ),
        ],
        if (canOmAct) ...[
          const SizedBox(height: 16),
          _buildOmEditPanel(d),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _acting ? null : _omSaveEdits,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ التعديلات'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF6C00),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _returnReasonController,
            decoration: const InputDecoration(
              labelText: 'سبب الإعادة للمكتب الفني (عند الإرجاع)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _acting ? null : _omReturn,
            icon: const Icon(Icons.undo),
            label: const Text('إرجاع للمكتب الفني'),
          ),
          const SizedBox(height: 16),
          _buildOmNotesEditor(readOnly: false),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _acting ? null : _omApprove,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('اعتماد / حفظ'),
          ),
        ],
        if (canOmEditNotes) ...[
          const SizedBox(height: 16),
          _buildOmNotesEditor(
            readOnly: false,
            saveLabel: 'حفظ الملاحظات',
            onSave: _saveOmNotes,
          ),
        ],
      ],
    );
  }
}
