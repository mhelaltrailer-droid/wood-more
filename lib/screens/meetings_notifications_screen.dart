import 'package:flutter/material.dart';

import '../models/meeting_notification_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/meetings_ui.dart';
import '../utils/notification_delete_ui.dart';
import '../utils/notification_time_display.dart';
import '../widgets/meetings_notification_app_bar_icon.dart';
import 'meeting_detail_screen.dart';

class MeetingsNotificationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const MeetingsNotificationsScreen({super.key, required this.currentUser});

  @override
  State<MeetingsNotificationsScreen> createState() =>
      _MeetingsNotificationsScreenState();
}

class _MeetingsNotificationsScreenState
    extends State<MeetingsNotificationsScreen> {
  List<MeetingNotificationModel> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openAndLoad();
  }

  Future<void> _openAndLoad() async {
    final storage = getStorage();
    if (storage is ApiStorageService) {
      try {
        await storage.markAllMeetingsNotificationsRead(widget.currentUser.id);
      } catch (_) {}
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        throw Exception('يتطلب اتصال API');
      }
      final items = await storage.getMeetingsNotifications(widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = meetingsApiError(e);
      });
    }
  }

  Future<void> _onTap(MeetingNotificationModel item) async {
    final storage = getStorage();
    if (storage is ApiStorageService) {
      await openMeetingPdf(
        context: context,
        storage: storage,
        userId: widget.currentUser.id,
        meetingId: item.meetingId,
        fileType: item.fileType,
      );
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(
          currentUser: widget.currentUser,
          meetingId: item.meetingId,
        ),
      ),
    );
  }

  Future<bool> _delete(MeetingNotificationModel item) async {
    final storage = getStorage();
    if (storage is! ApiStorageService) return false;
    try {
      await storage.deleteMeetingsNotification(
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MeetingsNotificationAppBarIcon(size: 22),
            SizedBox(width: 10),
            Text('إشعارات الاجتماعات'),
          ],
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
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
              child: Text(_error!, textAlign: TextAlign.center),
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
          key: ValueKey('meeting_notification_${item.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (_) async {
            if (!await confirmDeleteNotification(context)) return false;
            return _delete(item);
          },
          background: notificationDismissDeleteBackground(Alignment.centerLeft),
          secondaryBackground:
              notificationDismissDeleteBackground(Alignment.centerRight),
          child: InkWell(
            onTap: () => _onTap(item),
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
                      MeetingsNotificationAppBarIcon(
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
