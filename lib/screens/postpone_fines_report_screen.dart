import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/contractor_model.dart';
import '../models/postpone_fine_report_row_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/pdf_share.dart';

String _fmtPlanDate(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '—';
  final d = DateTime.tryParse(t);
  if (d == null) return t;
  return DateFormat('yyyy/MM/dd', 'ar').format(
    DateTime(d.year, d.month, d.day),
  );
}

class PostponeFinesReportScreen extends StatefulWidget {
  final UserModel currentUser;

  const PostponeFinesReportScreen({super.key, required this.currentUser});

  @override
  State<PostponeFinesReportScreen> createState() =>
      _PostponeFinesReportScreenState();
}

class _PostponeFinesReportScreenState extends State<PostponeFinesReportScreen> {
  final _db = getStorage();

  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();

  List<UserModel> _engineers = [];
  List<ProjectModel> _projects = [];
  List<ContractorModel> _contractors = [];
  List<Map<String, dynamic>> _reasonRows = [];

  int? _engineerIdFilter;
  int? _projectIdFilter;
  int? _contractorIdFilter;
  String? _reasonKeyFilter;

  List<PostponeFineReportRowModel> _rows = [];
  bool _loadingLists = true;
  bool _loadingReport = false;
  bool _hasSearched = false;
  String? _listError;

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _dateFrom = DateTime(n.year, n.month, 1);
    _dateTo = _dateOnly(n);
    _loadFilterLists();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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

  Future<void> _loadFilterLists() async {
    final db = _db;
    if (db is! ApiStorageService) {
      setState(() {
        _loadingLists = false;
        _listError = 'هذا التقرير يتطلب الاتصال بالخادم (وضع API).';
      });
      return;
    }
    final ApiStorageService api = db;
    setState(() {
      _loadingLists = true;
      _listError = null;
    });
    try {
      final eng = await api.getSiteEngineers();
      final proj = await api.getProjects();
      final contr = await api.getContractors();
      final reasons = await api.getPostponeReasons();
      if (!mounted) return;
      setState(() {
        _engineers = eng;
        _projects = proj;
        _contractors = contr;
        _reasonRows = reasons;
        _loadingLists = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLists = false;
        _listError = 'تعذر تحميل قوائم الفلترة: $e';
      });
    }
  }

