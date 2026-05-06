import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/private_chat_message_model.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';

class PrivateChatScreen extends StatefulWidget {
  final UserModel currentUser;

  const PrivateChatScreen({super.key, required this.currentUser});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  List<PrivateChatMessageModel> _messages = const [];

  String get _peerEmail {
    final me = widget.currentUser.email.trim().toLowerCase();
    return me == 'mouhammedhelal@gmail.com'
        ? 'islam.shams2050@gmail.com'
        : 'mouhammedhelal@gmail.com';
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final storage = getStorage();
      final list = storage is ApiStorageService
          ? await storage.getPrivateChatMessages(
              requesterEmail: widget.currentUser.email,
            )
          : await storage.getPrivateChatMessages(
              requesterEmail: widget.currentUser.email,
            );
      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final storage = getStorage();
      if (storage is ApiStorageService) {
        await storage.sendPrivateChatMessage(
          senderEmail: widget.currentUser.email,
          senderName: widget.currentUser.name,
          receiverEmail: _peerEmail,
          body: text,
        );
      } else {
        await storage.sendPrivateChatMessage(
          senderEmail: widget.currentUser.email,
          senderName: widget.currentUser.name,
          receiverEmail: _peerEmail,
          body: text,
        );
      }
      _inputController.clear();
      await _loadMessages(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الرسالة: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.currentUser.email.trim().toLowerCase();
    final dateFmt = DateFormat('hh:mm a', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة خاصة'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final mine = m.senderEmail.trim().toLowerCase() == me;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: mine
                                ? const Color(0xFF1B5E20)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.body,
                                style: TextStyle(
                                  color: mine ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateFmt.format(m.createdAt.toLocal()),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: mine
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x22000000))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
