import 'package:flutter/foundation.dart';

/// Controller shared by every [ExcelSheetView] platform implementation.
///
/// The active platform implementation (WebView on mobile, `<iframe>` on web)
/// registers its export/ready callbacks here so the host screen can trigger an
/// export without knowing which engine is running underneath.
class ExcelSheetController {
  Future<String> Function()? exportCallback;
  ValueGetter<bool>? readyGetter;

  bool get isReady => readyGetter?.call() ?? false;

  /// Asks the embedded spreadsheet engine to serialize the current workbook
  /// back into an .xlsx file and returns it as a base64 string.
  Future<String> exportXlsx() {
    final cb = exportCallback;
    if (cb == null) {
      throw StateError('ExcelSheetView غير جاهز');
    }
    return cb();
  }
}
