import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/notification_item_model.dart';
import '../models/withdrawal_request_model.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';
import '../utils/notification_delete_ui.dart';
import '../utils/notification_time_display.dart';
import 'engineer_withdraw_materials_screen.dart';
import 'notification_attachments_screen.dart';
import 'reports_sys_detail_screen.dart';
import 'reports_sys_hub_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// حجم الصفحة الواحدة — القائمة تنمو بالتمرير بدل تحميل كل الإشعارات دفعة واحدة.
  static const int _pageSize = 30;

  /// أقصى عدد يعيده الخادم في طلب واحد، يحدّ سقف التحديث الصامت.
  static const int _maxRefreshLimit = 200;

  List<NotificationItemModel> _items = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  Timer? _pollTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<List<NotificationItemModel>> _fetchPage({
    required int limit,
    required int offset,
  }) async {
    final storage = getStorage();
    if (storage is ApiStorageService) {
      return storage.getNotificationsForUser(
        widget.currentUser.id,
        limit: limit,
        offset: offset,
      );
    }
    final items = await storage.getNotificationsForUser(widget.currentUser.id);
    return List<NotificationItemModel>.from(items as List);
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _fetchPage(limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasMore = items.length >= _pageSize;
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _fetchPage(limit: _pageSize, offset: _items.length);
      if (!mounted) return;
      final existingIds = _items.map((e) => e.id).toSet();
      final fresh = more.where((e) => !existingIds.contains(e.id)).toList();
      setState(() {
        _items = [..._items, ...fresh];
        _hasMore = more.length >= _pageSize && fresh.isNotEmpty;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refreshSilently() async {
    try {
      // يُعاد تحميل ما هو ظاهر فقط حتى لا يقفز المستخدم لأعلى القائمة.
      final limit = _items.length < _pageSize
          ? _pageSize
          : (_items.length > _maxRefreshLimit ? _maxRefreshLimit : _items.length);
      final items = await _fetchPage(limit: limit, offset: 0);
      if (!mounted) return;
      setState(() {
        _items = items;
        _hasMore = items.length >= limit;
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
            withdrawalRequestId: n.withdrawalRequestId,
            actionTakenAt: n.actionTakenAt,
            attachmentSource: n.attachmentSource,
            attachmentRecordId: n.attachmentRecordId,
            attachmentCount: n.attachmentCount,
          );
        }).toList();
      });
    } catch (_) {}
  }

  /// فتح مرفقات الإشعار مباشرة في عارض المرفقات.
  Future<void> _openAttachments(NotificationItemModel item) async {
    await _markAsRead(item);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationAttachmentsScreen(
          currentUser: widget.currentUser,
          source: item.attachmentSource!,
          recordId: item.attachmentRecordId!,
          fallbackTitle: item.title,
        ),
      ),
    );
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

  /// فتح مكان العمل المعتمد مباشرة من إشعار الموافقة على طلب السحب.
  Future<void> _openApprovedWithdrawalLocation(
    NotificationItemModel item,
  ) async {
    await _markAsRead(item);
    final requestId = item.withdrawalRequestId;
    if (requestId == null) return;
    WithdrawalRequestModel? request;
    try {
      request = await getStorage().getWithdrawalRequestById(requestId)
          as WithdrawalRequestModel?;
    } catch (_) {
      request = null;
    }
    if (!mounted) return;
    final target = request;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح مكان العمل الخاص بالطلب')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EngineerWithdrawMaterialsScreen(
          user: widget.currentUser,
          initialProjectId: target.projectId,
          initialLocationId: target.locationId,
        ),
      ),
    );
  }

  Future<bool> _deleteNotification(NotificationItemModel item) async {
    if (item.isWithdrawalPendingAction) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(withdrawalNotificationDeleteBlockedMessage)),
        );
      }
      return false;
    }
    final storage = getStorage();
    try {
      await storage.deleteNotification(
        notificationId: item.id,
        userId: widget.currentUser.id,
      );
      if (mounted) {
        setState(() => _items = _items.where((n) => n.id != item.id).toList());
      }
      return true;
    } catch (e) {
      final msg = '$e';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('action_required_before_delete')
                  ? withdrawalNotificationDeleteBlockedMessage
                  : 'تعذر حذف الإشعار',
            ),
          ),
        );
      }
      return false;
    }
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
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = _items[index];
        return Dismissible(
          key: ValueKey('notification_${item.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (_) async {
            if (item.isWithdrawalPendingAction) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(withdrawalNotificationDeleteBlockedMessage),
                  ),
                );
              }
              return false;
            }
            if (!await confirmDeleteNotification(context)) return false;
            return _deleteNotification(item);
          },
          background: notificationDismissDeleteBackground(Alignment.centerLeft),
          secondaryBackground:
              notificationDismissDeleteBackground(Alignment.centerRight),
          child: InkWell(
          onTap: () {
            if (item.hasAttachments) {
              _openAttachments(item);
            } else if (item.eventType.startsWith('reports_sys_')) {
              _onNotificationTap(item);
            } else if (item.eventType == 'withdrawal_request_approved' &&
                item.withdrawalRequestId != null) {
              _openApprovedWithdrawalLocation(item);
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
                if (item.hasAttachments) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 16,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.attachmentCount != null && item.attachmentCount! > 0
                            ? 'اضغط لعرض ${item.attachmentCount} مرفق'
                            : 'اضغط لعرض المرفقات',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
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
