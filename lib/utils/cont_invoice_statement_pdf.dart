import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/cont_invoices_constants.dart';
import '../models/cont_invoice_model.dart';

String _kindLabel(ContInvoiceLineModel line) {
  switch (line.lineKind) {
    case contLineKindHoliday:
      return 'عطلات';
    case contLineKindTransport:
      return 'انتقالات';
    case contLineKindDeduction:
      final extra = line.deductionKind.trim();
      return extra.isEmpty ? 'خصم' : 'خصم — $extra';
    case contLineKindNoteOnOther:
      return 'يوميات ملاحظات';
    default:
      return 'تنفيذ';
  }
}

String _lineTitle(ContInvoiceLineModel line) {
  final desc = line.description.trim();
  if (desc.isNotEmpty) return desc;
  return line.locationLabel.trim().isEmpty ? '—' : line.locationLabel;
}

Future<void> printContInvoiceStatementPdf(ContInvoiceModel inv) async {
  final money = NumberFormat('#,##0.00', 'en_US');
  final qtyFmt = NumberFormat('#,##0.##', 'en_US');
  final dateFmt = DateFormat('dd/MM/yyyy');
  final fontBase = await PdfGoogleFonts.tajawalRegular();
  final fontBold = await PdfGoogleFonts.tajawalBold();
  final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);
  pw.ImageProvider? logo;
  try {
    final bytes = await rootBundle.load('assets/images/logo.png');
    logo = pw.MemoryImage(bytes.buffer.asUint8List());
  } catch (_) {}

  final dateLabel = inv.statementDate == null
      ? '—'
      : dateFmt.format(inv.statementDate!);
  final statusLabel = inv.statusLabelAr.trim().isNotEmpty
      ? inv.statusLabelAr
      : contInvoiceStatusLabelAr(inv.status);
  final lines = [...inv.lines]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final total = inv.totalAmount != 0 ? inv.totalAmount : inv.computedTotal;
  final due = inv.amountDue != 0 ? inv.amountDue : inv.computedDue;
  final fileName =
      'مستخلص_${inv.contractorName}_${inv.projectName}.pdf';

  pw.Widget cell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: header ? 8 : 7.5,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4.landscape,
      textDirection: pw.TextDirection.rtl,
      margin: const pw.EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      build: (ctx) => [
        if (logo != null)
          pw.Center(
            child: pw.Container(
              height: 42,
              margin: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
          ),
        pw.Text(
          'مستخلص مقاول',
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('المقاول: ${inv.contractorName}', textAlign: pw.TextAlign.right),
        pw.Text('المشروع: ${inv.projectName}', textAlign: pw.TextAlign.right),
        pw.Text(
          'التاريخ: $dateLabel    |    نوع المقاولة: ${inv.contractType}    |    الحالة: $statusLabel',
          textAlign: pw.TextAlign.right,
        ),
        if (inv.id != null)
          pw.Text('رقم المستخلص: ${inv.id}', textAlign: pw.TextAlign.right),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.55),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.6),
            3: const pw.FlexColumnWidth(1.1),
            4: const pw.FlexColumnWidth(0.6),
            5: const pw.FlexColumnWidth(0.7),
            6: const pw.FlexColumnWidth(0.85),
            7: const pw.FlexColumnWidth(0.7),
            8: const pw.FlexColumnWidth(0.7),
            9: const pw.FlexColumnWidth(0.95),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                cell('م', header: true),
                cell('الموقع', header: true),
                cell('البيان', header: true),
                cell('النوع', header: true),
                cell('الوحدة', header: true),
                cell('الكمية', header: true),
                cell('السعر', header: true),
                cell('% سابق', header: true),
                cell('% حالي', header: true),
                cell('المستحق', header: true),
              ],
            ),
            ...lines.asMap().entries.map((e) {
              final i = e.key + 1;
              final l = e.value;
              final other = l.counterpartyContractorName.trim();
              final kind = other.isEmpty
                  ? _kindLabel(l)
                  : '${_kindLabel(l)} ($other)';
              return pw.TableRow(
                children: [
                  cell('$i'),
                  cell(
                    l.locationLabel.trim().isEmpty ? '—' : l.locationLabel,
                  ),
                  cell(_lineTitle(l)),
                  cell(kind),
                  cell(l.unit),
                  cell(qtyFmt.format(l.totalQty)),
                  cell(money.format(l.unitPrice)),
                  cell(l.isExecution ? qtyFmt.format(l.prevPercent) : '—'),
                  cell(l.isExecution ? qtyFmt.format(l.percent) : '—'),
                  cell(money.format(l.lineTotal)),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 280,
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              children: [
                pw.TableRow(
                  children: [
                    cell('الإجمالي', header: true),
                    cell(money.format(total)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cell('السابق صرفه'),
                    cell(money.format(inv.previouslyPaid)),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cell('خصومات أخرى'),
                    cell(money.format(inv.otherDeductions)),
                  ],
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('المستحق', header: true),
                    cell(money.format(due)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (inv.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            'ملاحظات: ${inv.notes.trim()}',
            textAlign: pw.TextAlign.right,
          ),
        ],
      ],
    ),
  );
  await Printing.layoutPdf(
    onLayout: (_) async => doc.save(),
    name: fileName,
  );
}
