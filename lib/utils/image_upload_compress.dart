import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// نتيجة تجهيز ملف للرفع (صور فقط تُعاد ضغطها؛ باقي الأنواع كما هي).
class ImageUploadPrepResult {
  final Uint8List bytes;
  final String mime;
  final String fileName;

  const ImageUploadPrepResult({
    required this.bytes,
    required this.mime,
    required this.fileName,
  });
}

String _mimeFromFileName(String name) {
  final ext = name.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

bool _looksLikeRasterImage(String fileName) {
  final lower = fileName.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.bmp');
}

/// تصغير أطول ضلع إلى [maxSide] بكسل كحد أقصى، ثم ترميز JPEG بجودة [jpegQuality].
/// يقلّل حجم التخزين مع الحفاظ على وضوح مناسب للمعاينة والطباعة الخفيفة.
/// ملفات غير الصور أو فشل فك التشفير: إرجاع البايتات والاسم الأصليين.
ImageUploadPrepResult prepareImageForUpload({
  required Uint8List bytes,
  required String fileName,
  int maxSide = 1920,
  int jpegQuality = 85,
}) {
  if (!_looksLikeRasterImage(fileName)) {
    return ImageUploadPrepResult(
      bytes: bytes,
      mime: _mimeFromFileName(fileName),
      fileName: fileName,
    );
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return ImageUploadPrepResult(
      bytes: bytes,
      mime: _mimeFromFileName(fileName),
      fileName: fileName,
    );
  }

  var w = decoded.width;
  var h = decoded.height;
  img.Image work = decoded;
  if (w > maxSide || h > maxSide) {
    if (w >= h) {
      final nh = (h * maxSide / w).round().clamp(1, 100000);
      work = img.copyResize(
        decoded,
        width: maxSide,
        height: nh,
        interpolation: img.Interpolation.linear,
      );
    } else {
      final nw = (w * maxSide / h).round().clamp(1, 100000);
      work = img.copyResize(
        decoded,
        width: nw,
        height: maxSide,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  final outBytes = Uint8List.fromList(
    img.encodeJpg(work, quality: jpegQuality.clamp(1, 100)),
  );
  final base = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  return ImageUploadPrepResult(
    bytes: outBytes,
    mime: 'image/jpeg',
    fileName: '$base.jpg',
  );
}
