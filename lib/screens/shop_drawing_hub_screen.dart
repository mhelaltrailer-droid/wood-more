import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/shop_drawing_constants.dart';
import '../models/shop_darwing_notification_model.dart';
import '../models/shop_drawing_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/notification_delete_ui.dart';
import '../utils/shop_drawing_status_timeline.dart';
import 'shop_drawing_detail_screen.dart';
import 'shop_drawing_form_screen.dart';

class _TabDef {
  final String key;
  final String label;
  const _TabDef(this.key, this.label);
}

class ShopDrawingHubScreen extends StatefulWidget {
  final UserModel currentUser;
  final String documentType;
  final int initialTabIndex;

  const ShopDrawingHubScreen({
    super.key,
    required this.currentUser,
    required this.documentType,
    this.initialTabIndex = 0,
  });

  @override
  State<ShopDrawingHubScreen> createState() => _ShopDrawingHubScreenState();
}

class _ShopDrawingHubScreenState extends State<ShopDrawingHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = getStorage();
  bool _loading = true;
  String? _error;
  final Map<String, List<ShopDrawingModel>> _lists = {};
  List<ShopDarwingNotificationModel> _moduleNotifications = const [];
  int _moduleUnread = 0;
  Timer? _pollTimer;

  List<_TabDef> get _tabs {
    final user = widget.currentUser;
    if (user.isTechnicalOffice) {
      return const [
        _TabDef('pending', 'معادة للتعديل'),
        _TabDef('sent', 'مرسلة'),
        _TabDef('approved', 'معتمدة'),
        _TabDef('notifications', 'إشعارات'),
      ];
    }
    if (user.isShopDrawingProjectManager) {
      return const [
        _TabDef('pending', 'بانتظار إجرائي'),
        _TabDef('approved', 'معتمدة'),
        _TabDef('notifications', 'إشعارات'),
      ];
    }
    if (user.isOperationManager || user.canManageShopDrawingApproved) {
      return const [
        _TabDef('pending', 'بانتظار اعتمادي'),
        _TabDef('approved', 'معتمد'),
        _TabDef('all', 'الكل'),
      ];
    }
    if (user.isTopManagement) {
      return const [
        _TabDef('approved', 'معتمد'),
        _TabDef('all', 'الكل'),
      ];
    }
    return const [_TabDef('approved', 'معتمد')];
  }

  bool get _showModuleNotifications =>
      widget.currentUser.canSeeShopDrawingModuleNotifications;

  String get _typeLabel => shopDrawingDocumentTypeLabel(widget.documentType);

  @override
  void initState() {
    super.initState();
    final tabs = _tabs;
    var idx = widget.initialTabIndex;
    if (idx >= tabs.length) idx = 0;
    _tabController = TabController(length: tabs.length, vsync: this, initialIndex: idx);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _loadTab(_tabs[_tabController.index].key);
    });
    _loadAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) => _refreshSilently());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModuleNotifications() async {
    if (!_showModuleNotifications || _storage is! ApiStorageService) return;
    try {
      final items = await _storage.getShopDrawingModuleNotifications(
        widget.currentUser.id,
        documentType: widget.documentType,
      );
      final count = await _storage.getUnreadShopDrawingModuleNotificationsCount(
        widget.currentUser.id,
        documentType: widget.documentType,
      );
      if (!mounted) return;
      setState(() {
        _moduleNotifications = items;
        _moduleUnread = count;
      });
    } catch (_) {}
  }

  Future<void> _loadTab(String tabKey) async {
    if (tabKey == 'notifications') {
      await _loadModuleNotifications();
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
      final items = await _storage.getShopDrawingInbox(
        userId: widget.currentUser.id,
        tab: tabKey,
        documentType: widget.documentType,
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
    await _loadModuleNotifications();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refreshSilently() async {
    final tab = _tabs[_tabController.index].key;
    await _loadTab(tab);
    await _loadModuleNotifications();
  }

  Future<void> _openDrawing(ShopDrawingModel drawing) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShopDrawingDetailScreen(
          currentUser: widget.currentUser,
          drawingId: drawing.id,
        ),
      ),
    );
    if (changed == true) await _loadAll();
  }

  Future<void> _openNew() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShopDrawingFormScreen(
          currentUser: widget.currentUser,
          documentType: widget.documentType,
        ),
      ),
    );
    if (created == true) await _loadAll();
  }

  Future<void> _onModuleNotificationTap(ShopDarwingNotificationModel item) async {
    if (_storage is ApiStorageService && !item.isRead) {
      await _storage.markShopDrawingModuleNotificationRead(
        notificationId: item.id,
        userId: widget.currentUser.id,
      );
    }
    final drawingId = item.shopDrawingId;
    if (drawingId != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShopDrawingDetailScreen(
            currentUser: widget.currentUser,
            drawingId: drawingId,
          ),
        ),
      );
      await _loadAll();
      return;
    }
    await _loadModuleNotifications();
  }

  Future<bool> _deleteModuleNotification(ShopDarwingNotificationModel item) async {
    if (_storage is! ApiStorageService) return false;
    try {
      await _storage.deleteShopDarwingNotification(
        notificationId: item.id,
        userId: widget.currentUser.id,
      );
      if (mounted) {
        setState(() {
          _moduleNotifications =
              _moduleNotifications.where((n) => n.id != item.id).toList();
          if (!item.isRead && _moduleUnread > 0) _moduleUnread--;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حذف الإشعار')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: Text(_typeLabel),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: tabs.map((t) {
            if (t.key == 'notifications' && _moduleUnread > 0) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.label),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_moduleUnread',
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
      floatingActionButton: widget.currentUser.isTechnicalOffice
          ? FloatingActionButton.extended(
              onPressed: _openNew,
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text(
                'رفع جديد',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && !_lists.values.any((l) => l.isNotEmpty)
                    ? Center(
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: tabs.map((t) {
                          if (t.key == 'notifications') {
                            return _buildNotificationsTab(fmt);
                          }
                          return _buildDrawingsTab(
                            items: _lists[t.key] ?? const [],
                            fmt: fmt,
                            emptyMessage: 'لا توجد طلبات في هذا القسم',
                          );
                        }).toList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingsTab({
    required List<ShopDrawingModel> items,
    required DateFormat fmt,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(child: Text(emptyMessage)),
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
          if (widget.currentUser.isTopManagement) {
            return _buildTopManagementCard(d, fmt);
          }
          return Card(
            child: ListTile(
              onTap: () => _openDrawing(d),
              title: Text(
                d.projectName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.statusLabelAr),
                  Text('${d.createdByUserName} — ${fmt.format(d.updatedAt)}'),
                  if (d.returnReason != null && d.returnReason!.trim().isNotEmpty)
                    Text('سبب الإعادة: ${d.returnReason}'),
                ],
              ),
              trailing: Text(
                [
                  if (d.attachments.isNotEmpty) '${d.attachments.length} ملف',
                  if (d.externalUrl != null && d.externalUrl!.trim().isNotEmpty)
                    'رابط',
                ].join(' · '),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopManagementCard(ShopDrawingModel d, DateFormat fmt) {
    final timeline = buildShopDrawingStatusTimeline(d, formatter: fmt);
    return Card(
      child: InkWell(
        onTap: () => _openDrawing(d),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                d.projectName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'رقم الطلب: ${d.id} — ${d.documentTypeLabel}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              ...timeline.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        line.isPending ? Icons.schedule : Icons.check_circle_outline,
                        size: 16,
                        color: line.isPending
                            ? Colors.orange.shade800
                            : const Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                line.isPending ? FontWeight.w600 : FontWeight.normal,
                            color: line.isPending
                                ? Colors.orange.shade900
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(DateFormat fmt) {
    if (_moduleNotifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadModuleNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('لا توجد إشعارات')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadModuleNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _moduleNotifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _moduleNotifications[index];
          return Dismissible(
            key: ValueKey('sd_module_notification_${item.id}'),
            direction: DismissDirection.horizontal,
            confirmDismiss: (_) async {
              if (!await confirmDeleteNotification(context)) return false;
              return _deleteModuleNotification(item);
            },
            background: notificationDismissDeleteBackground(Alignment.centerLeft),
            secondaryBackground:
                notificationDismissDeleteBackground(Alignment.centerRight),
            child: InkWell(
            onTap: () => _onModuleNotificationTap(item),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: item.isRead
                    ? Colors.grey.shade100
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.isRead
                      ? Colors.grey.shade300
                      : const Color(0xFF1B5E20).withOpacity(0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: item.isRead
                          ? Colors.grey.shade800
                          : const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(item.body),
                  const SizedBox(height: 4),
                  Text(
                    fmt.format(item.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      ),
    );
  }
}
