import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'invoices_owner_new_pdf.dart';

/// مستوى جودة تجهيز المرفق قبل الرفع.
enum InvoicesOwnerPrepareQuality {
  /// رسومات هندسية: دقة أعلى وضغط أخف.
  engineering,

  /// مستند إداري: ضغط أقوى لتقليل الحجم.
  standard,
}

class InvoicesOwnerPrepareSource {
  final String label;
  final Uint8List bytes;
  final bool isPdf;

  const InvoicesOwnerPrepareSource({
    required this.label,
    required this.bytes,
    required this.isPdf,
  });
}

class InvoicesOwnerPrepareProgress {
  final String message;
  final int done;
  final int total;

  const InvoicesOwnerPrepareProgress({
    required this.message,
    required this.done,
    required this.total,
  });
}

class _QualityProfile {
  final double dpi;
  final int jpegQuality;
  final int maxEdge;

  const _QualityProfile({
    required this.dpi,
    required this.jpegQuality,
    required this.maxEdge,
  });
}

_QualityProfile _profileFor(InvoicesOwnerPrepareQuality quality) {
  // على الويب الضغط يعمل على خيط الواجهة؛ ملف متعدد الصفحات بـ 200 DPI
  // يجمّد المتصفح (Page Unresponsive). نخفّف الملف الشخصي قليلاً هناك.
  switch (quality) {
    case InvoicesOwnerPrepareQuality.engineering:
      return kIsWeb
          ? const _QualityProfile(dpi: 160, jpegQuality: 85, maxEdge: 2200)
          : const _QualityProfile(dpi: 200, jpegQuality: 90, maxEdge: 3000);
    case InvoicesOwnerPrepareQuality.standard:
      return kIsWeb
          ? const _QualityProfile(dpi: 120, jpegQuality: 70, maxEdge: 1400)
          : const _QualityProfile(dpi: 140, jpegQuality: 75, maxEdge: 1600);
  }
}

/// يترك خيط الأحداث يتنفس حتى لا تظهر «Page Unresponsive» في المتصفح.
Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);

bool invoicesOwnerPrepareLooksLikePdf(String name, String? mime) {
  final n = name.toLowerCase();
  final m = (mime ?? '').toLowerCase();
  return m == 'application/pdf' || n.endsWith('.pdf');
}

bool invoicesOwnerPrepareLooksLikeImage(String name, String? mime) {
  final n = name.toLowerCase();
  final m = (mime ?? '').toLowerCase();
  if (m.startsWith('image/')) return true;
  return n.endsWith('.jpg') ||
      n.endsWith('.jpeg') ||
      n.endsWith('.png') ||
      n.endsWith('.gif') ||
      n.endsWith('.webp') ||
      n.endsWith('.bmp');
}

/// Top-level لـ [compute]: Map حتى تُرسل بأمان عبر isolate.
Uint8List _encodeRasterJpegJob(Map<String, Object> job) {
  final width = job['width'] as int;
  final height = job['height'] as int;
  final pixels = job['pixels'] as Uint8List;
  final jpegQuality = job['jpegQuality'] as int;
  final maxEdge = job['maxEdge'] as int;
  var image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    rowStride: width * 4,
    order: img.ChannelOrder.rgba,
  );
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxEdge) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? maxEdge : null,
      height: image.height > image.width ? maxEdge : null,
      interpolation: img.Interpolation.average,
    );
  }
  return Uint8List.fromList(
    img.encodeJpg(image, quality: jpegQuality.clamp(1, 100)),
  );
}

Future<Uint8List> _encodeRasterJpegAsync(
  PdfRaster raster, {
  required int jpegQuality,
  required int maxEdge,
}) async {
  // نسخة مستقلة من البكسلات حتى لا تُبقى إشارة للـ raster بعد الترميز.
  final job = <String, Object>{
    'width': raster.width,
    'height': raster.height,
    'pixels': Uint8List.fromList(raster.pixels),
    'jpegQuality': jpegQuality,
    'maxEdge': maxEdge,
  };
  // على الويب نقل عشرات الميغا لكل صفحة إلى Worker أغلى من الترميز المحلي
  // مع إتاحة الواجهة؛ على الموبايل/سطح المكتب نستخدم isolate.
  if (kIsWeb) {
    await _yieldToUi();
    final out = _encodeRasterJpegJob(job);
    await _yieldToUi();
    return out;
  }
  return compute(_encodeRasterJpegJob, job);
}

Uint8List _prepareImageBytes(
  Uint8List raw, {
  required int jpegQuality,
  required int maxEdge,
}) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      return prepareImageBytesForPdf(raw, maxEdge: maxEdge);
    }
    img.Image out = decoded;
    final longest = out.width > out.height ? out.width : out.height;
    if (longest > maxEdge) {
      out = img.copyResize(
        out,
        width: out.width >= out.height ? maxEdge : null,
        height: out.height > out.width ? maxEdge : null,
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(
      img.encodeJpg(out, quality: jpegQuality.clamp(1, 100)),
    );
  } catch (_) {
    return prepareImageBytesForPdf(raw, maxEdge: maxEdge);
  }
}

