import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/invoices_owner_constants.dart';
import '../models/invoices_owner_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/notification_time_display.dart';
import 'invoices_owner_detail_screen.dart';
import 'invoices_owner_form_screen.dart';

class _TabDef {
  final String key;
  final String label;
  const _TabDef(this.key, this.label);
}

class InvoicesOwnerHubScreen extends StatefulWidget {
  final UserModel currentUser;
  final int initialTabIndex;

  const InvoicesOwnerHubScreen({
    super.key,
    required this.currentUser,
    this.initialTabIndex = 0,
  });

  @override
  State<InvoicesOwnerHubScreen> createState() => _InvoicesOwnerHubScreenState();
}

class _InvoicesOwnerHubScreenState extends State<InvoicesOwnerHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = getStorage();
  bool _loading = true;
  String? _error;
  final Map<String, List<InvoicesOwnerModel>> _lists = {};
  List<Map<String, dynamic>> _notifications = const [];
  int _unread = 0;
  Timer? _pollTimer;

  List<_TabDef> get _tabs {
    final user = widget.currentUser;
    if (user.canManageInvoicesOwner) {
      return const [
        _TabDef('all', 'الكل'),
        _TabDef('pending', 'قيد التداول'),
        _TabDef('approved', 'معتمدة'),
        _TabDef('notifications', 'إشعارات'),
      ];
    }
    if (user.canCreateInvoicesOwner) {
      return const [
        _TabDef('pending', 'معادة للتعديل'),
        _TabDef('sent', 'مرسلة'),
        _TabDef('approved', 'معتمدة'),
        _TabDef('notifications', 'إشعارات'),
      ];
    }
    return const [
      _TabDef('pending', 'بانتظار إجرائي'),
      _TabDef('approved', 'معتمدة'),
      _TabDef('notifications', 'إشعارات'),
    ];
  }

  @override
  void initState() {
    super.initState();
    final tabs = _tabs;
    var idx = widget.initialTabIndex;
    if (idx >= tabs.length) idx = 0;
    _tabController =
        TabController(length: tabs.length, vsync: this, initialIndex: idx);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _loadTab(_tabs[_tabController.index].key);
    });
    _loadAll();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => _refreshSilently());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (_storage is! ApiStorageService) return;
    try {
      final items =
          await _storage.getInvoicesOwnerNotifications(widget.currentUser.id);
      final count = await _storage
          .getUnreadInvoicesOwnerNotificationsCount(widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _unread = count;
      });
    } catch (_) {}
  }

  Future<void> _loadTab(String tabKey) async {
    if (tabKey == 'notifications') {
      await _loadNotifications();
      return;
    }
    if (_storage is! ApiStorageService) {
      setState(() {
        _error = 'يتطلب اتصال API';
        _loading = false;
      });
      return;
    }
    try {
      final items = await _storage.getInvoicesOwnerInbox(
        userId: widget.currentUser.id,
        tab: tabKey,
      );
      if (!mounted) return;
      setState(() {
        _lists[tabKey] = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    for (final t in _tabs) {
      if (t.key != 'notifications') {
        await _loadTab(t.key);
      }
    }
    await _loadNotifications();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refreshSilently() async {
    final tab = _tabs[_tabController.index].key;
    await _loadTab(tab);
    await _loadNotifications();
  }

  Future<void> _openInvoice(InvoicesOwnerModel invoice) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoicesOwnerDetailScreen(
          currentUser: widget.currentUser,
          invoiceId: invoice.id,
        ),
      ),
    );
    if (changed == true) await _loadAll();
  }

  Future<void> _openNew() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            InvoicesOwnerFormScreen(currentUser: widget.currentUser),
      ),
    );
    if (created == true) await _loadAll();
  }

  Future<void> _onNotificationTap(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    final invoiceId = item['invoice_id'] as int?;
    final isRead = item['is_read'] == true;
    if (_storage is ApiStorageService && id != null && !isRead) {
      await _storage.markInvoicesOwnerNotificationRead(
        notificationId: id,
        userId: widget.currentUser.id,
      );
    }
    if (invoiceId != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoicesOwnerDetailScreen(
            currentUser: widget.currentUser,
            invoiceId: invoiceId,
          ),
        ),
      );
      await _loadAll();
      return;
    }
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: const Text(invoicesOwnerHomeIconLabel),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: tabs.map((t) {
            if (t.key == 'notifications' && _unread > 0) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.label),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unread',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Tab(text: t.label);
          }).toList(),
        ),
      ),
      floatingActionButton: widget.currentUser.canCreateInvoicesOwner
          ? FloatingActionButton.extended(
              onPressed: _openNew,
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'New Progress +',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && !_lists.values.any((l) => l.isNotEmpty)
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              : TabBarView(
                  controller: _tabController,
                  children: tabs.map((t) {
                    if (t.key == 'notifications') {
                      return _buildNotificationsTab();
                    }
                    return _buildListTab(
                      items: _lists[t.key] ?? const [],
                      fmt: fmt,
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildListTab({
    required List<InvoicesOwnerModel> items,
    required DateFormat fmt,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('لا توجد طلبات في هذا القسم')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final d = items[index];
          return Card(
            child: ListTile(
              onTap: () => _openInvoice(d),
              title: Text(
                d.projectName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.statusLabelAr),
                  Text('${d.createdByUserName} — ${fmt.format(d.updatedAt)}'),
                  if (d.returnReason != null &&
                      d.returnReason!.trim().isNotEmpty)
                    Text('سبب الإعادة: ${d.returnReason}'),
                ],
              ),
              trailing: d.attachments.isNotEmpty
                  ? Text('${d.attachments.length} ملف')
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsTab() {
    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('لا إشعارات')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final n = _notifications[index];
          final isRead = n['is_read'] == true;
          final title = (n['title'] ?? '').toString();
          final body = (n['body'] ?? '').toString();
          final createdAt = DateTime.tryParse((n['created_at'] ?? '').toString());
          return Card(
            color: isRead ? null : const Color(0xFFE8F5E9),
            child: ListTile(
              onTap: () => _onNotificationTap(n),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body),
                  if (createdAt != null)
                    Text(
                      formatNotificationDateTimeCompact(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
