import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/invoices_owner_constants.dart';
import 'pdf_share.dart';

/// بناء ومشاركة PDF قائمة مراجعة OM بعد اعتماد المستخلص.
Future<void> shareInvoicesOwnerOmChecklistPdf({
  required String projectName,
  required Map<String, bool> checklist,
  int? invoiceId,
}) async {
  final fontBase = await PdfGoogleFonts.tajawalRegular();
  final fontBold = await PdfGoogleFonts.tajawalBold();
  final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);

  pw.ImageProvider? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {}

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      textDirection: pw.TextDirection.rtl,
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logoImage != null)
              pw.Center(
                child: pw.Container(
                  height: 48,
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              ),
            pw.Text(
              'المشروع: ${projectName.trim().isEmpty ? '—' : projectName.trim()}',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(width: 0.8, color: PdfColors.black),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.1),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(3.2),
                3: const pw.FlexColumnWidth(0.7),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _headerCell('الحالة'),
                    _headerCell('المسئول'),
                    _headerCell('البند'),
                    _headerCell('م'),
                  ],
                ),
                ...List.generate(invoicesOwnerOmChecklistPdfRows.length, (i) {
                  final row = invoicesOwnerOmChecklistPdfRows[i];
                  final checked = checklist[row.key] == true;
                  return pw.TableRow(
                    children: [
                      _statusCell(checked),
                      _bodyCell(row.responsible),
                      _bodyCell(row.itemLabel),
                      _bodyCell('${i + 1}', center: true),
                    ],
                  );
                }),
              ],
            ),
          ],
        );
      },
    ),
  );

  final bytes = await doc.save();
  final safeProject = projectName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(' ', '_');
  final name = invoiceId != null
      ? 'invoices_owner_${invoiceId}_${safeProject.isEmpty ? 'project' : safeProject}.pdf'
      : 'invoices_owner_${safeProject.isEmpty ? 'project' : safeProject}.pdf';
  await sharePdfBytes(Uint8List.fromList(bytes), name);
}

pw.Widget _headerCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _bodyCell(String text, {bool center = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: pw.Text(
      text,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
      style: const pw.TextStyle(fontSize: 10),
    ),
  );
}

pw.Widget _statusCell(bool checked) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8),
    child: pw.Center(
      child: pw.Container(
        width: 14,
        height: 14,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1.2, color: PdfColors.black),
        ),
        child: checked
            ? pw.Center(
                child: pw.Text(
                  '✓',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    ),
  );
}
