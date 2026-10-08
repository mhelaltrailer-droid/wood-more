import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../core/invoices_owner_constants.dart';
import '../utils/invoices_owner_new_pdf.dart';
import '../utils/pdf_share.dart';

/// شاشة إنشاء PDF من صور ثم التأكيد لإضافته كمرفق Progress.
class InvoicesOwnerNewPdfScreen extends StatefulWidget {
  const InvoicesOwnerNewPdfScreen({super.key});

  @override
  State<InvoicesOwnerNewPdfScreen> createState() =>
      _InvoicesOwnerNewPdfScreenState();
}

class _PickedImage {
  final String label;
  final Uint8List bytes;

  const _PickedImage({required this.label, required this.bytes});
}

class _InvoicesOwnerNewPdfScreenState extends State<InvoicesOwnerNewPdfScreen> {
  final _nameController = TextEditingController(text: 'Progress');
  final _picker = ImagePicker();
  final List<_PickedImage> _images = [];
  bool _busy = false;
  Uint8List? _pdfBytes;
  String? _pdfName;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;
      final added = <_PickedImage>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        added.add(_PickedImage(label: f.name, bytes: bytes));
      }
      if (added.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم اختيار صور صالحة')),
        );
        return;
      }
      setState(() {
        _images.addAll(added);
        _pdfBytes = null;
        _pdfName = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر اختيار الصور: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (bytes.isEmpty) return;
      setState(() {
        _images.add(
          _PickedImage(
            label: shot.name.isNotEmpty
                ? shot.name
                : 'camera_${_images.length + 1}.jpg',
            bytes: bytes,
          ),
        );
        _pdfBytes = null;
        _pdfName = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            invoicesOwnerNewPdfIsWeb
                ? 'الكاميرا غير متاحة أو مرفوضة في هذا المتصفح. استخدم المعرض.'
                : 'تعذر فتح الكاميرا: $e',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _buildPdf() async {
    final name = sanitizePdfFileName(_nameController.text);
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر صورة واحدة على الأقل')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await buildImagesPdf(_images.map((e) => e.bytes).toList());
      if (bytes.length > invoicesOwnerMaxAttachmentBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حجم الـ PDF ${invoicesOwnerFormatAttachmentSize(bytes.length)} '
              'أكبر من الحد ${invoicesOwnerMaxAttachmentSizeLabel()}. '
              'قلل عدد الصور أو جودتها.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _pdfName = name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء $name (${(bytes.length / 1024).toStringAsFixed(0)} KB)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء PDF: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previewPdf() async {
    final bytes = _pdfBytes;
    final name = _pdfName;
    if (bytes == null || name == null) return;
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: name,
    );
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
        SnackBar(content: Text('تعذر المشاركة/الحفظ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmAttach() async {
    final bytes = _pdfBytes;
    final name = _pdfName;
    if (bytes == null || name == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أنشئ الـ PDF أولاً')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الإضافة كمرفق'),
        content: Text(
          'إضافة الملف "$name" كمرفق في طلب Progress؟\n'
          'الصور الأصلية لن تُحفظ في قاعدة البيانات — الـ PDF فقط.',
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

  @override
  Widget build(BuildContext context) {
    final hasPdf = _pdfBytes != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New-PDF'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'اسم الملف',
              hintText: 'Progress',
              border: OutlineInputBorder(),
              helperText: 'يُحفظ تلقائياً بامتداد .pdf',
            ),
            onChanged: (_) => setState(() {
              _pdfBytes = null;
              _pdfName = null;
            }),
          ),
          const SizedBox(height: 16),
          const Text(
            'الصور',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('المعرض'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFromCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('الكاميرا'),
              ),
              if (_images.isNotEmpty)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _images.clear();
                            _pdfBytes = null;
                            _pdfName = null;
                          }),
                  child: const Text('مسح الصور'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_images.isEmpty)
            const Text(
              'لم يتم اختيار صور بعد',
              style: TextStyle(color: Colors.grey),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final imgItem = _images[i];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          imgItem.bytes,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _images.removeAt(i);
                                    _pdfBytes = null;
                                    _pdfName = null;
                                  }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy || _images.isEmpty ? null : _buildPdf,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            label: Text(_busy ? 'جاري الإنشاء...' : 'إنشاء PDF'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (hasPdf) ...[
            const SizedBox(height: 12),
            Card(
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
                      '${((_pdfBytes?.length ?? 0) / 1024).toStringAsFixed(1)} KB — ${_images.length} صورة',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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
                            invoicesOwnerNewPdfIsWeb ? 'تحميل / مشاركة' : 'مشاركة / حفظ',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _confirmAttach,
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
