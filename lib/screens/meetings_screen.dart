import 'dart:async';

import 'package:flutter/material.dart';

import '../models/meeting_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/meetings_ui.dart';
import '../utils/notification_time_display.dart';
import '../widgets/meetings_icon.dart';
import 'meeting_create_screen.dart';
import 'meeting_detail_screen.dart';

class MeetingsScreen extends StatefulWidget {
  final UserModel currentUser;

  const MeetingsScreen({super.key, required this.currentUser});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _searchC = TextEditingController();
  List<MeetingModel> _items = const [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _markAllRead();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    try {
      await storage.markAllMeetingsNotificationsRead(widget.currentUser.id);
    } catch (_) {}
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        throw Exception('يتطلب اتصال API');
      }
      final items = await storage.getMeetings(
        userId: widget.currentUser.id,
        query: query,
      );
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(query: value.trim());
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MeetingCreateScreen(currentUser: widget.currentUser),
      ),
    );
    if (created == true) {
      await _load(query: _searchC.text.trim());
    }
  }

  Future<void> _openDetail(MeetingModel meeting) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(
          currentUser: widget.currentUser,
          meetingId: meeting.id,
        ),
      ),
    );
    await _load(query: _searchC.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MeetingsIcon(size: 22, color: Colors.white),
            SizedBox(width: 10),
            Text('Meetings'),
          ],
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: widget.currentUser.canUploadMeetings
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Call of Meeting'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchC,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'بحث برقم الاجتماع أو الموضوع',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('لا توجد اجتماعات'));
    }
    return RefreshIndicator(
      onRefresh: () => _load(query: _searchC.text.trim()),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = _items[index];
          return InkWell(
            onTap: () => _openDetail(item),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1B5E20).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اجتماع ${item.meetingNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(item.subject),
                  const SizedBox(height: 4),
                  Text(
                    formatNotificationDateTime(item.scheduledAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
