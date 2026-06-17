import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/reports_sys_model.dart';
import '../utils/reports_sys_attachment_save.dart';

typedef ReportsSysAttachmentLoader = Future<Map<String, String>> Function(
  int attachmentId,
);

const double _kImageThumbSize = 88;

Uint8List? decodeReportsSysAttachmentBytes(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  var s = raw.trim();
  final comma = s.indexOf(',');
  if (s.startsWith('data:') && comma > 0) {
    s = s.substring(comma + 1);
  }
  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}

bool reportsSysAttachmentIsImage(ReportsSysAttachmentModel a) {
  if (a.mimeType.startsWith('image/')) return true;
  final n = a.fileName.toLowerCase();
  return n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.png') ||
      n.endsWith('.gif') ||
      n.endsWith('.webp');
}

class ReportsSysAttachmentsPanel extends StatefulWidget {
  final int? reportId;
  final List<ReportsSysAttachmentModel> attachments;
  final ReportsSysAttachmentLoader? loadAttachment;
  final void Function(int index)? onRemove;
  final bool readOnly;

  const ReportsSysAttachmentsPanel({
    super.key,
    this.reportId,
    required this.attachments,
    this.loadAttachment,
    this.onRemove,
    this.readOnly = true,
  });

  @override
  State<ReportsSysAttachmentsPanel> createState() =>
      _ReportsSysAttachmentsPanelState();
}

class _ReportsSysAttachmentsPanelState extends State<ReportsSysAttachmentsPanel> {
  final Map<int, Uint8List?> _bytesCache = {};
  int? _downloadingId;

  bool _isImage(ReportsSysAttachmentModel a) => reportsSysAttachmentIsImage(a);

