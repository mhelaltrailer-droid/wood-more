import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
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
      if (!mounted) return;
      setState(() {
        _reports = reports;
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
      _hasSearched = false;
      _dateFrom = DateTime.now();
      _dateTo = DateTime.now();
      _selectedEngineer = null;
      _selectedProject = null;
    });
  }

  Future<void> _exportPdf() async {
    if (_reports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد تقارير لتصديرها')),
      );
      return;
    }
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final fontBase = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);
    final doc = pw.Document();
    for (final r in _reports) {
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'تقرير يومي - ${r.userName} - ${dateFormat.format(r.reportDate)}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Paragraph(text: 'المشروع: ${r.projectName ?? "-"}'),
            pw.Paragraph(text: 'مكان العمل: ${r.workPlace}'),
            pw.Paragraph(text: 'تقرير الأعمال: ${r.workReport}'),
            pw.Paragraph(text: 'ما تم تنفيذه اليوم: ${r.executedToday}'),
            pw.Paragraph(text: 'المشرف: ${r.supervisorName}'),
            pw.Paragraph(text: 'المقاول: ${r.contractorName}'),
            pw.Paragraph(text: 'عدد العمال: ${r.workersCount}'),
            pw.Paragraph(text: 'خطة الغد: ${r.tomorrowPlan}'),
            if (r.notes.isNotEmpty) pw.Paragraph(text: 'ملاحظات: ${r.notes}'),
            pw.SizedBox(height: 12),
            pw.Text('الخامات والكميات', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...r.materials.where((m) => m.materialName.isNotEmpty).map((m) => pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 12),
                  child: pw.Text('${m.materialName} - ${m.quantity} ${m.unit}'),
                )),
            pw.SizedBox(height: 12),
            pw.Text('المصروفات', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ...r.expenses.where((e) => e.description.isNotEmpty || e.amount.isNotEmpty).map((e) => pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 12),
                  child: pw.Text('${e.description} - ${e.amount}'),
                )),
          ],
        ),
      );
    }
    final bytes = await doc.save();
    final dateFromStr = dateFormat.format(_dateFrom);
    final dateToStr = dateFormat.format(_dateTo);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'تقارير_يومية_${dateFromStr}_${dateToStr}.pdf',
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
            decoration: const InputDecoration(
              labelText: 'المهندس',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المهندسين')),
              ..._engineers.map((e) => DropdownMenuItem(value: e, child: Text(e.name))),
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
            decoration: const InputDecoration(
              labelText: 'المشروع (اختياري)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المشاريع')),
              ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
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
              ..._reports.map((r) => _ReportCard(report: r)),
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

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
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
        subtitle: report.projectName != null && report.projectName!.isNotEmpty
            ? Text(report.projectName!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))
            : null,
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
