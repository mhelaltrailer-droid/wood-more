import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/project_model.dart';
import '../models/uploaded_file_report_row_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/pdf_share.dart';

String _fmtDate(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return '—';
  final d = DateTime.tryParse(t);
  if (d == null) return t;
  return DateFormat('yyyy/MM/dd', 'ar').format(DateTime(d.year, d.month, d.day));
}

/// تقرير الملفات المرفوعة حالياً: اسم المشروع، تاريخ الرفع، المستخدم الرافع،
/// ونوع المرفق (IR / MIR / MS / SD / MoS / ITP / Shop-Drawing / PO / أذون السحب).
class UploadedFilesReportScreen extends StatefulWidget {
  final UserModel currentUser;

  const UploadedFilesReportScreen({super.key, required this.currentUser});

  @override
  State<UploadedFilesReportScreen> createState() =>
      _UploadedFilesReportScreenState();
}

class _UploadedFilesReportScreenState extends State<UploadedFilesReportScreen> {
  final _db = getStorage();

  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();

  List<ProjectModel> _projects = [];
  int? _projectIdFilter;
  String? _kindFilter;

  List<UploadedFileReportRowModel> _rows = [];
  bool _loadingLists = true;
  bool _loadingReport = false;
  bool _hasSearched = false;
  String? _listError;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// عدد الملفات لكل نوع، لعرض ملخص سريع أعلى الجدول.
  Map<String, int> get _countsByKind {
    final counts = <String, int>{};
    for (final r in _rows) {
      counts[r.kindLabel] = (counts[r.kindLabel] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _dateFrom = DateTime(n.year, n.month, 1);
    _dateTo = _dateOnly(n);
    _loadFilterLists();
  }

  Future<void> _loadFilterLists() async {
    final db = _db;
    if (db is! ApiStorageService) {
      setState(() {
        _loadingLists = false;
        _listError = 'هذا التقرير يتطلب الاتصال بالخادم (وضع API).';
      });
      return;
    }
    setState(() {
      _loadingLists = true;
      _listError = null;
    });
    try {
      final projects = await db.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loadingLists = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLists = false;
        _listError = 'تعذر تحميل قائمة المشاريع: $e';
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _dateFrom : _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = _dateOnly(picked);
      } else {
        _dateTo = _dateOnly(picked);
      }
    });
  }

