import 'package:flutter/material.dart';

import 'excel_sheet_controller.dart';

/// Fallback used when neither `dart:io` nor `dart:html` is available.
Widget createExcelSheetView({
  required String base64Data,
  required bool editable,
  ExcelSheetController? controller,
  VoidCallback? onReady,
  void Function(String message)? onError,
}) {
  return const Center(
    child: Text('عرض الشيت غير مدعوم على هذه المنصة'),
  );
}