  IconData _docIcon(ReportsSysAttachmentModel a) {
    final n = a.fileName.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (n.endsWith('.doc') || n.endsWith('.docx')) return Icons.description;
    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  Future<Uint8List?> _loadBytes(ReportsSysAttachmentModel att) async {
    if (_bytesCache.containsKey(att.id)) return _bytesCache[att.id];
    if (att.dataBase64 != null && att.dataBase64!.isNotEmpty) {
      final bytes = decodeReportsSysAttachmentBytes(att.dataBase64);
      _bytesCache[att.id] = bytes;
      return bytes;
    }
    if (widget.loadAttachment == null) return null;
    try {
      final data = await widget.loadAttachment!(att.id);
      final bytes = decodeReportsSysAttachmentBytes(data['data_base64']);
      _bytesCache[att.id] = bytes;
      return bytes;
    } catch (_) {
      _bytesCache[att.id] = null;
      return null;
    }
  }

  Future<void> _downloadAttachment(ReportsSysAttachmentModel att) async {
    if (_downloadingId == att.id) return;
    setState(() => _downloadingId = att.id);
    try {
      final bytes = await _loadBytes(att);
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل المرفق')),
        );
        return;
      }
      final err = await saveReportsSysAttachment(
        bytes: bytes,
        fileName: att.fileName,
        mimeType: att.mimeType,
      );
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التحميل: $err'), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحميل ${att.fileName}')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _openImageGallery(
    List<ReportsSysAttachmentModel> images,
    int initialIndex,
  ) async {
    if (images.isEmpty) return;
    final idx = initialIndex.clamp(0, images.length - 1);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _ReportsSysImageGalleryDialog(
        images: images,
        initialIndex: idx,
        loadBytes: _loadBytes,
        onDownload: _downloadAttachment,
      ),
    );
  }

  Future<void> _openAttachment(ReportsSysAttachmentModel att) async {
    if (_isImage(att)) {
      final images = widget.attachments.where(_isImage).toList();
      final index = images.indexWhere((a) => a.id == att.id);
      await _openImageGallery(images, index < 0 ? 0 : index);
      return;
    }
    await _downloadAttachment(att);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();

    final images = widget.attachments.where(_isImage).toList();
    final docs = widget.attachments.where((a) => !_isImage(a)).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_open_outlined,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المرفقات',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        '${widget.attachments.length} ملف مرفق',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'صور',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < images.length; i++)
                    _ImageThumb(
                      attachment: images[i],
                      loadBytes: _loadBytes,
                      onTap: () => _openImageGallery(images, i),
                      onRemove: widget.onRemove != null
                          ? () {
                              final globalIndex =
                                  widget.attachments.indexOf(images[i]);
                              widget.onRemove!(globalIndex);
                            }
                          : null,
                    ),
                ],
              ),
            ],
            if (docs.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'مستندات',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              ...docs.map((att) {
                final globalIndex = widget.attachments.indexOf(att);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: const Color(0xFFF8FAF8),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openAttachment(att),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF1B5E20).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Icon(
                                _docIcon(att),
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    att.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatSize(att.sizeBytes),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'تحميل',
                              onPressed: _downloadingId == att.id
                                  ? null
                                  : () => _downloadAttachment(att),
                              icon: _downloadingId == att.id
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(
                                      Icons.download_outlined,
                                      color: const Color(0xFF1B5E20),
                                      size: 22,
                                    ),
                            ),
                            if (widget.onRemove != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: () => widget.onRemove!(globalIndex),
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade400,
                                  size: 20,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final ReportsSysAttachmentModel attachment;
  final Future<Uint8List?> Function(ReportsSysAttachmentModel) loadBytes;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _ImageThumb({
    required this.attachment,
    required this.loadBytes,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _kImageThumbSize,
          height: _kImageThumbSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: loadBytes(attachment),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final bytes = snap.data;
                  if (bytes == null || bytes.isEmpty) {
                    return ColoredBox(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey.shade500,
                        size: 32,
                      ),
                    );
                  }
                  return Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: _kImageThumbSize,
                    height: _kImageThumbSize,
                    cacheWidth: (_kImageThumbSize * 2).round(),
                    cacheHeight: (_kImageThumbSize * 2).round(),
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey.shade500,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.photo_outlined,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsSysImageGalleryDialog extends StatefulWidget {
  final List<ReportsSysAttachmentModel> images;
  final int initialIndex;
  final Future<Uint8List?> Function(ReportsSysAttachmentModel) loadBytes;
  final Future<void> Function(ReportsSysAttachmentModel) onDownload;

  const _ReportsSysImageGalleryDialog({
    required this.images,
    required this.initialIndex,
    required this.loadBytes,
    required this.onDownload,
  });

  @override
  State<_ReportsSysImageGalleryDialog> createState() =>
      _ReportsSysImageGalleryDialogState();
}

class _ReportsSysImageGalleryDialogState
    extends State<_ReportsSysImageGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.images[_currentIndex];
    final multi = widget.images.length > 1;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          att.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (multi)
                          Text(
                            '${_currentIndex + 1} / ${widget.images.length}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحميل',
                    onPressed: () => widget.onDownload(att),
                    icon: const Icon(Icons.download_outlined, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    itemBuilder: (context, index) {
                      final image = widget.images[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: FutureBuilder<Uint8List?>(
                          future: widget.loadBytes(image),
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white54,
                                ),
                              );
                            }
                            final bytes = snap.data;
                            if (bytes == null || bytes.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'تعذر عرض الصورة',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4,
                              child: Center(
                                child: Image.memory(
                                  bytes,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 48,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  if (multi) ...[
                    Positioned(
                      right: 4,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        onPressed: _currentIndex > 0
                            ? () => _goTo(_currentIndex - 1)
                            : null,
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        onPressed: _currentIndex < widget.images.length - 1
                            ? () => _goTo(_currentIndex + 1)
                            : null,
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (multi)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: widget.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = widget.images[index];
                    final selected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () => _goTo(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF66BB6A)
                                : Colors.white24,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: FutureBuilder<Uint8List?>(
                          future: widget.loadBytes(image),
                          builder: (context, snap) {
                            final bytes = snap.data;
                            if (bytes == null || bytes.isEmpty) {
                              return ColoredBox(
                                color: Colors.grey.shade800,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.white54,
                                  size: 24,
                                ),
                              );
                            }
                            return Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              width: 56,
                              height: 56,
                              cacheWidth: 112,
                              cacheHeight: 112,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                color: Colors.grey.shade800,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white54,
                                  size: 24,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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

/// مرفقات محلية قبل الحفظ (نموذج الإنشاء).
class ReportsSysLocalAttachmentsPanel extends StatelessWidget {
  final List<({
    String fileName,
    String mimeType,
    String dataBase64,
    int sizeBytes,
  })> items;
  final void Function(int index) onRemove;

  const ReportsSysLocalAttachmentsPanel({
    super.key,
    required this.items,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final models = [
      for (var i = 0; i < items.length; i++)
        ReportsSysAttachmentModel(
          id: i,
          fileName: items[i].fileName,
          mimeType: items[i].mimeType,
          sizeBytes: items[i].sizeBytes,
          createdAt: DateTime.now(),
          dataBase64: items[i].dataBase64,
        ),
    ];
    return ReportsSysAttachmentsPanel(
      attachments: models,
      readOnly: false,
      onRemove: onRemove,
    );
  }
}
