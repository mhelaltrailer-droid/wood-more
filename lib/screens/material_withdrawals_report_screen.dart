import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/material_withdrawal_report_row_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/pdf_share.dart';

String _fmtDateTime(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return '—';
  final d = DateTime.tryParse(t);
  if (d == null) return t;
  return DateFormat('yyyy/MM/dd', 'ar').format(DateTime(d.year, d.month, d.day));
}

class _StatusFilter {
  final String? value;
  final String label;
  const _StatusFilter(this.value, this.label);
}

const _statusFilters = <_StatusFilter>[
  _StatusFilter(null, 'كل الحالات'),
  _StatusFilter('completed', 'تم إكمال السحب'),
  _StatusFilter('not_completed', 'لم يكتمل السحب'),
  _StatusFilter('request_only', 'طلب سحب فقط — بانتظار الاعتماد'),
  _StatusFilter('approved_pending', 'معتمد — بانتظار إكمال السحب'),
  _StatusFilter('rejected', 'طلب مرفوض'),
];

/// تقرير سحب الخامات: المشاريع ومواقع العمل التي تم سحب خامتها من التطبيق،
/// مع توضيح ما إذا كان الأمر طلب سحب فقط أم تم إكمال السحب وإرفاق الأذون.
class MaterialWithdrawalsReportScreen extends StatefulWidget {
  final UserModel currentUser;

  const MaterialWithdrawalsReportScreen({super.key, required this.currentUser});

  @override
  State<MaterialWithdrawalsReportScreen> createState() =>
      _MaterialWithdrawalsReportScreenState();
}

class _MaterialWithdrawalsReportScreenState
    extends State<MaterialWithdrawalsReportScreen> {
  final _db = getStorage();

  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();

  List<ProjectModel> _projects = [];
  List<UserModel> _engineers = [];
  int? _projectIdFilter;
  int? _engineerIdFilter;
  String? _statusFilter;

  List<MaterialWithdrawalReportRowModel> _rows = [];
  bool _loadingLists = true;
  bool _loadingReport = false;
  bool _hasSearched = false;
  String? _listError;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int get _completedCount => _rows.where((r) => r.isCompleted).length;
  int get _pendingCount => _rows.length - _completedCount;

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
      final engineers = await db.getSiteEngineers();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _engineers = engineers;
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
      final list = await db.getMaterialWithdrawalsReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        projectId: _projectIdFilter,
        engineerUserId: _engineerIdFilter,
        status: _statusFilter,
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
                    'تقرير سحب الخامات — المشاريع ومواقع العمل',
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
                'من $fromStr إلى $toStr — الإجمالي: ${_rows.length} | مكتمل: $_completedCount | طلب فقط: $_pendingCount',
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
                1: const pw.FlexColumnWidth(1.6),
                2: const pw.FlexColumnWidth(0.9),
                3: const pw.FlexColumnWidth(1.7),
                4: const pw.FlexColumnWidth(0.85),
                5: const pw.FlexColumnWidth(0.85),
                6: const pw.FlexColumnWidth(1.1),
                7: const pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfCell('المشروع', isHeader: true),
                    _pdfCell('موقع العمل', isHeader: true),
                    _pdfCell('المرحلة', isHeader: true),
                    _pdfCell('حالة السحب', isHeader: true),
                    _pdfCell('تاريخ الطلب', isHeader: true),
                    _pdfCell('تاريخ الإتمام', isHeader: true),
                    _pdfCell('المستخدم', isHeader: true),
                    _pdfCell('المرفقات', isHeader: true),
                  ],
                ),
                ..._rows.map(
                  (r) => pw.TableRow(
                    children: [
                      _pdfCell(r.projectName),
                      _pdfCell(r.locationPath),
                      _pdfCell(r.phaseLabel),
                      _pdfCell(r.statusLabel),
                      _pdfCell(_fmtDateTime(r.requestCreatedAt)),
                      _pdfCell(_fmtDateTime(r.withdrawalCreatedAt)),
                      _pdfCell(r.responsibleUserName),
                      _pdfCell(r.attachmentsLabel),
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
    await sharePdfBytes(bytes, 'تقرير_سحب_الخامات_${fromStr}_$toStr.pdf');
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
        title: const Text('تقرير سحب الخامات'),
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
                            DropdownButtonFormField<int?>(
                              value: _engineerIdFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'مهندس الموقع',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('كل المهندسين'),
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
                            DropdownButtonFormField<String?>(
                              value: _statusFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'حالة السحب',
                                border: OutlineInputBorder(),
                              ),
                              items: _statusFilters
                                  .map(
                                    (f) => DropdownMenuItem<String?>(
                                      value: f.value,
                                      child: Text(f.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _statusFilter = v),
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _summaryChip(
                                    'الإجمالي: ${_rows.length}',
                                    Colors.blueGrey,
                                  ),
                                  _summaryChip(
                                    'تم إكمال السحب: $_completedCount',
                                    Colors.green,
                                  ),
                                  _summaryChip(
                                    'طلب سحب فقط: $_pendingCount',
                                    Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_rows.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child:
                                      Center(child: Text('لا توجد صفوف للعرض')),
                                )
                              else
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      Colors.green.shade100,
                                    ),
                                    columns: const [
                                      DataColumn(label: Text('المشروع')),
                                      DataColumn(label: Text('موقع العمل')),
                                      DataColumn(label: Text('المرحلة')),
                                      DataColumn(label: Text('حالة السحب')),
                                      DataColumn(label: Text('تاريخ الطلب')),
                                      DataColumn(label: Text('تاريخ الإتمام')),
                                      DataColumn(label: Text('المستخدم')),
                                      DataColumn(
                                        label: Text('مدير المشروعات'),
                                      ),
                                      DataColumn(label: Text('مدير العمليات')),
                                      DataColumn(label: Text('المرفقات')),
                                    ],
                                    rows: _rows.map((r) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(r.projectName)),
                                          DataCell(
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 220,
                                              ),
                                              child: Text(r.locationPath),
                                            ),
                                          ),
                                          DataCell(Text(r.phaseLabel)),
                                          DataCell(_statusCell(r)),
                                          DataCell(
                                            Text(
                                              _fmtDateTime(r.requestCreatedAt),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _fmtDateTime(
                                                r.withdrawalCreatedAt,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(r.responsibleUserName),
                                          ),
                                          DataCell(Text(r.semStatusLabel)),
                                          DataCell(Text(r.omStatusLabel)),
                                          DataCell(Text(r.attachmentsLabel)),
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

  Widget _statusCell(MaterialWithdrawalReportRowModel r) {
    final color = r.isCompleted
        ? Colors.green.shade800
        : r.status == 'rejected'
            ? Colors.red.shade700
            : Colors.orange.shade800;
    final reason = r.rejectionReason;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            r.statusLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          if (r.status == 'rejected' && reason != null)
            Text(
              'السبب: $reason',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Chip(
      label: Text(label, style: TextStyle(color: color)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}
