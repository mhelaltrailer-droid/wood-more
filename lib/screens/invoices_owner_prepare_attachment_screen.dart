import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/invoices_owner_constants.dart';
import '../utils/invoices_owner_new_pdf.dart';
import '../utils/invoices_owner_prepare_pdf.dart';
import '../utils/pdf_share.dart';

/// شاشة تجهيز مرفق Progress: دمج PDF/صور + ضغط محافظ قبل الرفع.
class InvoicesOwnerPrepareAttachmentScreen extends StatefulWidget {
  const InvoicesOwnerPrepareAttachmentScreen({super.key});

  @override
  State<InvoicesOwnerPrepareAttachmentScreen> createState() =>
      _InvoicesOwnerPrepareAttachmentScreenState();
}

class _PrepareItem {
  final String label;
  final Uint8List bytes;
  final bool isPdf;

  const _PrepareItem({
    required this.label,
    required this.bytes,
    required this.isPdf,
  });
}

class _InvoicesOwnerPrepareAttachmentScreenState
    extends State<InvoicesOwnerPrepareAttachmentScreen> {
  final _nameController = TextEditingController(text: 'Progress_prepared');
  final List<_PrepareItem> _items = [];
  InvoicesOwnerPrepareQuality _quality =
      InvoicesOwnerPrepareQuality.engineering;
  bool _busy = false;
  String? _progressMessage;
  Uint8List? _pdfBytes;
  String? _pdfName;
  InvoicesOwnerPrepareQuality? _usedQuality;
  DateTime _lastProgressUi = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _reportProgress(String message) {
    if (!mounted) return;
    final now = DateTime.now();
    // تحديث الواجهة كل ~250ms لتجنب إعادة البناء الثقيلة كل صفحة.
    if (now.difference(_lastProgressUi).inMilliseconds < 250 &&
        _progressMessage != null) {
      _progressMessage = message;
      return;
    }
    _lastProgressUi = now;
    setState(() => _progressMessage = message);
  }

  void _clearResult() {
    _pdfBytes = null;
    _pdfName = null;
    _usedQuality = null;
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'bmp',
        ],
        withData: true,
      );
      if (result == null) return;
      final added = <_PrepareItem>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final name = f.name;
        final isPdf = invoicesOwnerPrepareLooksLikePdf(name, null);
        final isImage = invoicesOwnerPrepareLooksLikeImage(name, null);
        if (!isPdf && !isImage) continue;
        added.add(_PrepareItem(label: name, bytes: bytes, isPdf: isPdf));
      }
      if (added.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم اختيار ملفات PDF أو صور صالحة')),
        );
        return;
      }
      setState(() {
        _items.addAll(added);
        _clearResult();
      });
      final heavyPdf = added.any(
        (e) => e.isPdf && e.bytes.length >= 12 * 1024 * 1024,
      );
      if (heavyPdf && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'ملف PDF كبير: التجهيز قد يستغرق وقتاً. للملفات متعددة الصفحات يُفضّل الوضع «إداري»، ولا تغلق التبويب.'
                  : 'ملف PDF كبير: التجهيز قد يستغرق وقتاً. للملفات متعددة الصفحات يُفضّل الوضع «إداري».',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر اختيار الملفات: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _canAttachAsIs {
    if (_items.length != 1) return false;
    final only = _items.first;
    return only.isPdf && only.bytes.length <= invoicesOwnerMaxAttachmentBytes;
  }

  Future<void> _attachAsIs() async {
    if (!_canAttachAsIs) return;
    final item = _items.first;
    final name = sanitizePdfFileName(
      _nameController.text.trim().isEmpty ? item.label : _nameController.text,
    );
    Navigator.of(context).pop(
      InvoicesOwnerNewPdfResult(fileName: name, bytes: item.bytes),
    );
  }

  Future<void> _prepare() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف ملف PDF أو صورة واحدة على الأقل')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _progressMessage = 'بدء التجهيز...';
      _clearResult();
    });
    try {
      final sources = _items
          .map(
            (e) => InvoicesOwnerPrepareSource(
              label: e.label,
              bytes: e.bytes,
              isPdf: e.isPdf,
            ),
          )
          .toList();
      final result = await buildPreparedAttachmentPdfWithinLimit(
        sources: sources,
        maxBytes: invoicesOwnerMaxAttachmentBytes,
        preferred: _quality,
        onProgress: (p) => _reportProgress(p.message),
      );
      final name = sanitizePdfFileName(_nameController.text);
      if (!mounted) return;
      if (result.bytes.length > invoicesOwnerMaxAttachmentBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'الحجم النهائي ${invoicesOwnerFormatAttachmentSize(result.bytes.length)} '
              'أكبر من الحد ${invoicesOwnerMaxAttachmentSizeLabel()}. '
              'قلل عدد الصفحات أو استخدم ضغط أقوى.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _pdfBytes = result.bytes;
          _pdfName = name;
          _usedQuality = result.usedQuality;
        });
        return;
      }
      setState(() {
        _pdfBytes = result.bytes;
        _pdfName = name;
        _usedQuality = result.usedQuality;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم التجهيز: $name (${invoicesOwnerFormatAttachmentSize(result.bytes.length)})',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تجهيز المرفق: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progressMessage = null;
        });
      }
    }
  }

  Future<void> _previewPdf() async {
    final bytes = _pdfBytes;
    final name = _pdfName;
    if (bytes == null || name == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  }

  Future<void> _shareOrSavePdf() async {
    final bytes = _pdfBytes;
    final name = _pdfName;
    if (bytes == null || name == null) return;
    try {
      await sharePdfBytes(bytes, name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر المشاركة/الحفظ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmAttach() async {
    final bytes = _pdfBytes;
    final name = _pdfName;
    if (bytes == null || name == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جهّز المرفق أولاً')),
      );
      return;
    }
    if (bytes.length > invoicesOwnerMaxAttachmentBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الملف أكبر من ${invoicesOwnerMaxAttachmentSizeLabel()}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإضافة كمرفق'),
        content: Text(
          'إضافة الملف "$name" '
          '(${invoicesOwnerFormatAttachmentSize(bytes.length)}) كمرفق؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pop(
      InvoicesOwnerNewPdfResult(fileName: name, bytes: bytes),
    );
  }

  String _qualityLabel(InvoicesOwnerPrepareQuality q) {
    switch (q) {
      case InvoicesOwnerPrepareQuality.engineering:
        return 'رسومات هندسية (جودة عالية)';
      case InvoicesOwnerPrepareQuality.standard:
        return 'مستند إداري (ضغط أقوى)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPdf = _pdfBytes != null;
    final withinLimit = (_pdfBytes?.length ?? 0) <=
        invoicesOwnerMaxAttachmentBytes;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تجهيز المرفق'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسم الملف النهائي',
              border: OutlineInputBorder(),
              helperText: 'يُحفظ تلقائياً بامتداد .pdf',
            ),
            onChanged: (_) => setState(_clearResult),
          ),
          const SizedBox(height: 16),
          const Text(
            'الملفات (PDF / صور)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'يمكن دمج أكثر من ملف وترتيب الصفحات. الحد الأقصى للرفع: '
            '${invoicesOwnerMaxAttachmentSizeLabel()}.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('إضافة ملفات'),
              ),
              if (_items.isNotEmpty)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _items.clear();
                            _clearResult();
                          }),
                  child: const Text('مسح الكل'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Text(
              'لم يتم اختيار ملفات بعد',
              style: TextStyle(color: Colors.grey),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                  _clearResult();
                });
              },
              itemBuilder: (context, i) {
                final item = _items[i];
                return ListTile(
                  key: ValueKey('prep-$i-${item.label}-${item.bytes.length}'),
                  leading: Icon(
                    item.isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(invoicesOwnerFormatAttachmentSize(item.bytes.length)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.drag_handle),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _items.removeAt(i);
                                  _clearResult();
                                }),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          const Text(
            'مستوى الجودة',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<InvoicesOwnerPrepareQuality>(
            segments: const [
              ButtonSegment(
                value: InvoicesOwnerPrepareQuality.engineering,
                label: Text('هندسي'),
                icon: Icon(Icons.architecture),
              ),
              ButtonSegment(
                value: InvoicesOwnerPrepareQuality.standard,
                label: Text('إداري'),
                icon: Icon(Icons.compress),
              ),
            ],
            selected: {_quality},
            onSelectionChanged: _busy
                ? null
                : (s) => setState(() {
                      _quality = s.first;
                      _clearResult();
                    }),
          ),
          if (_canAttachAsIs) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _attachAsIs,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('إرفاق PDF كما هو (بدون إعادة ضغط)'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy || _items.isEmpty ? null : _prepare,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(_busy ? 'جاري التجهيز...' : 'تجهيز ودمج'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_progressMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _progressMessage!,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
          if (hasPdf) ...[
            const SizedBox(height: 12),
            Card(
              color: withinLimit ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'جاهز: $_pdfName',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${invoicesOwnerFormatAttachmentSize(_pdfBytes!.length)}'
                      '${_usedQuality != null ? ' — ${_qualityLabel(_usedQuality!)}' : ''}'
                      '${withinLimit ? '' : ' — يتجاوز الحد'}',
                      style: TextStyle(
                        color: withinLimit
                            ? Colors.grey.shade800
                            : Colors.red.shade800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _previewPdf,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('معاينة'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _shareOrSavePdf,
                          icon: const Icon(Icons.ios_share),
                          label: Text(
                            invoicesOwnerNewPdfIsWeb
                                ? 'تحميل / مشاركة'
                                : 'مشاركة / حفظ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: withinLimit ? _confirmAttach : null,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('تأكيد الإضافة كمرفق'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
