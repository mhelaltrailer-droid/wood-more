import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reports_sys_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/reports_sys_timeline.dart';
import '../widgets/reports_sys_attachments_panel.dart';
import 'reports_sys_form_screen.dart';

class ReportsSysDetailScreen extends StatefulWidget {
  final UserModel currentUser;
  final int reportId;

  const ReportsSysDetailScreen({
    super.key,
    required this.currentUser,
    required this.reportId,
  });

  @override
  State<ReportsSysDetailScreen> createState() => _ReportsSysDetailScreenState();
}

class _ReportsSysDetailScreenState extends State<ReportsSysDetailScreen> {
  final _storage = getStorage();
  final _commentController = TextEditingController();
  final _relaunchNameController = TextEditingController();

  ReportsSysModel? _report;
  List<UserModel> _users = const [];
  bool _loading = true;
  bool _acting = false;
  String? _error;
  int? _forwardToUserId;

  bool get _canDeleteAnyReportAsPrimaryAdmin =>
      widget.currentUser.email.trim().toLowerCase() ==
      UserModel.primaryAppAdminEmail.toLowerCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _relaunchNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_storage is! ApiStorageService) {
        throw Exception('Reports-SYS يتطلب اتصال API');
      }
      final report = await _storage.getReportsSysDetail(widget.reportId);
      final users = await _storage.getUsers(
        requesterEmail: widget.currentUser.email,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _users = users.where((u) => u.id != widget.currentUser.id).toList();
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

  Future<void> _respond(String action, {bool requireComment = false}) async {
    final report = _report;
    if (report == null || _storage is! ApiStorageService) return;
    final comment = _commentController.text.trim();
    if (requireComment && comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('سبب الرفض أو الملاحظة مطلوب'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (action == 'forward' && _forwardToUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المستخدم للتوجيه')),
      );
      return;
    }

    setState(() => _acting = true);
    try {
      await _storage.respondReportsSys(
        reportId: report.id,
        userId: widget.currentUser.id,
        action: action,
        toUserId: _forwardToUserId,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      _commentController.clear();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنفيذ الإجراء')),
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

  Future<void> _openEdit() async {
    final report = _report;
    if (report == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportsSysFormScreen(
          currentUser: widget.currentUser,
          existing: report,
        ),
      ),
    );
    if (changed == true) {
      await _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _submitAfterEdit() async {
    final report = _report;
    if (report == null || _storage is! ApiStorageService) return;
    if (_forwardToUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المستخدم للإرسال')),
      );
      return;
    }
    setState(() => _acting = true);
    try {
      await _storage.submitReportsSys(
        reportId: report.id,
        userId: widget.currentUser.id,
        toUserId: _forwardToUserId!,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
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

  Future<void> _relaunch() async {
    final report = _report;
    if (report == null || _storage is! ApiStorageService) return;
    final name = _relaunchNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل اسماً جديداً للتقرير')),
      );
      return;
    }
    setState(() => _acting = true);
    try {
      final newReport = await _storage.relaunchReportsSys(
        sourceReportId: report.id,
        userId: widget.currentUser.id,
        reportName: name,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReportsSysDetailScreen(
            currentUser: widget.currentUser,
            reportId: newReport.id,
          ),
        ),
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

  Future<void> _showRelaunchDialog() async {
    _relaunchNameController.clear();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة إطلاق كتقرير جديد'),
        content: TextField(
          controller: _relaunchNameController,
          decoration: const InputDecoration(
            labelText: 'اسم التقرير الجديد',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _relaunch();
            },
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReport() async {
    final report = _report;
    if (report == null || _storage is! ApiStorageService) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقرير'),
        content: Text(
          'سيتم حذف التقرير نهائياً بكل مرفقاته ومساره الزمني.\n\n${report.reportName}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _acting = true);
    try {
      await _storage.deleteReportsSys(
        reportId: report.id,
        userId: widget.currentUser.id,
        requesterEmail: widget.currentUser.email,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف التقرير نهائياً')),
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

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل التقرير'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _report == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل التقرير'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: Center(child: Text(_error ?? 'غير موجود')),
      );
    }

    final report = _report!;
    final canEdit = report.canEditBy(widget.currentUser.id);
    final canAct = report.canActBy(widget.currentUser.id);
    final canArchive = widget.currentUser.canArchiveReportsSys;
    final canRelaunch = report.isTerminal;

    return Scaffold(
      appBar: AppBar(
        title: Text(report.reportName),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'تعديل',
              onPressed: _openEdit,
              icon: const Icon(Icons.edit),
            ),
          if (_canDeleteAnyReportAsPrimaryAdmin)
            IconButton(
              tooltip: 'حذف نهائي',
              onPressed: _acting ? null : _deleteReport,
              icon: const Icon(Icons.delete_forever_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.reportType,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('الحالة: ${report.statusLabelAr}'),
                  if (report.projectName.trim().isNotEmpty)
                    Text('المشروع: ${report.projectName}'),
                  Text('المنشئ: ${report.createdByUserName}'),
                  if (report.currentAssigneeUserName != null)
                    Text('بحوزة: ${report.currentAssigneeUserName}'),
                  Text('آخر تحديث: ${fmt.format(report.updatedAt)}'),
                  if (report.rejectionReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'سبب الرفض: ${report.rejectionReason}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ReportsSysReviewersChip(reviewers: report.reviewers),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملخص التقرير',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(report.summary),
                  if (report.notes != null && report.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'ملاحظات',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(report.notes!),
                  ],
                ],
              ),
            ),
          ),
          if (report.attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ReportsSysAttachmentsPanel(
              reportId: report.id,
              attachments: report.attachments,
              loadAttachment: _storage is ApiStorageService
                  ? (id) => _storage.getReportsSysAttachmentData(
                        reportId: report.id,
                        attachmentId: id,
                      )
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          ReportsSysTimeline(actions: report.actions),
          if (canAct || (canEdit && report.status == ReportsSysModel.statusReturnedForEdit)) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'ملاحظة / سبب (إلزامي عند الرفض أو الإرجاع)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _forwardToUserId,
              decoration: const InputDecoration(
                labelText: 'المسند إليه',
                border: OutlineInputBorder(),
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
          ],
          if (canAct) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _acting ? null : () => _respond('forward'),
                  child: const Text('اطلاع وموافقة — توجيه'),
                ),
                OutlinedButton(
                  onPressed: _acting ? null : () => _respond('return', requireComment: true),
                  child: const Text('إرجاع للتعديل'),
                ),
                if (canArchive)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _acting ? null : () => _respond('archive'),
                    child: const Text('إرسال للأرشيف'),
                  ),
                TextButton(
                  onPressed: _acting ? null : () => _respond('reject', requireComment: true),
                  child: Text(
                    'رفض التقرير',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ],
          if (canEdit && report.status == ReportsSysModel.statusReturnedForEdit) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _acting ? null : _openEdit,
                    child: const Text('تعديل التقرير'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _acting ? null : _submitAfterEdit,
                    child: const Text('إعادة الإرسال'),
                  ),
                ),
              ],
            ),
          ],
          if (canRelaunch) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _acting ? null : _showRelaunchDialog,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة إطلاق كتقرير جديد'),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
