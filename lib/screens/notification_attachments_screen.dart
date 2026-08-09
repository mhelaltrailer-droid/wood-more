import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/notification_attachment_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/open_stored_attachment.dart';

/// عارض المرفقات المفتوح من الإشعار: الصور تُعرض داخل التطبيق بمعرض قابل
/// للتكبير والتمرير، وبقية الملفات تُفتح ببرنامج النظام.
class NotificationAttachmentsScreen extends StatefulWidget {
  final UserModel currentUser;
  final String source;
  final int recordId;

  /// عنوان مبدئي يظهر ريثما يصل عنوان السجل من الخادم.
  final String fallbackTitle;

  const NotificationAttachmentsScreen({
    super.key,
    required this.currentUser,
    required this.source,
    required this.recordId,
    this.fallbackTitle = 'المرفقات',
  });

  @override
  State<NotificationAttachmentsScreen> createState() =>
      _NotificationAttachmentsScreenState();
}

class _NotificationAttachmentsScreenState
    extends State<NotificationAttachmentsScreen> {
  final _storage = getStorage();
  final Map<String, Uint8List> _bytesCache = {};

  /// طلبات الجلب الجارية — تُشارَك بين الشبكة المصغّرة والمعرض حتى لا يُجلب
  /// الملف مرتين ولا يبقى المعرض عالقاً على مؤشر تحميل.
  final Map<String, Future<Uint8List?>> _inFlight = {};

  bool _isLoadingList = true;
  String? _error;
  NotificationAttachmentList? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoadingList = true;
      _error = null;
    });
    try {
      final result = await _storage.getNotificationAttachments(
            userId: widget.currentUser.id,
            source: widget.source,
            recordId: widget.recordId,
          ) as NotificationAttachmentList;
      if (!mounted) return;
      setState(() {
        _list = result;
        _isLoadingList = false;
      });
      _prefetchImages(result.items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError('$e');
        _isLoadingList = false;
      });
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('forbidden')) return 'ليس لديك صلاحية عرض هذه المرفقات';
    if (raw.contains('record_not_found')) return 'السجل الأصلي لم يعد موجوداً';
    if (raw.contains('unknown_attachment_source')) {
      return 'نوع المرفقات غير مدعوم في هذه النسخة من التطبيق';
    }
    return 'تعذر تحميل المرفقات';
  }

  /// الصور تُجلب تلقائياً لعرض المعاينة، أما الملفات فتُجلب عند الفتح فقط.
  Future<void> _prefetchImages(List<NotificationAttachmentModel> items) async {
    for (final item in items) {
      if (!item.isImage || !item.canOpen) continue;
      await _loadBytes(item);
      if (!mounted) return;
    }
  }

  Future<Uint8List?> _loadBytes(NotificationAttachmentModel item) {
    final cached = _bytesCache[item.id];
    if (cached != null) return Future<Uint8List?>.value(cached);
    final existing = _inFlight[item.id];
    if (existing != null) return existing;
    final future = _fetchBytes(item);
    _inFlight[item.id] = future;
    return future;
  }

  Future<Uint8List?> _fetchBytes(NotificationAttachmentModel item) async {
    Uint8List? bytes;
    try {
      final file = await _storage.getNotificationAttachmentFile(
            userId: widget.currentUser.id,
            source: widget.source,
            recordId: widget.recordId,
            attachmentId: item.id,
          ) as NotificationAttachmentFile;
      bytes = file.bytes;
      _bytesCache[item.id] = file.bytes;
    } catch (_) {
      bytes = null;
    }
    _inFlight.remove(item.id);
    if (mounted) {
      setState(() {});
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل "${item.fileName}"')),
        );
      }
    }
    return bytes;
  }

  Future<void> _openItem(NotificationAttachmentModel item) async {
    if (!item.canOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الملف يُنزَّل من شاشة إصدارات التطبيق'),
        ),
      );
      return;
    }
    final items = _list?.items ?? const <NotificationAttachmentModel>[];
    if (item.isImage) {
      final images = items.where((e) => e.isImage && e.canOpen).toList();
      final index = images.indexWhere((e) => e.id == item.id);
      await _openImageGallery(images, index < 0 ? 0 : index);
      return;
    }
    final bytes = await _loadBytes(item);
    if (bytes == null || !mounted) return;
    final dataUrl = 'data:${item.mimeType};base64,${base64Encode(bytes)}';
    final error = await openStoredAttachment(
      bytes: bytes,
      fileName: item.fileName,
      dataUrl: dataUrl,
    );
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الملف: $error')),
      );
    }
  }

  Future<void> _openImageGallery(
    List<NotificationAttachmentModel> images,
    int initialIndex,
  ) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _AttachmentGalleryDialog(
        images: images,
        initialIndex: initialIndex,
        loader: _loadBytes,
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes بايت';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} كيلوبايت';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
  }

  IconData _iconFor(NotificationAttachmentModel item) {
    switch (item.kind) {
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_list?.title.isNotEmpty == true
            ? _list!.title
            : widget.fallbackTitle),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoadingList) {
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
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      );
    }
    final items = _list?.items ?? const <NotificationAttachmentModel>[];
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('لا توجد مرفقات لهذا السجل')),
        ],
      );
    }

    final images = items.where((e) => e.isImage).toList();
    final files = items.where((e) => !e.isImage).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (images.isNotEmpty) ...[
          const Text(
            'الصور',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: images.map(_buildImageTile).toList(),
          ),
          const SizedBox(height: 24),
        ],
        if (files.isNotEmpty) ...[
          const Text(
            'الملفات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...files.map(_buildFileTile),
        ],
      ],
    );
  }

  Widget _buildImageTile(NotificationAttachmentModel item) {
    final bytes = _bytesCache[item.id];
    return InkWell(
      onTap: () => _openItem(item),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 104,
              height: 104,
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: _inFlight.containsKey(item.id)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined),
                    ),
            ),
          ),
          if (item.label != null)
            SizedBox(
              width: 104,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileTile(NotificationAttachmentModel item) {
    final subtitleParts = [
      if (item.label != null) item.label!,
      if (item.sizeBytes > 0) _formatSize(item.sizeBytes),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_iconFor(item), color: const Color(0xFF1B5E20)),
        title: Text(item.fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' — ')),
        trailing: _inFlight.containsKey(item.id)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(item.canOpen ? Icons.open_in_new : Icons.lock_outline),
        onTap: () => _openItem(item),
      ),
    );
  }
}

class _AttachmentGalleryDialog extends StatefulWidget {
  final List<NotificationAttachmentModel> images;
  final int initialIndex;
  final Future<Uint8List?> Function(NotificationAttachmentModel item) loader;

  const _AttachmentGalleryDialog({
    required this.images,
    required this.initialIndex,
    required this.loader,
  });

  @override
  State<_AttachmentGalleryDialog> createState() =>
      _AttachmentGalleryDialogState();
}

class _AttachmentGalleryDialogState extends State<_AttachmentGalleryDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    current.label ?? current.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  return FutureBuilder<Uint8List?>(
                    future: widget.loader(widget.images[i]),
                    builder: (_, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const Center(
                          child: Text(
                            'تعذر تحميل الصورة',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Center(child: Image.memory(bytes)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
