import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/custody_expense_log_entry.dart';
import '../models/user_model.dart';
import '../services/custody_expense_log_service.dart';
import '../utils/full_screen_image.dart';
import 'expense_statements_screen.dart';

const Color _kPrimary = Color(0xFF1B5E20);

/// العهدة/المصروفات لمدير العمليات والمسؤول الأساسي: بيانات الصرف كما هي،
/// إضافة إلى سجل حركات العهد والمصروفات للعرض فقط.
class CustodyExpensesViewScreen extends StatefulWidget {
  final UserModel currentUser;
  final String appBarTitle;

  const CustodyExpensesViewScreen({
    super.key,
    required this.currentUser,
    this.appBarTitle = 'العهده/ المصروفات',
  });

  @override
  State<CustodyExpensesViewScreen> createState() =>
      _CustodyExpensesViewScreenState();
}

class _CustodyExpensesViewScreenState extends State<CustodyExpensesViewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd HH:mm', 'ar');

  bool _loading = true;
  String? _error;
  List<CustodyExpenseLogEntry> _entries = const [];
  List<UserModel> _users = const [];
  DateTime? _newSince;

  /// يُسكت العدّاد بمجرد فتح تبويب السجل، مع إبقاء شارات «جديد» ظاهرة.
  bool _logOpened = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.index != 1 || _logOpened) return;
    setState(() => _logOpened = true);
    CustodyExpenseLogSeen.markSeenNow(widget.currentUser.id);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seen = await CustodyExpenseLogSeen.lastSeenOrBaseline(
        widget.currentUser.id,
      );
      final log = await loadCustodyExpenseLog();
      if (!mounted) return;
      setState(() {
        _entries = log.entries;
        _users = log.users;
        _newSince = seen;
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

  int get _unreadCount {
    final since = _newSince;
    if (_logOpened || since == null) return 0;
    return _entries.where((e) => e.occurredAt.isAfter(since)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'بيانات الصرف'),
            Tab(child: _logTabLabel()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ExpenseStatementsScreen(
            currentUser: widget.currentUser,
            statuses: const ['approved', 'rejected'],
            allowRespond: false,
            allowDelete: widget.currentUser.canDeleteExpenseStatements,
            embedded: true,
          ),
          _MovementsLogTab(
            loading: _loading,
            error: _error,
            entries: _entries,
            users: _users,
            newSince: _newSince,
            dateFormat: _dateFormat,
            onRefresh: _load,
          ),
        ],
      ),
    );
  }

  Widget _logTabLabel() {
    final count = _unreadCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Flexible(child: Text('سجل الحركات', overflow: TextOverflow.ellipsis)),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count > 99 ? '+99' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MovementsLogTab extends StatefulWidget {
  final bool loading;
  final String? error;
  final List<CustodyExpenseLogEntry> entries;
  final List<UserModel> users;
  final DateTime? newSince;
  final DateFormat dateFormat;
  final Future<void> Function() onRefresh;

  const _MovementsLogTab({
    required this.loading,
    required this.error,
    required this.entries,
    required this.users,
    required this.newSince,
    required this.dateFormat,
    required this.onRefresh,
  });

  @override
  State<_MovementsLogTab> createState() => _MovementsLogTabState();
}

class _MovementsLogTabState extends State<_MovementsLogTab> {
  CustodyLogCategory? _category;
  int? _userId;

  List<UserModel> get _userOptions {
    final involved = <int>{};
    for (final e in widget.entries) {
      if (e.actorUserId != null) involved.add(e.actorUserId!);
      if (e.targetUserId != null) involved.add(e.targetUserId!);
    }
    final options =
        widget.users.where((u) => involved.contains(u.id)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  List<CustodyExpenseLogEntry> get _filtered {
    return widget.entries.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_userId != null && !e.matchesUser(_userId!)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onRefresh,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filtered;
    return Column(
      children: [
        _filters(),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                        child: Text(
                          widget.entries.isEmpty
                              ? 'لا توجد حركات مسجّلة بعد.\nتظهر هنا إضافة وسحب الأرصدة وبيانات الصرف بعد البت فيها.'
                              : 'لا توجد حركات مطابقة للفلتر المحدد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _entryCard(items[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<CustodyLogCategory?>(
              value: _category,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'نوع الحركة',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('الكل')),
                DropdownMenuItem(
                  value: CustodyLogCategory.balance,
                  child: Text('حركات الأرصدة'),
                ),
                DropdownMenuItem(
                  value: CustodyLogCategory.expense,
                  child: Text('بيانات الصرف'),
                ),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<int?>(
              value: _userId,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'المستخدم',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('الكل')),
                for (final u in _userOptions)
                  DropdownMenuItem(
                    value: u.id,
                    child: Text(u.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _userId = v),
            ),
          ),
        ],
      ),
    );
  }

  Color _accentColor(CustodyExpenseLogEntry e) {
    if (e.isBalance) {
      return e.isAddBalance ? Colors.green.shade700 : Colors.orange.shade800;
    }
    return e.isRejected ? Colors.red.shade700 : _kPrimary;
  }

  IconData _icon(CustodyExpenseLogEntry e) {
    if (e.isBalance) {
      return e.isAddBalance ? Icons.add_card : Icons.money_off;
    }
    return e.isRejected ? Icons.receipt_long_outlined : Icons.receipt_long;
  }

  Widget _entryCard(CustodyExpenseLogEntry e) {
    final accent = _accentColor(e);
    final since = widget.newSince;
    final isNew = since != null && e.occurredAt.isAfter(since);
    final decision = e.decisionNote;
    final description = e.description.trim();
    final project = e.projectName?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(_icon(e), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          e.sentence,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'جديد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.dateFormat.format(e.occurredAt.toLocal()),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  if (!e.isBalance) ...[
                    if (project.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('الموقع / المشروع: $project'),
                      ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('بيان الصرف: $description'),
                      ),
                    if (decision != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          decision,
                          style: TextStyle(fontSize: 12, color: accent),
                        ),
                      ),
                    if (e.isRejected &&
                        (e.rejectionReason?.trim().isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'سبب الرفض: ${e.rejectionReason!.trim()}',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    if (e.imagePath?.trim().isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _imageThumb(e.imagePath!),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageThumb(String path) {
    return InkWell(
      onTap: () => showFullScreenImage(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          path,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 40),
        ),
      ),
    );
  }
}
