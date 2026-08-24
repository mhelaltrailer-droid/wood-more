import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/location_material_model.dart';

/// هل الوحدة مترية (عمود الكمية بالمتر)؟
bool isMeterMaterialUnit(String unit) {
  final u = unit.trim().toLowerCase();
  if (u.isEmpty) return false;
  if (u.contains('متر') || u.contains('meter') || u.contains('metre')) {
    return true;
  }
  return u == 'm' ||
      u == 'm2' ||
      u == 'm²' ||
      u == 'm3' ||
      u == 'm³' ||
      u == 'sqm' ||
      u == 'sq.m';
}

/// بيانات صف في جدول أذن الصرف/التسليم
class DisbursementNoteLine {
  final String materialName;
  final String quantity;
  final String unit;
  final bool isMeter;

  DisbursementNoteLine({
    required this.materialName,
    required this.quantity,
    required this.unit,
  }) : isMeter = isMeterMaterialUnit(unit);

  factory DisbursementNoteLine.fromMaterial(LocationMaterialModel m) {
    return DisbursementNoteLine(
      materialName: m.materialName,
      quantity: m.quantity,
      unit: m.unit,
    );
  }

  String get qtyDisplay {
    final q = quantity.trim();
    final u = unit.trim();
    if (q.isEmpty) return u;
    if (u.isEmpty) return q;
    // الرقم ثم الوحدة — اتجاه RTL في الخلية يضمن تشكيل العربية بشكل صحيح
    return '$q $u';
  }
}

/// يبني PDF نموذج اذن صرف/تسليم بنفس تخطيط المرفق.
Future<Uint8List> buildDisbursementNotePdf({
  required String requestNumber,
  required String villaNumber,
  required String projectName,
  required String contractorName,
  required DateTime date,
  required List<DisbursementNoteLine> lines,
}) async {
  final fontBase = await PdfGoogleFonts.tajawalRegular();
  final fontBold = await PdfGoogleFonts.tajawalBold();
  final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);

  pw.ImageProvider? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {}

  final dateStr = DateFormat('yyyy/MM/dd').format(date);
  final contractor = contractorName.trim().isEmpty ? '—' : contractorName.trim();
  final hasMeter = lines.any((e) => e.isMeter);
  final hasPiece = lines.any((e) => !e.isMeter);
  // عند مزج الوحدات نعرض العمودين؛ عند توحيد النوع نخفي الآخر.
  final onlyMeter = hasMeter && !hasPiece;
  final onlyPiece = hasPiece && !hasMeter;

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) {
        return pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.2),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _header(logoImage, contractor),
                pw.SizedBox(height: 14),
                _metaRow(
                  requestNumber: requestNumber,
                  villaNumber: villaNumber,
                  dateStr: dateStr,
                  projectName: projectName,
                ),
                pw.SizedBox(height: 14),
                _materialsTable(
                  lines: lines,
                  onlyMeter: onlyMeter,
                  onlyPiece: onlyPiece,
                ),
                pw.Spacer(),
                _signatures(contractor),
              ],
            ),
          ),
        );
      },
    ),
  );
  return doc.save();
}

