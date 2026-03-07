import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

Future<void> sharePdfBytes(Uint8List bytes, String filename) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: filename);
  } catch (e) {
    try {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (_) {
      rethrow;
    }
  }
}
