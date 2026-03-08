import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../utils/pdf_share.dart';
import '../models/project_model.dart';
import '../models/daily_report_model.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// شاشة التقارير لمدير المهندسين: فلتر (مهندس، من تاريخ، إلى تاريخ، مشروع اختياري) وعرض التقارير اليومية + تصدير PDF
class ReportsScreen extends StatefulWidget {
  final UserModel currentUser;

  const ReportsScreen({super.key, required this.currentUser});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = getStorage();
  List<UserModel> _engineers = [];
  List<ProjectModel> _projects = [];
  UserModel? _selectedEngineer;
  ProjectModel? _selectedProject;
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<DailyReportData> _reports = [];
  /// مفتاح: 'userId_year_month_day' — قيمة: (حضور، انصراف)
  Map<String, ({DateTime? checkIn, DateTime? checkOut})> _attendanceMap = {};
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadEngineersAndProjects();
  }

  Future<void> _loadEngineersAndProjects() async {
    final engineers = await _db.getSiteEngineers();
    final projects = await _db.getProjects();
    if (!mounted) return;
    setState(() {
      _engineers = engineers;
      _projects = projects;
    });
  }

  Future<void> _runReport() async {
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final reports = await _db.getDailyReports(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        userId: _selectedEngineer?.id,
        projectId: _selectedProject?.id,
      );
      final map = <String, ({DateTime? checkIn, DateTime? checkOut})>{};
      for (final r in reports) {
        final key = '${r.userId}_${r.reportDate.year}_${r.reportDate.month}_${r.reportDate.day}';
        map[key] = await _db.getAttendanceForUserOnDate(r.userId, r.reportDate);
      }
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _attendanceMap = map;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _newReport() {
    setState(() {
      _reports = [];
      _attendanceMap = {};
      _hasSearched = false;
      _dateFrom = DateTime.now();
      _dateTo = DateTime.now();
      _selectedEngineer = null;
      _selectedProject = null;
    });
  }

  String _attendanceKey(DailyReportData r) =>
      '${r.userId}_${r.reportDate.year}_${r.reportDate.month}_${r.reportDate.day}';

  Future<void> _exportPdf() async {
    if (_reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد تقارير لتصديرها')),
      );
      return;
    }
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
    for (final r in _reports) {
      final att = _attendanceMap[_attendanceKey(r)];
      final checkInStr = att?.checkIn != null ? timeFormat.format(att!.checkIn!) : '—';
      final checkOutStr = att?.checkOut != null ? timeFormat.format(att!.checkOut!) : '—';
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          build: (ctx) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Center(
                    child: pw.Container(
                      height: 56,
                      margin: const pw.EdgeInsets.only(bottom: 12),
                      child: pw.Image(logoImage!, fit: pw.BoxFit.contain),
                    ),
                  ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.green800),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'التقرير اليومي | Daily Report',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                    ),
                  ),
                ),
                pw.SizedBox(height: 16),
                _pdfSectionTitle('بيانات التقرير | Report Data'),
                pw.SizedBox(height: 6),
                _pdfRow('المهندس | Engineer', r.userName),
                _pdfRow('موعد الحضور | Check-in', checkInStr),
                _pdfRow('موعد الانصراف | Check-out', checkOutStr),
                _pdfRow('التاريخ | Date', dateFormat.format(r.reportDate)),
                _pdfRow('المشروع | Project', r.projectName ?? '—'),
                _pdfRow('مكان العمل | Work Place', r.workPlace),
                pw.SizedBox(height: 14),
                _pdfSectionTitle('تفاصيل الأعمال | Work Details'),
                pw.SizedBox(height: 6),
                _pdfRow('تقرير الأعمال | Work Report', r.workReport),
                _pdfRow('ما تم تنفيذه اليوم | Executed Today', r.executedToday),
                _pdfRow('المشرف | Supervisor', r.supervisorName),
                _pdfRow('المقاول | Contractor', r.contractorName),
                _pdfRow('عدد العمال | Workers Count', r.workersCount),
                _pdfRow('خطة الغد | Tomorrow Plan', r.tomorrowPlan),
                if (r.notes.isNotEmpty) _pdfRow('ملاحظات | Notes', r.notes),
                pw.SizedBox(height: 14),
                _pdfSectionTitle('الخامات والكميات | Materials & Quantities'),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1)},
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _pdfCell('الخامة | Material', isHeader: true),
                        _pdfCell('الكمية | Qty', isHeader: true),
                        _pdfCell('الوحدة | Unit', isHeader: true),
                      ],
                    ),
                    ...List.generate(5, (i) {
                      final m = r.materials[i];
                      return pw.TableRow(
                        children: [
                          _pdfCell(m.materialName.isEmpty ? '—' : m.materialName, isHeader: false),
                          _pdfCell(m.quantity, isHeader: false),
                          _pdfCell(m.unit, isHeader: false),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 14),
                _pdfSectionTitle('المصروفات | Expenses'),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1.2)},
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _pdfCell('البيان | Description', isHeader: true),
                        _pdfCell('المبلغ | Amount', isHeader: true),
                      ],
                    ),
                    ...List.generate(4, (i) {
                      final e = r.expenses[i];
                      return pw.TableRow(
                        children: [
                          _pdfCell(e.description.isEmpty ? '—' : e.description, isHeader: false),
                          _pdfCell(e.amount, isHeader: false),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    final bytes = await doc.save();
    final dateFromStr = dateFormat.format(_dateFrom);
    final dateToStr = dateFormat.format(_dateTo);
    await sharePdfBytes(bytes, 'تقارير_يومية_${dateFromStr}_${dateToStr}.pdf');
  }

  pw.Widget _pdfSectionTitle(String text) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
      ),
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 180,
            child: pw.Text(
              label,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? '—' : value,
              textDirection: pw.TextDirection.rtl,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, {required bool isHeader}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.green900 : PdfColors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser)),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'معايير التقرير',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // مهندس
          DropdownButtonFormField<UserModel?>(
            value: _selectedEngineer,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المهندس',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المهندسين')),
              ..._engineers.map((e) => DropdownMenuItem(value: e, child: Text(e.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _selectedEngineer = v),
          ),
          const SizedBox(height: 16),
          // من تاريخ
          ListTile(
            title: const Text('من تاريخ *'),
            subtitle: Text(DateFormat('yyyy/MM/dd', 'ar').format(_dateFrom)),
            trailing: const Icon(Icons.calendar_today),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _dateFrom, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _dateFrom = d);
            },
          ),
          const SizedBox(height: 16),
          // إلى تاريخ
          ListTile(
            title: const Text('إلى تاريخ *'),
            subtitle: Text(DateFormat('yyyy/MM/dd', 'ar').format(_dateTo)),
            trailing: const Icon(Icons.calendar_today),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _dateTo, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _dateTo = d);
            },
          ),
          const SizedBox(height: 16),
          // المشروع (اختياري)
          DropdownButtonFormField<ProjectModel?>(
            value: _selectedProject,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المشروع (اختياري)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المشاريع')),
              ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _selectedProject = v),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _runReport,
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
            label: Text(_loading ? 'جاري التحميل...' : 'عرض التقرير'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_hasSearched) ...[
            const SizedBox(height: 24),
            Text(
              'النتائج (${_reports.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_reports.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('لا توجد تقارير في الفترة المحددة', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              )
            else
              ..._reports.map((r) => _ReportCard(
                    report: r,
                    checkIn: _attendanceMap[_attendanceKey(r)]?.checkIn,
                    checkOut: _attendanceMap[_attendanceKey(r)]?.checkOut,
                  )),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 340;
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: _reports.isEmpty ? null : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf, size: 20),
                        label: const Text('تصدير PDF'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _newReport,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('تقرير جديد'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B5E20),
                          side: const BorderSide(color: Color(0xFF1B5E20)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _reports.isEmpty ? null : _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('تصدير PDF'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _newReport,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تقرير جديد'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1B5E20),
                          side: const BorderSide(color: Color(0xFF1B5E20)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final DailyReportData report;
  final DateTime? checkIn;
  final DateTime? checkOut;

  const _ReportCard({required this.report, this.checkIn, this.checkOut});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final timeFormat = DateFormat('hh:mm a', 'ar');
    final checkInStr = checkIn != null ? timeFormat.format(checkIn!) : '—';
    final checkOutStr = checkOut != null ? timeFormat.format(checkOut!) : '—';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Row(
          children: [
            Expanded(child: Text(report.userName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(dateFormat.format(report.reportDate), style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (report.projectName != null && report.projectName!.isNotEmpty)
              Text(report.projectName!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            Text('حضور: $checkInStr  |  انصراف: $checkOutStr', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'مكان العمل', value: report.workPlace),
                _InfoRow(label: 'تقرير الأعمال', value: report.workReport),
                _InfoRow(label: 'ما تم تنفيذه اليوم', value: report.executedToday),
                _InfoRow(label: 'المشرف', value: report.supervisorName),
                _InfoRow(label: 'المقاول', value: report.contractorName),
                _InfoRow(label: 'عدد العمال', value: report.workersCount),
                _InfoRow(label: 'خطة الغد', value: report.tomorrowPlan),
                if (report.notes.isNotEmpty) _InfoRow(label: 'ملاحظات', value: report.notes),
                const SizedBox(height: 8),
                const Text('الخامات والكميات', style: TextStyle(fontWeight: FontWeight.bold)),
                ...report.materials.where((m) => m.materialName.isNotEmpty).map((m) => Padding(
                      padding: const EdgeInsets.only(right: 16, top: 4),
                      child: Text('• ${m.materialName} - ${m.quantity} ${m.unit}'),
                    )),
                const SizedBox(height: 8),
                const Text('المصروفات', style: TextStyle(fontWeight: FontWeight.bold)),
                ...report.expenses.where((e) => e.description.isNotEmpty || e.amount.isNotEmpty).map((e) => Padding(
                      padding: const EdgeInsets.only(right: 16, top: 4),
                      child: Text('• ${e.description} - ${e.amount}'),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
