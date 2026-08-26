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
      final invoice = await _storage.getInvoicesOwnerDetail(widget.invoiceId);
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
      await _storage.approveInvoicesOwner(
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
        title: const Text('حذف الفاتورة'),
        content: const Text(
          'هل تريد حذف هذه الفاتورة بالكامل مع كل المرفقات؟ لا يمكن التراجع.',
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
        content: const Text('حذف هذا الملف من الفاتورة؟'),
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
              tooltip: 'حذف الفاتورة',
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
        const SizedBox(height: 12),
        Text(
          'بواسطة: ${d.createdByUserName}'
          '${d.currentAssigneeUserName != null ? ' — المسند: ${d.currentAssigneeUserName}' : ''}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (d.attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReportsSysAttachmentsPanel(
            reportId: d.id,
            attachments: _asReportsSysAttachments(d.attachments),
            loadAttachment: _storage is ApiStorageService
                ? (attachmentId) => _storage.getInvoicesOwnerAttachmentData(
                      invoiceId: d.id,
                      attachmentId: attachmentId,
                    )
                : null,
            readOnly: true,
            onRemove: canManage
                ? (index) {
                    if (index < 0 || index >= d.attachments.length) return;
                    _deleteAttachment(d.attachments[index].id);
                  }
                : null,
          ),
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
