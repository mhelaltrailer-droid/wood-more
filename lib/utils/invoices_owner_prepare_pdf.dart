import 'dart:typed_data';

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
  switch (quality) {
    case InvoicesOwnerPrepareQuality.engineering:
      return const _QualityProfile(dpi: 200, jpegQuality: 90, maxEdge: 3000);
    case InvoicesOwnerPrepareQuality.standard:
      return const _QualityProfile(dpi: 140, jpegQuality: 75, maxEdge: 1600);
  }
}

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

Uint8List _encodeRasterJpeg(
  PdfRaster raster, {
  required int jpegQuality,
  required int maxEdge,
}) {
  var image = img.Image.fromBytes(
    width: raster.width,
    height: raster.height,
    bytes: raster.pixels.buffer,
    bytesOffset: raster.pixels.offsetInBytes,
    rowStride: raster.width * 4,
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
    out.add(
      _encodeRasterJpeg(
        page,
        jpegQuality: profile.jpegQuality,
        maxEdge: profile.maxEdge,
      ),
    );
    onProgress?.call(
      InvoicesOwnerPrepareProgress(
        message: 'معالجة صفحات PDF ($pageIndex)...',
        done: progressBase + pageIndex,
        total: progressTotal + pageIndex,
      ),
    );
  }
  if (out.isEmpty) {
    throw StateError('تعذر قراءة صفحات ملف PDF');
  }
  return out;
}

Future<Uint8List> _buildPdfFromPageImages(
  List<Uint8List> pages, {
  required double dpi,
}) async {
  final doc = pw.Document();
  for (final jpeg in pages) {
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
    const InvoicesOwnerPrepareProgress(
      message: 'إنشاء ملف PDF النهائي...',
      done: 1,
      total: 1,
    ),
  );
  return _buildPdfFromPageImages(pageImages, dpi: profile.dpi);
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