pw.Widget _header(pw.ImageProvider? logo, String contractor) {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 88,
          height: 72,
          alignment: pw.Alignment.center,
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(width: 0.8)),
          ),
          child: logo != null
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                )
              : pw.Text(
                  'WOOD & MORE',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
        ),
        pw.Expanded(
          child: pw.Center(
            child: pw.Text(
              'نموذج اذن صرف/تسليم',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.Container(
          width: 120,
          height: 72,
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(right: pw.BorderSide(width: 0.8)),
          ),
          child: pw.Text(
            contractor,
            textAlign: pw.TextAlign.center,
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _metaRow({
  required String requestNumber,
  required String villaNumber,
  required String dateStr,
  required String projectName,
}) {
  pw.Widget labelValue(String label, String value, {bool ltr = false}) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(width: 4),
        pw.Text(
          value,
          textDirection: ltr ? pw.TextDirection.ltr : pw.TextDirection.rtl,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          labelValue('رقم الطلب :', requestNumber, ltr: true),
          labelValue('التاريخ :', dateStr, ltr: true),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          labelValue('رقم الفيلا :', villaNumber, ltr: true),
          pw.Expanded(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('مشروع :', style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(width: 6),
                pw.Flexible(
                  child: pw.Text(
                    projectName,
                    textDirection: pw.TextDirection.ltr,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _materialsTable({
  required List<DisbursementNoteLine> lines,
  required bool onlyMeter,
  required bool onlyPiece,
}) {
  final headerColor = PdfColor.fromInt(0xFFC8E6C9);

  pw.Widget cell(
    String text, {
    bool header = false,
    bool ltr = false,
    pw.Alignment align = pw.Alignment.center,
  }) {
    return pw.Container(
      alignment: align,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: ltr ? pw.TextDirection.ltr : pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ترتيب الأعمدة من اليمين لليسار في RTL: م، اسم، شريحة، متر، ملاحظات
  final widths = <int, pw.TableColumnWidth>{};
  var col = 0;
  // ملاحظات (يسار)
  widths[col++] = const pw.FlexColumnWidth(1.2);
  if (!onlyPiece) {
    widths[col++] = const pw.FlexColumnWidth(1.4);
  }
  if (!onlyMeter) {
    widths[col++] = const pw.FlexColumnWidth(1.4);
  }
  widths[col++] = const pw.FlexColumnWidth(3.2);
  widths[col++] = const pw.FlexColumnWidth(0.5);

  List<pw.Widget> headerCells() {
    final cells = <pw.Widget>[
      cell('ملاحظات', header: true),
    ];
    if (!onlyPiece) {
      cells.add(cell('الكمية بالمتر', header: true));
    }
    if (!onlyMeter) {
      cells.add(cell('الكمية بالشريحة', header: true));
    }
    cells.add(cell('اسم الصنف', header: true));
    cells.add(cell('م', header: true));
    return cells;
  }

  List<pw.Widget> rowCells(int index, DisbursementNoteLine line) {
    final cells = <pw.Widget>[
      cell(''), // ملاحظات فارغة
    ];
    if (!onlyPiece) {
      cells.add(
        cell(line.isMeter ? line.qtyDisplay : ''),
      );
    }
    if (!onlyMeter) {
      cells.add(
        cell(!line.isMeter ? line.qtyDisplay : ''),
      );
    }
    cells.add(
      cell(
        line.materialName,
        ltr: true,
        align: pw.Alignment.centerLeft,
      ),
    );
    cells.add(cell('${index + 1}', ltr: true));
    return cells;
  }

  return pw.Table(
    border: pw.TableBorder.all(width: 0.6),
    columnWidths: widths,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: headerColor),
        children: headerCells(),
      ),
      ...List.generate(lines.length, (i) {
        return pw.TableRow(children: rowCells(i, lines[i]));
      }),
      // صفوف فارغة إن قلّت البنود ليبدو النموذج أقرب للمرفق
      if (lines.length < 8)
        ...List.generate(8 - lines.length, (_) {
          final empty = <pw.Widget>[cell('')];
          if (!onlyPiece) empty.add(cell(''));
          if (!onlyMeter) empty.add(cell(''));
          empty.add(cell(''));
          empty.add(cell(''));
          return pw.TableRow(children: empty);
        }),
    ],
  );
}

pw.Widget _signatures(String contractor) {
  pw.Widget block(String title) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(
            title,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 18),
          pw.Text('الاسم', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 16),
          pw.Text('التوقيع', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        block('مهندس / مشرف وود اند مور'),
        block('المقاول'),
        block('مهندس / $contractor'),
      ],
    ),
  );
}
