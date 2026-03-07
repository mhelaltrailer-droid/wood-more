import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../models/attendance_record_model.dart';
import '../services/storage_service.dart';

/// تقرير حضور وانصراف: مدة → كل الحركات
class AttendanceSubReportScreen extends StatefulWidget {
  final UserModel admin;

  const AttendanceSubReportScreen({super.key, required this.admin});

  @override
  State<AttendanceSubReportScreen> createState() => _AttendanceSubReportScreenState();
}

class _AttendanceSubReportScreenState extends State<AttendanceSubReportScreen> {
  final _db = getStorage();
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<AttendanceRecordModel> _records = [];
  bool _loading = false;

  Future<void> _run() async {
    setState(() => _loading = true);
    final list = await _db.getAllAttendanceRecords();
    final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
    final toEnd = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);
    final filtered = list.where((r) {
      return !r.dateTime.isBefore(from) && !r.dateTime.isAfter(toEnd);
    }).toList();
    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    if (!mounted) return;
    setState(() {
      _records = filtered;
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    if (_records.isEmpty) return;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final timeFormat = DateFormat('hh:mm a', 'ar');
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
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) pw.Center(child: pw.Container(height: 48, margin: const pw.EdgeInsets.only(bottom: 8), child: pw.Image(logoImage!, fit: pw.BoxFit.contain))),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: PdfColors.green800)),
                child: pw.Center(child: pw.Text('تقرير حضور وانصراف | Attendance Report', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
              ),
              pw.SizedBox(height: 6),
              pw.Text('من ${dateFormat.format(_dateFrom)} إلى ${dateFormat.format(_dateTo)}', textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {0: const pw.FlexColumnWidth(1.2), 1: const pw.FlexColumnWidth(0.8), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1), 4: const pw.FlexColumnWidth(1.2), 5: const pw.FlexColumnWidth(1.5)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _cell('المهندس', true),
                      _cell('نوع التسجيل', true),
                      _cell('التاريخ', true),
                      _cell('الوقت', true),
                      _cell('المشروع', true),
                      _cell('الموقع / ملاحظات', true),
                    ],
                  ),
                  ..._records.map((r) => pw.TableRow(
                        children: [
                          _cell(r.userName, false),
                          _cell(r.isCheckIn ? 'حضور' : 'انصراف', false),
                          _cell(dateFormat.format(r.dateTime), false),
                          _cell(timeFormat.format(r.dateTime), false),
                          _cell(r.projectName ?? '—', false),
                          _cell('${r.location}${r.notes != null && r.notes!.isNotEmpty ? "\n${r.notes}" : ""}', false),
                        ],
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'تقرير_حضور_انصراف_${dateFormat.format(_dateFrom)}.pdf');
  }

  pw.Widget _cell(String text, bool isHeader) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: pw.Text(text, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 8, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, color: isHeader ? PdfColors.green900 : PdfColors.black)),
      );

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final timeFormat = DateFormat('hh:mm a', 'ar');
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير حضور وانصراف'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: const Text('من تاريخ'), subtitle: Text(dateFormat.format(_dateFrom)), trailing: const Icon(Icons.calendar_today), onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _dateFrom, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _dateFrom = d);
          }),
          ListTile(title: const Text('إلى تاريخ'), subtitle: Text(dateFormat.format(_dateTo)), trailing: const Icon(Icons.calendar_today), onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _dateTo, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _dateTo = d);
          }),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _loading ? null : _run, icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search), label: const Text('عرض التقرير'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20))),
          if (_records.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('النتائج (${_records.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._records.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${r.userName} • ${r.isCheckIn ? "حضور" : "انصراف"}'),
                    subtitle: Text('${dateFormat.format(r.dateTime)} ${timeFormat.format(r.dateTime)} • ${r.projectName ?? "—"}'),
                    trailing: Text(r.location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                )),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('تصدير PDF'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20))),
          ],
        ],
      ),
    );
  }
}
