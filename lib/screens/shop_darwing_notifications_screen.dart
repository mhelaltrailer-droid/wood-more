import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/shop_darwing_notification_model.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';
import '../utils/notification_delete_ui.dart';
import '../utils/notification_time_display.dart';
import '../widgets/shop_darwing_notification_app_bar_icon.dart';
import 'shop_drawing_detail_screen.dart';

class ShopDarwingNotificationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const ShopDarwingNotificationsScreen({super.key, required this.currentUser});

  @override
  State<ShopDarwingNotificationsScreen> createState() =>
      _ShopDarwingNotificationsScreenState();
}

class _ShopDarwingNotificationsScreenState
    extends State<ShopDarwingNotificationsScreen> {
  List<ShopDarwingNotificationModel> _items = const [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final storage = getStorage();
      final items = storage is ApiStorageService
          ? await storage.getShopDarwingNotifications(widget.currentUser.id)
          : await storage.getShopDarwingNotifications(widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final storage = getStorage();
      final items = storage is ApiStorageService
          ? await storage.getShopDarwingNotifications(widget.currentUser.id)
          : await storage.getShopDarwingNotifications(widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (_) {}
  }

  Future<void> _markAsRead(ShopDarwingNotificationModel item) async {
    if (item.isRead) return;
    final storage = getStorage();
    try {
      if (storage is ApiStorageService) {
        await storage.markShopDarwingNotificationRead(
          notificationId: item.id,
          userId: widget.currentUser.id,
        );
      } else {
        await storage.markShopDarwingNotificationRead(
          notificationId: item.id,
          userId: widget.currentUser.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _items = _items.map((n) {
          if (n.id != item.id) return n;
          return ShopDarwingNotificationModel(
            id: n.id,
            recipientUserId: n.recipientUserId,
            title: n.title,
            body: n.body,
            shopDrawingId: n.shopDrawingId,
            createdAt: n.createdAt,
            isRead: true,
            readAt: DateTime.now(),
          );
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _onNotificationTap(ShopDarwingNotificationModel item) async {
    await _markAsRead(item);
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
    }
  }

  Future<bool> _confirmDelete() => confirmDeleteNotification(context);

  Future<bool> _deleteNotification(ShopDarwingNotificationModel item) async {
    final storage = getStorage();
    try {
      await storage.deleteShopDarwingNotification(
        notificationId: item.id,
        userId: widget.currentUser.id,
      );
      if (mounted) {
        setState(() => _items = _items.where((n) => n.id != item.id).toList());
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إشعارات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'تعذر تحميل الإشعارات',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('لا توجد إشعارات حالياً')),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Dismissible(
          key: ValueKey('sd_notification_${item.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (_) async {
            if (!await _confirmDelete()) return false;
            return _deleteNotification(item);
          },
          background: notificationDismissDeleteBackground(Alignment.centerLeft),
          secondaryBackground:
              notificationDismissDeleteBackground(Alignment.centerRight),
          child: InkWell(
            onTap: () => _onNotificationTap(item),
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
                Row(
                  children: [
                    ShopDarwingNotificationAppBarIcon(
                      size: 20,
                      color: item.isRead
                          ? Colors.grey.shade700
                          : const Color(0xFF1B5E20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: item.isRead
                              ? Colors.grey.shade800
                              : const Color(0xFF1B5E20),
                        ),
                      ),
                    ),
                    if (!item.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.body),
                const SizedBox(height: 6),
                Text(
                  formatNotificationDateTime(item.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}
