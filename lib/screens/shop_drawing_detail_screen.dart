import 'package:flutter/material.dart';
import 'dart:ui' show TextDirection;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../models/reports_sys_model.dart';
import '../models/shop_drawing_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/reports_sys_attachments_panel.dart';
import '../widgets/shop_drawing_content_flags_panel.dart';
import '../widgets/shop_drawing_timeline.dart';
import 'shop_drawing_form_screen.dart';

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

  ShopDrawingModel? _drawing;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  void _syncOmNotesController(ShopDrawingModel drawing) {
    _omNotesController.text = drawing.omNotes?.trim() ?? '';
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
              readOnly ? 'ملاحظات مدير العمليات' : 'ملاحظات مدير العمليات (اختياري)',
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
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildBody(fmt),
    );
  }

  Widget _buildBody(DateFormat fmt) {
    final d = _drawing!;
    final user = widget.currentUser;
    final canPmAct = user.canActAsShopDrawingProjectManager &&
        d.status == ShopDrawingModel.statusPendingPm;
    final canOmAct = user.canApproveShopDrawingAsOm &&
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
                  const Text('الملاحظات', style: TextStyle(fontWeight: FontWeight.bold)),
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
        if (d.externalUrl != null && d.externalUrl!.trim().isNotEmpty) ...[
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
        const SizedBox(height: 20),
        ShopDrawingContentFlagsPanel(
          contentSd: d.contentSd,
          contentQs: d.contentQs,
          contentDashboard: d.contentDashboard,
          readOnly: true,
        ),
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