  Future<void> _runReport() async {
    final db = _db;
    if (db is! ApiStorageService) return;
    if (_dateFrom.isAfter(_dateTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاريخ البداية يجب أن يكون قبل أو يساوي تاريخ النهاية'),
        ),
      );
      return;
    }
    setState(() {
      _loadingReport = true;
      _hasSearched = true;
    });
    try {
      final list = await db.getUploadedFilesReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        projectId: _projectIdFilter,
        kind: _kindFilter,
      );
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loadingReport = false;
      });
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد ملفات للمعايير المحددة')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingReport = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_rows.isEmpty) return;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final fontBase = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}
    final fromStr = dateFormat.format(_dateFrom);
    final toStr = dateFormat.format(_dateTo);
    final summary = _countsByKind.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(' | ');
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        header: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (logoImage != null)
                pw.Center(
                  child: pw.Container(
                    height: 44,
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green800),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'تقرير الملفات المرفوعة',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'من $fromStr إلى $toStr — إجمالي الملفات: ${_rows.length}',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              if (summary.isNotEmpty)
                pw.Text(
                  summary,
                  textDirection: pw.TextDirection.rtl,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              pw.SizedBox(height: 8),
            ],
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.3),
                1: const pw.FlexColumnWidth(0.85),
                2: const pw.FlexColumnWidth(1.1),
                3: const pw.FlexColumnWidth(0.9),
                4: const pw.FlexColumnWidth(1.6),
                5: const pw.FlexColumnWidth(1.5),
                6: const pw.FlexColumnWidth(0.7),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfCell('اسم المشروع', isHeader: true),
                    _pdfCell('نوع المرفق', isHeader: true),
                    _pdfCell('المستخدم الرافع', isHeader: true),
                    _pdfCell('تاريخ الرفع', isHeader: true),
                    _pdfCell('اسم الملف', isHeader: true),
                    _pdfCell('المرجع', isHeader: true),
                    _pdfCell('الحجم', isHeader: true),
                  ],
                ),
                ..._rows.map(
                  (r) => pw.TableRow(
                    children: [
                      _pdfCell(r.projectName),
                      _pdfCell(r.kindLabel),
                      _pdfCell(r.userName),
                      _pdfCell(_fmtDate(r.uploadedAt)),
                      _pdfCell(r.fileName),
                      _pdfCell(r.contextLabel),
                      _pdfCell(r.sizeLabel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await sharePdfBytes(bytes, 'تقرير_الملفات_المرفوعة_${fromStr}_$toStr.pdf');
  }

  static pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text.trim().isEmpty ? '—' : text,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.green900 : PdfColors.black,
        ),
        maxLines: 4,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الملفات المرفوعة'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (_hasSearched && _rows.isNotEmpty && !_loadingReport)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير PDF',
              onPressed: _exportPdf,
            ),
        ],
      ),
      body: _loadingLists
          ? const Center(child: CircularProgressIndicator())
          : _listError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _listError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickDate(isFrom: true),
                                    icon: const Icon(Icons.date_range),
                                    label: Text(
                                      'من: ${DateFormat('yyyy/MM/dd', 'ar').format(_dateFrom)}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _pickDate(isFrom: false),
                                    icon: const Icon(Icons.date_range),
                                    label: Text(
                                      'إلى: ${DateFormat('yyyy/MM/dd', 'ar').format(_dateTo)}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: _projectIdFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'المشروع',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('كل المشاريع'),
                                ),
                                ..._projects.map(
                                  (p) => DropdownMenuItem<int?>(
                                    value: p.id,
                                    child: Text(p.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _projectIdFilter = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _kindFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'نوع المرفق',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('كل الأنواع'),
                                ),
                                ...uploadedFileKindFilters.entries.map(
                                  (e) => DropdownMenuItem<String?>(
                                    value: e.key,
                                    child: Text(e.value),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() => _kindFilter = v),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _loadingReport ? null : _runReport,
                              icon: _loadingReport
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(
                                _loadingReport
                                    ? 'جاري التحميل...'
                                    : 'عرض التقرير',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            if (_hasSearched && !_loadingReport) ...[
                              const SizedBox(height: 24),
                              Text(
                                'إجمالي الملفات: ${_rows.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _countsByKind.entries
                                    .map(
                                      (e) => Chip(
                                        label: Text('${e.key}: ${e.value}'),
                                        backgroundColor: Colors.green.shade50,
                                        side: BorderSide(
                                          color: Colors.green.shade200,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              if (_rows.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child:
                                      Center(child: Text('لا توجد ملفات للعرض')),
                                )
                              else
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.green.shade100,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('اسم المشروع')),
                                      DataColumn(label: Text('نوع المرفق')),
                                      DataColumn(
                                        label: Text('المستخدم الرافع'),
                                      ),
                                      DataColumn(label: Text('تاريخ الرفع')),
                                      DataColumn(label: Text('اسم الملف')),
                                      DataColumn(label: Text('المرجع')),
                                      DataColumn(label: Text('الحجم')),
                                    ],
                                    rows: _rows.map((r) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(r.projectName)),
                                          DataCell(
                                            Chip(
                                              label: Text(
                                                r.kindLabel,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              backgroundColor:
                                                  Colors.green.shade50,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                          DataCell(Text(r.userName)),
                                          DataCell(
                                            Text(_fmtDate(r.uploadedAt)),
                                          ),
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 220,
                                              ),
                                              child: Text(
                                                r.fileName,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 220,
                                              ),
                                              child: Text(
                                                r.contextLabel.isEmpty
                                                    ? '—'
                                                    : r.contextLabel,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text(r.sizeLabel)),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (_hasSearched && _rows.isNotEmpty && !_loadingReport)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: FilledButton.icon(
                            onPressed: _exportPdf,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('تصدير PDF'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF33691E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