Future<List<Uint8List>> _rasterPdfToJpegs(
  Uint8List pdfBytes, {
  required _QualityProfile profile,
  required void Function(InvoicesOwnerPrepareProgress progress)? onProgress,
  required int progressBase,
  required int progressTotal,
}) async {
  final out = <Uint8List>[];
  var pageIndex = 0;
  await for (final page in Printing.raster(pdfBytes, dpi: profile.dpi)) {
    pageIndex += 1;
    onProgress?.call(
      InvoicesOwnerPrepareProgress(
        message: 'معالجة صفحات PDF ($pageIndex)...',
        done: progressBase + pageIndex,
        total: progressTotal + pageIndex,
      ),
    );
    out.add(
      await _encodeRasterJpegAsync(
        page,
        jpegQuality: profile.jpegQuality,
        maxEdge: profile.maxEdge,
      ),
    );
    // إتاحة دورية للواجهة بين الصفحات (مهم جداً على Chrome/Web).
    await _yieldToUi();
  }
  if (out.isEmpty) {
    throw StateError('تعذر قراءة صفحات ملف PDF');
  }
  return out;
}

Future<Uint8List> _buildPdfFromPageImages(
  List<Uint8List> pages, {
  required double dpi,
  void Function(InvoicesOwnerPrepareProgress progress)? onProgress,
}) async {
  final doc = pw.Document();
  final total = pages.length;
  for (var i = 0; i < pages.length; i++) {
    final jpeg = pages[i];
    if (i % 3 == 0) {
      onProgress?.call(
        InvoicesOwnerPrepareProgress(
          message: 'إنشاء ملف PDF النهائي (${i + 1}/$total)...',
          done: i + 1,
          total: total,
        ),
      );
      await _yieldToUi();
    }
    final decoded = img.decodeImage(jpeg);
    final image = pw.MemoryImage(jpeg);
    if (decoded != null && decoded.width > 0 && decoded.height > 0) {
      final pageW = decoded.width * PdfPageFormat.inch / dpi;
      final pageH = decoded.height * PdfPageFormat.inch / dpi;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageW, pageH),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    } else {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(12),
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
  }
  await _yieldToUi();
  return doc.save();
}

/// يدمج PDF/صور في ملف واحد مع ضغط حسب مستوى الجودة.
Future<Uint8List> buildPreparedAttachmentPdf({
  required List<InvoicesOwnerPrepareSource> sources,
  required InvoicesOwnerPrepareQuality quality,
  void Function(InvoicesOwnerPrepareProgress progress)? onProgress,
}) async {
  if (sources.isEmpty) {
    throw ArgumentError('لا توجد ملفات للتجهيز');
  }

  final info = await Printing.info();
  final needsRaster = sources.any((s) => s.isPdf);
  if (needsRaster && !info.canRaster) {
    throw StateError(
      'معالجة ملفات PDF غير متاحة على هذا الجهاز/المتصفح. '
      'جرّب من متصفح آخر أو ارفع ملفاً واحداً أصغر من الحد.',
    );
  }

  final profile = _profileFor(quality);
  final pageImages = <Uint8List>[];
  final totalSteps = sources.length;
  var step = 0;

  for (final source in sources) {
    step += 1;
    onProgress?.call(
      InvoicesOwnerPrepareProgress(
        message: 'تجهيز: ${source.label}',
        done: step - 1,
        total: totalSteps,
      ),
    );
    if (source.isPdf) {
      final pages = await _rasterPdfToJpegs(
        source.bytes,
        profile: profile,
        onProgress: onProgress,
        progressBase: step - 1,
        progressTotal: totalSteps,
      );
      pageImages.addAll(pages);
    } else {
      pageImages.add(
        _prepareImageBytes(
          source.bytes,
          jpegQuality: profile.jpegQuality,
          maxEdge: profile.maxEdge,
        ),
      );
    }
  }

  onProgress?.call(
    InvoicesOwnerPrepareProgress(
      message: 'إنشاء ملف PDF النهائي (0/${pageImages.length})...',
      done: 0,
      total: pageImages.length,
    ),
  );
  return _buildPdfFromPageImages(
    pageImages,
    dpi: profile.dpi,
    onProgress: onProgress,
  );
}

/// يحاول الجودة الهندسية أولاً ثم الإدارية إن تجاوز الحجم الحد.
Future<({Uint8List bytes, InvoicesOwnerPrepareQuality usedQuality})>
    buildPreparedAttachmentPdfWithinLimit({
  required List<InvoicesOwnerPrepareSource> sources,
  required int maxBytes,
  InvoicesOwnerPrepareQuality preferred =
      InvoicesOwnerPrepareQuality.engineering,
  void Function(InvoicesOwnerPrepareProgress progress)? onProgress,
}) async {
  final order = preferred == InvoicesOwnerPrepareQuality.engineering
      ? const [
          InvoicesOwnerPrepareQuality.engineering,
          InvoicesOwnerPrepareQuality.standard,
        ]
      : const [
          InvoicesOwnerPrepareQuality.standard,
          InvoicesOwnerPrepareQuality.engineering,
        ];

  Uint8List? last;
  var lastQuality = preferred;
  for (final q in order) {
    onProgress?.call(
      InvoicesOwnerPrepareProgress(
        message: q == InvoicesOwnerPrepareQuality.engineering
            ? 'تجهيز بجودة هندسية...'
            : 'تجهيز بضغط أقوى لتقليل الحجم...',
        done: 0,
        total: 1,
      ),
    );
    final bytes = await buildPreparedAttachmentPdf(
      sources: sources,
      quality: q,
      onProgress: onProgress,
    );
    last = bytes;
    lastQuality = q;
    if (bytes.length <= maxBytes) {
      return (bytes: bytes, usedQuality: q);
    }
  }
  return (bytes: last!, usedQuality: lastQuality);
}
