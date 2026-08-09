import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense_statement_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/full_screen_image.dart';

/// عرض بيانات الصرف مع الحالة؛ اعتماد/رفض لمدير المشروعات المحدد، وحذف للمسؤول الأساسي.
class ExpenseStatementsScreen extends StatefulWidget {
  final UserModel currentUser;
  final String appBarTitle;

  /// إن وُجدت تُفلتر القائمة؛ وإلا تُعرض كل الحالات.
  final List<String>? statuses;

  /// إظهار أزرار اعتماد/رفض للبند قيد الانتظار (للمعتمد فقط).
  final bool allowRespond;

  /// إظهار حذف (للمسؤول الأساسي فقط يُفعَّل فعلياً).
  final bool allowDelete;

  /// عرض المحتوى بدون Scaffold أو AppBar (عند الاستخدام داخل تبويب).
  final bool embedded;

  const ExpenseStatementsScreen({
    super.key,
    required this.currentUser,
    this.appBarTitle = 'تقارير المصروفات',
    this.statuses,
    this.allowRespond = false,
    this.allowDelete = false,
    this.embedded = false,
  });

  @override
  State<ExpenseStatementsScreen> createState() => _ExpenseStatementsScreenState();
}

class _ExpenseStatementsScreenState extends State<ExpenseStatementsScreen> {
  final _db = getStorage();
  bool _loading = true;
  String? _error;
  List<ExpenseStatementModel> _items = [];

  bool get _canRespond =>
      widget.allowRespond && widget.currentUser.canApproveExpenseStatements;

  bool get _canDelete =>
      widget.allowDelete && widget.currentUser.canDeleteExpenseStatements;

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
      final list = await _db.getExpenseStatements(statuses: widget.statuses);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case ExpenseStatementModel.statusApproved:
        return Colors.green.shade700;
      case ExpenseStatementModel.statusRejected:
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  Future<void> _approve(ExpenseStatementModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اعتماد بيان الصرف'),
        content: Text(
          'تأكيد اعتماد البيان وخصم المبلغ ${item.amount.toStringAsFixed(2)} من رصيد ${item.submitterUserName}؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اعتماد')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.respondExpenseStatement(
        statementId: item.id,
        actorUserId: widget.currentUser.id,
        approve: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الاعتماد وخصم الرصيد'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reject(ExpenseStatementModel item) async {
    final reasonC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض بيان الصرف'),
        content: TextField(
          controller: reasonC,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض *',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
    final reason = reasonC.text.trim();
    reasonC.dispose();
    if (ok != true) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سبب الرفض مطلوب'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      await _db.respondExpenseStatement(
        statementId: item.id,
        actorUserId: widget.currentUser.id,
        approve: false,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفض البيان'), backgroundColor: Colors.orange),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _delete(ExpenseStatementModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف بيان الصرف'),
        content: const Text(
          'هل تريد حذف هذا البيان؟ إن كان معتمداً سيتم استرجاع المبلغ إلى الرصيد.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.deleteExpenseStatement(
        statementId: item.id,
        actorUserId: widget.currentUser.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _imageThumb(String? path) {
    if (path == null || path.trim().isEmpty) {
      return const Text('لا توجد صورة', style: TextStyle(color: Colors.grey));
    }
    return InkWell(
      onTap: () => showFullScreenImage(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          path,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 48),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final dateFmt = DateFormat('yyyy/MM/dd HH:mm', 'ar');
    return _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('لا توجد بيانات صرف'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          final statusColor = _statusColor(item.status);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.submitterUserName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.statusLabelAr,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'الموقع / المشروع: ${item.projectName?.trim().isNotEmpty == true ? item.projectName : '—'}',
                                  ),
                                  Text('بيان الصرف: ${item.description.trim().isEmpty ? '—' : item.description}'),
                                  Text(
                                    'قيمة المبلغ: ${item.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'التاريخ: ${dateFmt.format(item.createdAt.toLocal())}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                  if (item.isRejected &&
                                      item.rejectionReason != null &&
                                      item.rejectionReason!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'سبب الرفض: ${item.rejectionReason}',
                                      style: TextStyle(color: Colors.red.shade700),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  const Text('الصور المرفقة:', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  _imageThumb(item.imagePath),
                                  if (_canRespond && item.isPending) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () => _approve(item),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF1B5E20),
                                            ),
                                            child: const Text('اعتماد'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _reject(item),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            child: const Text('رفض'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_canDelete) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () => _delete(item),
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        label: const Text('حذف', style: TextStyle(color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
  }
}
