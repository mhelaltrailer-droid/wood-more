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

  /// إن وُجدت كانت تُفلتر من الـ API سابقاً؛ الفلاتر في الواجهة أصبحت المصدر الأساسي.
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

  /// null = الكل؛ وإلا إحدى حالات البيان.
  String? _statusFilter = ExpenseStatementModel.statusPending;

  /// null = الكل.
  int? _engineerUserId;
  String? _engineerUserName;

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
      // تحميل كل الحالات لتمكين فلتر الواجهة (انتظار / معتمد / مرفوض / الكل).
      final list = await _db.getExpenseStatements();
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

  static bool _startsWithArabic(String name) {
    final t = name.trim();
    if (t.isEmpty) return false;
    final c = t.runes.first;
    return c >= 0x0600 && c <= 0x06FF;
  }

  /// عربي أولاً، ثم إنجليزي/غيره أبجدياً.
  static int _compareNamesArThenEn(String a, String b) {
    final aAr = _startsWithArabic(a);
    final bAr = _startsWithArabic(b);
    if (aAr && !bAr) return -1;
    if (!aAr && bAr) return 1;
    return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
  }

  List<ExpenseStatementModel> get _itemsForStatus {
    if (_statusFilter == null) return _items;
    return _items.where((e) => e.status == _statusFilter).toList();
  }

  List<({int id, String name})> get _engineerOptions {
    final map = <int, String>{};
    for (final e in _itemsForStatus) {
      if (e.submitterUserId <= 0) continue;
      final name = e.submitterUserName.trim();
      map[e.submitterUserId] = name.isEmpty ? 'مستخدم #${e.submitterUserId}' : name;
    }
    final list = map.entries
        .map((e) => (id: e.key, name: e.value))
        .toList();
    list.sort((a, b) => _compareNamesArThenEn(a.name, b.name));
    return list;
  }

  List<ExpenseStatementModel> get _filteredItems {
    var list = _itemsForStatus;
    if (_engineerUserId != null) {
      list = list.where((e) => e.submitterUserId == _engineerUserId).toList();
    }
    return list;
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

  Widget _filtersBar() {
    final engineers = _engineerOptions;
    final engineerInList =
        _engineerUserId != null && engineers.any((e) => e.id == _engineerUserId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _engineerUserId,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المهندس',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('الكل')),
                for (final e in engineers)
                  DropdownMenuItem<int?>(
                    value: e.id,
                    child: Text(e.name, overflow: TextOverflow.ellipsis),
                  ),
                if (_engineerUserId != null && !engineerInList)
                  DropdownMenuItem<int?>(
                    value: _engineerUserId,
                    child: Text(
                      _engineerUserName?.trim().isNotEmpty == true
                          ? _engineerUserName!
                          : 'مستخدم #$_engineerUserId',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                setState(() {
                  _engineerUserId = v;
                  if (v == null) {
                    _engineerUserName = null;
                  } else {
                    final match = engineers.where((e) => e.id == v);
                    if (match.isNotEmpty) {
                      _engineerUserName = match.first.name;
                    }
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _statusFilter,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'حالة الطلب',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem<String?>(
                  value: ExpenseStatementModel.statusPending,
                  child: Text('انتظار الاعتماد'),
                ),
                DropdownMenuItem<String?>(
                  value: ExpenseStatementModel.statusApproved,
                  child: Text('معتمد'),
                ),
                DropdownMenuItem<String?>(
                  value: ExpenseStatementModel.statusRejected,
                  child: Text('مرفوض'),
                ),
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('الكل'),
                ),
              ],
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
          ),
        ],
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
    final dayFmt = DateFormat('yyyy/MM/dd', 'ar');
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
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
      );
    }

    final filtered = _filteredItems;
    final emptyMessage = _items.isEmpty
        ? 'لا توجد بيانات صرف'
        : 'لا يوجد بيانات صرف حسب التصفية المحددة';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filtersBar(),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(emptyMessage))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
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
                                      color: statusColor.withValues(alpha: 0.15),
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
                              Text(
                                'بيان الصرف: ${item.description.trim().isEmpty ? '—' : item.description}',
                              ),
                              Text(
                                'قيمة المبلغ: ${item.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                item.datesLabelAr(dayFormat: dayFmt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
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
                              const Text(
                                'الصور المرفقة:',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    label: const Text(
                                      'حذف',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
