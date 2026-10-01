import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// نتيجة إنشاء PDF من صور — للربط كمرفق بعد تأكيد المستخدم.
class InvoicesOwnerNewPdfResult {
  final String fileName;
  final Uint8List bytes;

  const InvoicesOwnerNewPdfResult({
    required this.fileName,
    required this.bytes,
  });

  int get sizeBytes => bytes.length;
}

String sanitizePdfFileName(String raw) {
  var name = raw.trim();
  if (name.isEmpty) name = 'Progress';
  name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (!name.toLowerCase().endsWith('.pdf')) {
    name = '$name.pdf';
  }
  return name;
}

/// يضغط الصورة عند الحاجة لتقليل حجم الـ PDF النهائي.
Uint8List prepareImageBytesForPdf(Uint8List raw, {int maxEdge = 1600}) {
  try {
    final decoded = img.decodeImage(raw);
    if (decoded == null) return raw;
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
    return Uint8List.fromList(img.encodeJpg(out, quality: 82));
  } catch (_) {
    return raw;
  }
}

Future<Uint8List> buildImagesPdf(List<Uint8List> imageBytesList) async {
  final doc = pw.Document();
  for (final raw in imageBytesList) {
    final prepared = prepareImageBytesForPdf(raw);
    final image = pw.MemoryImage(prepared);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ),
    );
  }
  return doc.save();
}

/// على الويب الكاميرا عبر image_picker مدعومة جزئياً؛ المعرض يعمل عبر file_picker.
bool get invoicesOwnerNewPdfCameraSupported => true;

bool get invoicesOwnerNewPdfIsWeb => kIsWeb;