  Future<void> _runReport() async {
    final db = _db;
    if (db is! ApiStorageService) return;
    final ApiStorageService api = db;
    if (_dateFrom.isAfter(_dateTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تاريخ البداية يجب أن يكون قبل أو يساوي تاريخ النهاية')),
      );
      return;
    }
    setState(() {
      _loadingReport = true;
      _hasSearched = true;
    });
    try {
      final list = await api.getPostponeFinesReport(
        actorUserId: widget.currentUser.id,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        engineerUserId: _engineerIdFilter,
        projectId: _projectIdFilter,
        contractorId: _contractorIdFilter,
        reasonKey: _reasonKeyFilter,
      );
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loadingReport = false;
      });
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد نتائج للمعايير المحددة')),
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
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لتصديرها')),
      );
      return;
    }
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
                    'تقارير التأجيل والغرامات',
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
                'من $fromStr إلى $toStr',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
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
                0: const pw.FlexColumnWidth(1.1),
                1: const pw.FlexColumnWidth(1.1),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(0.75),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(0.9),
                6: const pw.FlexColumnWidth(0.7),
                7: const pw.FlexColumnWidth(0.75),
                8: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfCell('المهندس', isHeader: true),
                    _pdfCell('المشروع', isHeader: true),
                    _pdfCell('مقاولو الخطة', isHeader: true),
                    _pdfCell('تاريخ الخطة', isHeader: true),
                    _pdfCell('سبب التأجيل', isHeader: true),
                    _pdfCell('اقتراح غرامة (مهندس)', isHeader: true),
                    _pdfCell('قيمة الغرامة الموقعة', isHeader: true),
                    _pdfCell('الطرف الموقع عليه', isHeader: true),
                    _pdfCell('ملخص قرار الغرامة', isHeader: true),
                  ],
                ),
                ..._rows.map(
                  (r) => pw.TableRow(
                    children: [
                      _pdfCell(r.userName),
                      _pdfCell(r.projectName?.trim().isNotEmpty == true ? r.projectName! : '—'),
                      _pdfCell(r.contractorsInPlanLabel),
                      _pdfCell(_fmtPlanDate(r.planDate)),
                      _pdfCell(r.postponeReasonDisplay),
                      _pdfCell(r.engineerFineLabelAr),
                      _pdfCell(r.signedFineAmountColumn),
                      _pdfCell(r.signedFinePartyColumn),
                      _pdfCell(r.semDecisionShort),
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
    await sharePdfBytes(
      bytes,
      'تقرير_التأجيل_والغرامات_${fromStr}_$toStr.pdf',
    );
  }

  static pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
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
    if (!widget.currentUser.canAccessPostponeFinesReports) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تقارير التأجيل/الغرامات'),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('غير مصرح لك بعرض هذه الشاشة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير التأجيل/الغرامات'),
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
                              value: _engineerIdFilter,
                              decoration: const InputDecoration(
                                labelText: 'المهندس',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('جميع المهندسين'),
                                ),
                                ..._engineers.map(
                                  (u) => DropdownMenuItem<int?>(
                                    value: u.id,
                                    child: Text(u.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _engineerIdFilter = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int?>(
                              value: _projectIdFilter,
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
                            DropdownButtonFormField<int?>(
                              value: _contractorIdFilter,
                              decoration: const InputDecoration(
                                labelText: 'المقاول',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('كل المقاولين'),
                                ),
                                ..._contractors.map(
                                  (c) => DropdownMenuItem<int?>(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _contractorIdFilter = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String?>(
                              value: _reasonKeyFilter,
                              decoration: const InputDecoration(
                                labelText: 'سبب التأجيل',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('كل الأسباب'),
                                ),
                                ..._reasonRows.map((row) {
                                  final key =
                                      (row['reason_key'] ?? '').toString();
                                  final label =
                                      (row['label'] ?? key).toString();
                                  return DropdownMenuItem<String?>(
                                    value: key,
                                    child: Text(label),
                                  );
                                }),
                              ],
                              onChanged: (v) =>
                                  setState(() => _reasonKeyFilter = v),
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
                                _loadingReport ? 'جاري التحميل...' : 'عرض التقرير',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                            if (_hasSearched && !_loadingReport) ...[
                              const SizedBox(height: 24),
                              Text(
                                'النتائج: ${_rows.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_rows.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Text('لا توجد صفوف للعرض'),
                                  ),
                                )
                              else
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor:
                                        WidgetStateProperty.all(
                                      Colors.green.shade100,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('المهندس')),
                                      DataColumn(label: Text('المشروع')),
                                      DataColumn(label: Text('مقاولو الخطة')),
                                      DataColumn(label: Text('تاريخ الخطة')),
                                      DataColumn(label: Text('سبب التأجيل')),
                                      DataColumn(
                                        label: Text('اقتراح غرامة (مهندس)'),
                                      ),
                                      DataColumn(
                                        label: Text('قيمة الغرامة الموقعة'),
                                      ),
                                      DataColumn(
                                        label: Text('الطرف الموقع عليه'),
                                      ),
                                      DataColumn(
                                        label: Text('ملخص قرار الغرامة'),
                                      ),
                                    ],
                                    rows: _rows.map((r) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(r.userName)),
                                          DataCell(
                                            Text(
                                              r.projectName?.trim().isNotEmpty ==
                                                      true
                                                  ? r.projectName!
                                                  : '—',
                                            ),
                                          ),
                                          DataCell(
                                            Text(r.contractorsInPlanLabel),
                                          ),
                                          DataCell(
                                            Text(_fmtPlanDate(r.planDate)),
                                          ),
                                          DataCell(
                                            Text(r.postponeReasonDisplay),
                                          ),
                                          DataCell(
                                            Text(r.engineerFineLabelAr),
                                          ),
                                          DataCell(
                                            Text(r.signedFineAmountColumn),
                                          ),
                                          DataCell(
                                            Text(r.signedFinePartyColumn),
                                          ),
                                          DataCell(Text(r.semDecisionShort)),
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
