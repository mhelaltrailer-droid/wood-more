import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/contractor_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';

/// تقرير المقاول: اسم المقاول + مدة → المشاريع وعدد العمال في كل تقرير
/// قائمة المقاولين من التخزين (نفس مصدر خطة عمل الغد / التقرير المفصل)
class ContractorReportScreen extends StatefulWidget {
  final UserModel admin;

  const ContractorReportScreen({super.key, required this.admin});

  @override
  State<ContractorReportScreen> createState() => _ContractorReportScreenState();
}

class _ContractorReportScreenState extends State<ContractorReportScreen> {
  static const _allContractors = 'الجميع';

  final _db = getStorage();
  List<String> _contractorNames = [];
  String _selectedContractor = _allContractors;
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<_ContractorReportRow> _rows = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadContractors();
  }

  Future<void> _loadContractors() async {
    List<ContractorModel> contractors = [];
    try {
      contractors = await _db.getContractors();
    } catch (e) {
      if (!mounted) return;
      setState(() => _contractorNames = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل المقاولين: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _contractorNames = contractors
          .where((c) {
            final n = c.name.trim().toLowerCase();
            return n != 'لايوجد مقاول' && n != 'ذاتي';
          })
          .map((c) => c.name.trim())
          .where((n) => n.isNotEmpty)
          .toList();
    });
  }

  Future<void> _run() async {
    if (_db is! ApiStorageService) {
      if (!mounted) return;
      setState(() => _rows = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا التقرير متاح في وضع API فقط'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final list = await (_db as ApiStorageService).getContractorReportFromExecutedPlans(
      contractorName: _selectedContractor,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    final rows = list.map(_ContractorReportRow.fromMap).toList();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    if (_rows.isEmpty) return;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final rangeLabel = DateFormat('yyyy-MM-dd', 'ar');
    final fontBase = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => [
          if (logoImage != null)
            pw.Center(
              child: pw.Container(
                height: 52,
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.green800, width: 0.8),
            ),
            child: pw.Center(
              child: pw.Text(
                'تقرير المقاول | Contractor Report',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'المقاول: $_selectedContractor',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'من ${dateFormat.format(_dateFrom)} إلى ${dateFormat.format(_dateTo)}',
            textDirection: pw.TextDirection.rtl,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(width: 0.45, color: PdfColors.grey600),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.4),
              5: const pw.FlexColumnWidth(0.7),
              6: const pw.FlexColumnWidth(0.7),
              7: const pw.FlexColumnWidth(0.7),
            },
            children: [
              pw.TableRow(
                repeat: true,
                verticalAlignment: pw.TableCellVerticalAlignment.top,
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('التاريخ', true),
                  _cell('المقاول', true),
                  _cell('المهندس', true),
                  _cell('المشروع', true),
                  _cell('مكان العمل', true),
                  _cell('صنايعي', true),
                  _cell('مساعد', true),
                  _cell('عمال', true),
                ],
              ),
              ..._rows.map(
                (r) => pw.TableRow(
                  verticalAlignment: pw.TableCellVerticalAlignment.top,
                  children: [
                    _cell(
                      r.planDate != null ? dateFormat.format(r.planDate!) : '—',
                      false,
                    ),
                    _cell(r.contractorName, false),
                    _cell(r.engineerName, false),
                    _cell(r.projectName, false),
                    _cell(r.workPlace, false),
                    _cell('${r.craftsmanCount}', false),
                    _cell('${r.assistantCount}', false),
                    _cell('${r.workersCount}', false),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'تقرير_المقاول_${_selectedContractor}_${rangeLabel.format(_dateFrom)}_${rangeLabel.format(_dateTo)}.pdf',
    );
  }

  pw.Widget _cell(String text, bool isHeader) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text(
            text.trim().isEmpty ? '—' : text,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
              fontSize: isHeader ? 8.5 : 8,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? PdfColors.green900 : PdfColors.black,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير المقاول'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedContractor,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المقاول', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem<String>(value: _allContractors, child: Text('الجميع')),
              ..._contractorNames.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => setState(() => _selectedContractor = v ?? _allContractors),
          ),
          const SizedBox(height: 12),
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
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('النتائج (${_rows.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._rows.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${r.contractorName} • ${r.engineerName}'),
                    subtitle: Text(
                      '${r.planDate != null ? dateFormat.format(r.planDate!) : '—'}\n'
                      '${r.projectName} • ${r.workPlace}\n'
                      'صنايعي: ${r.craftsmanCount} • مساعد: ${r.assistantCount} • عمال: ${r.workersCount}',
                    ),
                    isThreeLine: true,
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

class _ContractorReportRow {
  final String contractorName;
  final String engineerName;
  final String projectName;
  final String workPlace;
  final DateTime? planDate;
  final int craftsmanCount;
  final int assistantCount;
  final int workersCount;

  const _ContractorReportRow({
    required this.contractorName,
    required this.engineerName,
    required this.projectName,
    required this.workPlace,
    this.planDate,
    required this.craftsmanCount,
    required this.assistantCount,
    required this.workersCount,
  });

  factory _ContractorReportRow.fromMap(Map<String, dynamic> m) {
    int parse(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }
    return _ContractorReportRow(
      contractorName: (m['contractor_name'] ?? '—').toString(),
      engineerName: (m['user_name'] ?? '—').toString(),
      projectName: (m['project_name'] ?? '—').toString(),
      workPlace: (m['work_place'] ?? '—').toString(),
      planDate: parseDate(m['plan_date']),
      craftsmanCount: parse(m['craftsman_count']),
      assistantCount: parse(m['assistant_count']),
      workersCount: parse(m['workers_count']),
    );
  }
}
