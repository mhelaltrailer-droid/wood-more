import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/invoices_owner_constants.dart';
import '../models/invoices_owner_model.dart';
import '../models/reports_sys_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/invoices_owner_timeline.dart';
import '../widgets/reports_sys_attachments_panel.dart';
import 'invoices_owner_form_screen.dart';

class InvoicesOwnerDetailScreen extends StatefulWidget {
  final UserModel currentUser;
  final int invoiceId;

  const InvoicesOwnerDetailScreen({
    super.key,
    required this.currentUser,
    required this.invoiceId,
  });

  @override
  State<InvoicesOwnerDetailScreen> createState() =>
      _InvoicesOwnerDetailScreenState();
}

class _InvoicesOwnerDetailScreenState extends State<InvoicesOwnerDetailScreen> {
  final _storage = getStorage();
  final _returnReasonController = TextEditingController();
  final _approveNotesController = TextEditingController();

  InvoicesOwnerModel? _invoice;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _returnReasonController.dispose();
    _approveNotesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_storage is! ApiStorageService) {
        throw Exception('Invoices (Owner) يتطلب اتصال API');
      }
      final invoice = await _storage.getInvoicesOwnerDetail(
        widget.invoiceId,
        userId: widget.currentUser.id,
      );
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<ReportsSysAttachmentModel> _asReportsSysAttachments(
    List<InvoicesOwnerAttachmentModel> list,
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

  Future<void> _approve() async {
    if (_storage is! ApiStorageService) return;
    setState(() => _acting = true);
    try {
      final notes = _approveNotesController.text.trim();
      await _storage.approveInvoicesOwner(
        invoiceId: widget.invoiceId,
        userId: widget.currentUser.id,
        notes: notes.isEmpty ? null : notes,
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

  Future<void> _returnForReview() async {
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
      await _storage.returnInvoicesOwner(
        invoiceId: widget.invoiceId,
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

  Future<void> _openEdit() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoicesOwnerFormScreen(
          currentUser: widget.currentUser,
          existing: invoice,
        ),
      ),
    );
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _deleteInvoice() async {
    if (_storage is! ApiStorageService) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستخلص'),
        content: const Text(
          'هل تريد حذف هذا المستخلص بالكامل مع كل المرفقات؟ لا يمكن التراجع.',
        ),
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
      await _storage.deleteInvoicesOwner(
        invoiceId: widget.invoiceId,
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

  Future<void> _deleteAttachment(int attachmentId) async {
    if (_storage is! ApiStorageService) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: const Text(
          'حذف هذا الملف نهائياً من قاعدة البيانات؟ لا يمكن التراجع.',
        ),
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
      final updated = await _storage.deleteInvoicesOwnerAttachment(
        invoiceId: widget.invoiceId,
        attachmentId: attachmentId,
        userId: widget.currentUser.id,
      );
      if (!mounted) return;
      setState(() => _invoice = updated);
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

  Future<Map<String, dynamic>?> _pickSingleAttachmentFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'xls', 'xlsx', 'xlsm'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return null;
    if (bytes.length > invoicesOwnerMaxAttachmentBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الملف ${f.name} أكبر من 5 ميجا'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
    final mime = _mimeFromExtension(f.extension);
    if (!_isAllowedFile(f.name, mime)) return null;
    return {
      'file_name': f.name,
      'mime_type': mime,
      'data_base64': base64Encode(bytes),
      'size_bytes': bytes.length,
    };
  }

  Future<void> _addAttachment() async {
    if (_storage is! ApiStorageService) return;
    final d = _invoice;
    if (d == null) return;
    if (d.attachments.length >= invoicesOwnerMaxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الحد الأقصى $invoicesOwnerMaxAttachments ملفات'),
        ),
      );
      return;
    }
    final file = await _pickSingleAttachmentFile();
    if (file == null) return;
    setState(() => _acting = true);
    try {
      final updated = await _storage.addInvoicesOwnerAttachment(
        invoiceId: widget.invoiceId,
        userId: widget.currentUser.id,
        fileName: file['file_name'] as String,
        mimeType: file['mime_type'] as String,
        dataBase64: file['data_base64'] as String,
        sizeBytes: file['size_bytes'] as int,
      );
      if (!mounted) return;
      setState(() => _invoice = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _replaceAttachment(int index) async {
    if (_storage is! ApiStorageService) return;
    final d = _invoice;
    if (d == null || index < 0 || index >= d.attachments.length) return;
    final attachment = d.attachments[index];
    final file = await _pickSingleAttachmentFile();
    if (file == null) return;
    setState(() => _acting = true);
    try {
      final updated = await _storage.replaceInvoicesOwnerAttachment(
        invoiceId: widget.invoiceId,
        attachmentId: attachment.id,
        userId: widget.currentUser.id,
        fileName: file['file_name'] as String,
        mimeType: file['mime_type'] as String,
        dataBase64: file['data_base64'] as String,
        sizeBytes: file['size_bytes'] as int,
      );
      if (!mounted) return;
      setState(() => _invoice = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: const Text(invoicesOwnerHomeIconLabel),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (_invoice != null && widget.currentUser.canManageInvoicesOwner)
            IconButton(
              tooltip: 'حذف المستخلص',
              onPressed: _acting ? null : _deleteInvoice,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              : _buildBody(fmt),
    );
  }

  Widget _buildBody(DateFormat fmt) {
    final d = _invoice!;
    final user = widget.currentUser;
    final canAct = user.canActOnInvoicesOwnerStatus(d.status) &&
        d.status != invoicesOwnerStatusReturnedCreator &&
        d.status != invoicesOwnerStatusApproved;
    final canEdit = user.canCreateInvoicesOwner &&
        d.status == invoicesOwnerStatusReturnedCreator &&
        d.createdByUserId == user.id;
    final canManage = user.canManageInvoicesOwner;
    final canAssigneeAttachments = user.canManageInvoicesOwnerAttachmentsAsAssignee(
      status: d.status,
      currentAssigneeUserId: d.currentAssigneeUserId,
    );
    final canDownloadAttachments = user.canDownloadInvoicesOwnerAttachments(
      status: d.status,
      currentAssigneeUserId: d.currentAssigneeUserId,
    );
    final canRemoveAttachment = canManage || canAssigneeAttachments;

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
        if (d.stageNotesForDisplay.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملاحظات المراحل',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...d.stageNotesForDisplay.map((n) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(n.body),
                          Text(
                            fmt.format(n.at),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
        const SizedBox(height: 12),
        Text(
          'بواسطة: ${d.createdByUserName}'
          '${d.currentAssigneeUserName != null ? ' — المسند: ${d.currentAssigneeUserName}' : ''}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (d.attachments.isNotEmpty || canAssigneeAttachments) ...[
          const SizedBox(height: 12),
          if (d.attachments.isNotEmpty)
            ReportsSysAttachmentsPanel(
              reportId: d.id,
              attachments: _asReportsSysAttachments(d.attachments),
              loadAttachment: _storage is ApiStorageService && canDownloadAttachments
                  ? (attachmentId) => _storage.getInvoicesOwnerAttachmentData(
                        invoiceId: d.id,
                        attachmentId: attachmentId,
                        userId: widget.currentUser.id,
                      )
                  : null,
              allowDownload: canDownloadAttachments,
              readOnly: !canRemoveAttachment,
              onRemove: canRemoveAttachment
                  ? (index) {
                      if (index < 0 || index >= d.attachments.length) return;
                      _deleteAttachment(d.attachments[index].id);
                    }
                  : null,
              onReplace: canAssigneeAttachments
                  ? (index) => _replaceAttachment(index)
                  : null,
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المرفقات',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'لا مرفقات حالياً',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          if (canAssigneeAttachments &&
              d.attachments.length < invoicesOwnerMaxAttachments) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _acting ? null : _addAttachment,
              icon: const Icon(Icons.add),
              label: const Text('إضافة مرفق'),
            ),
          ],
        ],
        const SizedBox(height: 16),
        InvoicesOwnerTimeline(actions: d.actions),
        if (canEdit) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _acting ? null : _openEdit,
            icon: const Icon(Icons.edit),
            label: const Text('تعديل وإعادة إرسال'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
        if (canAct) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _approveNotesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات الاعتماد (اختياري)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _acting ? null : _approve,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('اعتماد'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _returnReasonController,
            decoration: const InputDecoration(
              labelText: 'سبب الإعادة *',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _acting ? null : _returnForReview,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('إعادة للخطوة السابقة'),
          ),
        ],
      ],
    );
  }
}
