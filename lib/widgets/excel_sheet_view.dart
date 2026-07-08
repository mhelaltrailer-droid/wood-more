import 'package:flutter/material.dart';

import 'excel_sheet_controller.dart';
import 'excel_sheet_view_stub.dart'
    if (dart.library.io) 'excel_sheet_view_mobile.dart'
    if (dart.library.html) 'excel_sheet_view_web.dart';

export 'excel_sheet_controller.dart';

/// Renders an .xlsx file (given as base64) using a real spreadsheet engine
/// (Luckysheet), preserving the original colors and formatting exactly like
/// the desktop Excel app.
///
/// On mobile the sheet is hosted inside a native WebView; on Flutter Web it is
/// hosted inside an `<iframe>`. Both share the same `assets/spreadsheet/`
/// engine, so behavior (view / edit / export) is identical everywhere.
///
/// When [editable] is true the user can edit cells and the host can export the
/// edited workbook back to .xlsx via [controller].
class ExcelSheetView extends StatelessWidget {
  final String base64Data;
  final bool editable;
  final ExcelSheetController? controller;
  final VoidCallback? onReady;
  final void Function(String message)? onError;

  const ExcelSheetView({
    super.key,
    required this.base64Data,
    this.editable = false,
    this.controller,
    this.onReady,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return createExcelSheetView(
      base64Data: base64Data,
      editable: editable,
      controller: controller,
      onReady: onReady,
      onError: onError,
    );
  }
}
