import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/notification_item_model.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';
import 'reports_sys_detail_screen.dart';
import 'reports_sys_hub_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItemModel> _items = const [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
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
          ? await storage.getNotificationsForUser(widget.currentUser.id)
          : await storage.getNotificationsForUser(widget.currentUser.id);
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
          ? await storage.getNotificationsForUser(widget.currentUser.id)
          : await storage.getNotificationsForUser(widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (_) {}
  }

  Future<void> _markAsRead(NotificationItemModel item) async {
    if (item.isRead) return;
    final storage = getStorage();
    try {
      if (storage is ApiStorageService) {
        await storage.markNotificationRead(
          notificationId: item.id,
          userId: widget.currentUser.id,
        );
      } else {
        await storage.markNotificationRead(
          notificationId: item.id,
          userId: widget.currentUser.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _items = _items.map((n) {
          if (n.id != item.id) return n;
          return NotificationItemModel(
            id: n.id,
            recipientUserId: n.recipientUserId,
            recipientRole: n.recipientRole,
            title: n.title,
            body: n.body,
            eventType: n.eventType,
            actorUserId: n.actorUserId,
            actorUserName: n.actorUserName,
            projectName: n.projectName,
            createdAt: n.createdAt,
            isRead: true,
            readAt: DateTime.now(),
          );
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _onNotificationTap(NotificationItemModel item) async {
    await _markAsRead(item);
    final reportId = parseReportsSysIdFromEventType(item.eventType);
    if (reportId == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportsSysDetailScreen(
          currentUser: widget.currentUser,
          reportId: reportId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
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
        return InkWell(
          onTap: () {
            if (item.eventType.startsWith('reports_sys_')) {
              _onNotificationTap(item);
            } else {
              _markAsRead(item);
            }
          },
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
                    Icon(
                      Icons.notifications_active_outlined,
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
                  DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(item.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
