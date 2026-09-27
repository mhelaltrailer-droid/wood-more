import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/invoices_owner_constants.dart';
import 'pdf_share.dart';

/// ألوان هوية Wood & More (متناسقة مع شعار/التطبيق).
const PdfColor _brandGreen = PdfColor.fromInt(0xFF1B5E20);
const PdfColor _brandGreenLight = PdfColor.fromInt(0xFFE8F5E9);
const PdfColor _brandGreenMid = PdfColor.fromInt(0xFF2E7D32);

/// بناء ومشاركة PDF قائمة مراجعة OM بعد اعتماد المستخلص.
Future<void> shareInvoicesOwnerOmChecklistPdf({
  required String projectName,
  required Map<String, bool> checklist,
  int? invoiceId,
}) async {
  final fontBase = await PdfGoogleFonts.tajawalRegular();
  final fontBold = await PdfGoogleFonts.tajawalBold();
  // Amiri يدعم Bold Italic للعربية (Tajawal لا يوفر italic).
  final fontBoldItalic = await PdfGoogleFonts.amiriBoldItalic();
  final theme = pw.ThemeData.withFont(
    base: fontBase,
    bold: fontBold,
    italic: fontBoldItalic,
    boldItalic: fontBoldItalic,
  );

  pw.ImageProvider? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {}

  final projectLabel =
      projectName.trim().isEmpty ? '—' : projectName.trim();

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
                  height: 52,
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              ),
            pw.Center(
              child: pw.Text(
                '(Invoices Checklist)',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandGreen,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                projectLabel,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandGreenMid,
                ),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(width: 0.9, color: _brandGreen),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.0),
                1: const pw.FlexColumnWidth(2.0),
                2: const pw.FlexColumnWidth(3.2),
                3: const pw.FlexColumnWidth(0.7),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _brandGreenLight),
                  children: [
                    _headerCell('الحالة'),
                    _headerCell('المسئول'),
                    _headerCell('البند'),
                    _headerCell('م'),
                  ],
                ),
                ...List.generate(invoicesOwnerOmChecklistItems.length, (i) {
                  final row = invoicesOwnerOmChecklistItems[i];
                  final checked = checklist[row.key] == true;
                  final zebra = i.isOdd ? _brandGreenLight : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: zebra),
                    children: [
                      _statusCell(checked),
                      _bodyCell(row.responsible),
                      _bodyCell(row.label),
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
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 9),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        fontStyle: pw.FontStyle.italic,
        color: _brandGreen,
      ),
    ),
  );
}

pw.Widget _bodyCell(String text, {bool center = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    child: pw.Text(
      text,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        fontStyle: pw.FontStyle.italic,
        color: PdfColors.black,
      ),
    ),
  );
}

/// مربع اختيار بهوية خضراء — علامة ✓ مرسومة (لتجنب تشويه حرف الخط).
pw.Widget _statusCell(bool checked) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7),
    child: pw.Center(
      child: pw.Container(
        width: 16,
        height: 16,
        decoration: pw.BoxDecoration(
          color: checked ? _brandGreen : PdfColors.white,
          border: pw.Border.all(width: 1.6, color: _brandGreen),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: checked
            ? pw.CustomPaint(
                size: const PdfPoint(16, 16),
                painter: (canvas, s) {
                  // إحداثيات PDF: Y تصاعدي من الأسفل — مسار ✓ الصحيح
                  canvas
                    ..setStrokeColor(PdfColors.white)
                    ..setLineWidth(2.0)
                    ..moveTo(s.x * 0.20, s.y * 0.48)
                    ..lineTo(s.x * 0.42, s.y * 0.28)
                    ..lineTo(s.x * 0.80, s.y * 0.72)
                    ..strokePath();
                },
              )
            : null,
      ),
    ),
  );
}
