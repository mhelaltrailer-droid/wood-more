import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/detailed_report_model.dart';
import '../models/project_location_model.dart';
import '../models/project_model.dart';
import '../models/location_withdrawal_for_period_model.dart';
import '../models/user_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import '../utils/pdf_share.dart';
import 'home_screen.dart';
import 'reports_screen.dart' show canEditDeleteDailyReport;

/// عرض موقع العمل: المستوى الأب (المستوى الأول) ثم الفرع بين أقواس، مثل: Shed02 (Villa77)
String _formatLocationHierarchy(ProjectLocationModel loc, Map<int, ProjectLocationModel> byId) {
  final parent = loc.parentId != null ? byId[loc.parentId!] : null;
  if (parent != null) {
    return '${parent.name} (${loc.name})';
  }
  return loc.name;
}

/// كل سحوبات المشروع في نفس يوم التقرير، مع اسم المستخدم ومسار الموقع الهرمي
String _withdrawalsTextForProjectDay(
  int? projectId,
  String engineerName,
  DateTime reportDate,
  List<LocationWithdrawalForPeriodModel> withdrawals,
  Map<int, ProjectLocationModel> locationById,
  String Function(DateTime) dayKey,
) {
  if (projectId == null) return '---------';
  final dk = dayKey(reportDate);
  final relevant = <LocationWithdrawalForPeriodModel>[];
  for (final w in withdrawals) {
    if (w.projectId == projectId &&
        dayKey(w.createdAt) == dk &&
        w.userName.trim() == engineerName.trim()) {
      relevant.add(w);
    }
  }
  if (relevant.isEmpty) return '---------';
  relevant.sort((a, b) => a.userName.compareTo(b.userName));
  final lines = <String>[];
  for (final w in relevant) {
    final loc = locationById[w.locationId];
    final locLabel = loc != null ? _formatLocationHierarchy(loc, locationById) : 'موقع #${w.locationId}';
    final parts = <String>[];
    for (final m in w.materials) {
      final u = m.unit.trim().isEmpty ? '' : ' ${m.unit}';
      final line = '${m.materialName} ${m.quantity}$u'.trim();
      if (line.isNotEmpty) {
        parts.add(line);
      }
    }
    final mat = parts.isEmpty ? '—' : parts.join('؛ ');
    lines.add('${w.userName}: من $locLabel — $mat');
  }
  return lines.join('\n');
}

/// تقرير مجمع من التقارير المفصّلة لمهندسي المواقع: فلترة بالمدة والمشروع + سحب الخامات في يوم التقرير
class AggregatedDetailedDailyReportScreen extends StatefulWidget {
  final UserModel currentUser;

  const AggregatedDetailedDailyReportScreen({super.key, required this.currentUser});

  @override
  State<AggregatedDetailedDailyReportScreen> createState() => _AggregatedDetailedDailyReportScreenState();
}

class _TableRowData {
  final int? detailedReportId;
  final bool showDeleteReportAction;
  final DateTime reportDate;
  final String projectName;
  final String engineerName;
  final String contractorName;
  final String workersText;
  final String phasesText;
  final String locationName;
  final String materialsText;
  final String summaryText;
  final String expenseDescriptionText;
  final String expenseAmountText;

  _TableRowData({
    this.detailedReportId,
    this.showDeleteReportAction = false,
    required this.reportDate,
    required this.projectName,
    required this.engineerName,
    required this.contractorName,
    required this.workersText,
    required this.phasesText,
    required this.locationName,
    required this.materialsText,
    required this.summaryText,
    required this.expenseDescriptionText,
    required this.expenseAmountText,
  });
}

class _AggregatedDetailedDailyReportScreenState extends State<AggregatedDetailedDailyReportScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  List<UserModel> _engineers = [];
  ProjectModel? _selectedProject;
  UserModel? _selectedEngineer;
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<_TableRowData> _rows = [];
  bool _loading = false;
  bool _hasSearched = false;

  static String _dayKey(DateTime t) {
    final l = t.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  bool get _canDeleteDetailedReports => canEditDeleteDailyReport(widget.currentUser);

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final projects = await _db.getProjects();
    final engineers = await _db.getSiteEngineers();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _engineers = engineers;
    });
  }

  Future<void> _deleteDetailedReport(int? id) async {
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('حذف هذا التقرير المفصّل بالكامل (جميع السطور)؟ لا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.deleteDetailedReport(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف التقرير'), backgroundColor: Colors.green));
      await _runReport();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _runReport() async {
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final reports = await _db.getDetailedReports(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        userId: _selectedEngineer?.id,
        projectId: _selectedProject?.id,
      );
      final contractors = await _db.getContractors();
      final contractorById = {for (final c in contractors) c.id: c};
      final phases = await _db.getWorkPhases();
      final phaseById = {for (final p in phases) p.id: p};

      final withdrawals = await _db.getLocationWithdrawalsForPeriod(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        projectId: _selectedProject?.id,
      );

      final projectById = {for (final p in _projects) p.id: p};
      final projectIdsNeeded = <int>{};
      for (final r in reports) {
        if (r.projectId != null) projectIdsNeeded.add(r.projectId!);
      }
      for (final w in withdrawals) {
        projectIdsNeeded.add(w.projectId);
      }
      final locationById = <int, ProjectLocationModel>{};
      for (final pid in projectIdsNeeded) {
        final locs = await _db.getProjectLocations(pid);
        for (final loc in locs) {
          locationById[loc.id] = loc;
        }
      }

      String projectLabel(DetailedReportModel r) {
        if (r.projectId != null) {
          return projectById[r.projectId]?.name ?? r.projectName ?? '—';
        }
        return r.projectName?.trim().isNotEmpty == true ? r.projectName!.trim() : '—';
      }

      final out = <_TableRowData>[];
      final deletePlacedForReport = <int>{};
      final shownWithdrawalsKeys = <String>{};
      final shownExpenseKeys = <String>{};

      for (final report in reports) {
        final proj = projectLabel(report);
        final rid = report.id;
        final withdrawKey = '${report.projectId ?? 0}_${report.userName.trim()}_${_dayKey(report.reportDatetime)}';
        final matForDay = _withdrawalsTextForProjectDay(
          report.projectId,
          report.userName,
          report.reportDatetime,
          withdrawals,
          locationById,
          _dayKey,
        );
        final summaryText = (report.summary ?? '').trim().isEmpty ? '—' : report.summary!.trim();
        final expenseDescriptions = <String>[];
        final expenseAmounts = <String>[];
        for (final e in report.expenses) {
          final d = e.description.trim();
          if (d.isNotEmpty) expenseDescriptions.add(d);
          final a = e.amount.trim();
          if (a.isNotEmpty) expenseAmounts.add(a);
        }
        final expenseDescriptionText = expenseDescriptions.isEmpty ? '—' : expenseDescriptions.join(' + ');
        final expenseAmountText = expenseAmounts.isEmpty ? '—' : expenseAmounts.join(' + ');

        void addRow({
          required String contractorName,
          required String workersText,
          required String phasesText,
          required String locationName,
        }) {
          final showWithdrawals = !shownWithdrawalsKeys.contains(withdrawKey);
          if (showWithdrawals) shownWithdrawalsKeys.add(withdrawKey);
          final showExpenses = !shownExpenseKeys.contains(withdrawKey);
          if (showExpenses) shownExpenseKeys.add(withdrawKey);
          final showDel = _canDeleteDetailedReports && rid != null && !deletePlacedForReport.contains(rid);
          if (rid != null && showDel) {
            deletePlacedForReport.add(rid);
          }
          out.add(_TableRowData(
            detailedReportId: rid,
            showDeleteReportAction: showDel,
            reportDate: report.reportDatetime,
            projectName: proj,
            engineerName: report.userName,
            contractorName: contractorName,
            workersText: workersText,
            phasesText: phasesText,
            locationName: locationName,
            materialsText: showWithdrawals ? matForDay : '---------',
            summaryText: summaryText,
            expenseDescriptionText: showExpenses ? expenseDescriptionText : '---------',
            expenseAmountText: showExpenses ? expenseAmountText : '---------',
          ));
        }

        if (report.lines.isEmpty) {
          addRow(contractorName: '—', workersText: '—', phasesText: '—', locationName: '—');
          continue;
        }
        final grouped = <String, List<DetailedReportLineModel>>{};
        for (final line in report.lines) {
          final key = '${line.contractorId ?? 0}_${line.locationId ?? 0}';
          grouped.putIfAbsent(key, () => <DetailedReportLineModel>[]).add(line);
        }
        for (final g in grouped.values) {
          final first = g.first;
          final cname = first.contractorId == null
              ? '—'
              : (contractorById[first.contractorId!]?.name ?? '—');
          String locName = '—';
          if (first.locationId != null) {
            final loc = locationById[first.locationId!];
            locName = loc != null ? _formatLocationHierarchy(loc, locationById) : '—';
          }
          final phaseNames = <String>[];
          for (final line in g) {
            final pname = phaseById[line.phaseId]?.name.trim();
            if (pname != null && pname.isNotEmpty && !phaseNames.contains(pname)) {
              phaseNames.add(pname);
            }
          }
          final phasesText = phaseNames.isEmpty ? '—' : '(${phaseNames.join('+')})';
          final workers = g.map((e) => e.workersCount).fold<int>(0, (a, b) => a > b ? a : b);
          addRow(
            contractorName: cname,
            workersText: workers > 0 ? '$workers' : '—',
            phasesText: phasesText,
            locationName: locName,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = out;
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

  Future<void> _exportPdf() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بيانات لتصديرها')));
      return;
    }
    final fontBase = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final rangeLabel = DateFormat('yyyy-MM-dd', 'ar');
    final doc = pw.Document(theme: theme);
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
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
                'التقرير اليومي المجمع | Aggregated Daily Report',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'من ${rangeLabel.format(_dateFrom)} إلى ${rangeLabel.format(_dateTo)} — ${_selectedProject == null ? 'جميع المشاريع' : _selectedProject!.name}',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(width: 0.45, color: PdfColors.grey600),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.95),
              1: const pw.FlexColumnWidth(1.15),
              2: const pw.FlexColumnWidth(1.15),
              3: const pw.FlexColumnWidth(1.35),
              4: const pw.FlexColumnWidth(0.95),
              5: const pw.FlexColumnWidth(0.5),
              6: const pw.FlexColumnWidth(2.1),
              7: const pw.FlexColumnWidth(1.8),
              8: const pw.FlexColumnWidth(1.5),
              9: const pw.FlexColumnWidth(1.2),
              10: const pw.FlexColumnWidth(0.95),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfCellHdr('المهندس'),
                  _pdfCellHdr('المشروع'),
                  _pdfCellHdr('مكان العمل'),
                  _pdfCellHdr('المراحل'),
                  _pdfCellHdr('المقاول'),
                  _pdfCellHdr('عدد العمال'),
                  _pdfCellHdr('سحب خامات (المستخدم والموقع)'),
                  _pdfCellHdr('ملخص الأعمال اليوم'),
                  _pdfCellHdr('بيان الصرف'),
                  _pdfCellHdr('قيمة المبلغ المنصرف'),
                  _pdfCellHdr('التاريخ'),
                ],
              ),
              ..._rows.map(
                (r) => pw.TableRow(
                  children: [
                    _pdfCellBody(r.engineerName),
                    _pdfCellBody(r.projectName),
                    _pdfCellBody(r.locationName),
                    _pdfCellBody(r.phasesText),
                    _pdfCellBody(r.contractorName),
                    _pdfCellBody(r.workersText),
                    _pdfCellBody(r.materialsText),
                    _pdfCellBody(r.summaryText),
                    _pdfCellBody(r.expenseDescriptionText),
                    _pdfCellBody(r.expenseAmountText),
                    _pdfCellBody(dateFormat.format(r.reportDate)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await sharePdfBytes(bytes, 'تقرير_مجمع_مفصل_${rangeLabel.format(_dateFrom)}_${rangeLabel.format(_dateTo)}.pdf');
  }

  pw.Widget _pdfCellHdr(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          t,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
        ),
      );

  pw.Widget _pdfCellBody(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          t.isEmpty ? '—' : t,
          textDirection: pw.TextDirection.rtl,
          style: const pw.TextStyle(fontSize: 7.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير اليومي المجمع'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (_rows.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير PDF',
              onPressed: _exportPdf,
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser)),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'بناءً على التقارير المفصّلة لمهندسي المواقع: صف واحد لكل سطر في التقرير المفصّل. مكان العمل يُعرض هرمياً (المستوى الأول ثم الفرع بين أقواس). سحب الخامات يعرض كل السحوبات في نفس يوم التقرير ولمشروع التقرير، مع اسم المستخدم وموقع السحب.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('من تاريخ *'),
            subtitle: Text(DateFormat('yyyy/MM/dd', 'ar').format(_dateFrom)),
            trailing: const Icon(Icons.calendar_today),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _dateFrom,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _dateFrom = d);
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('إلى تاريخ *'),
            subtitle: Text(DateFormat('yyyy/MM/dd', 'ar').format(_dateTo)),
            trailing: const Icon(Icons.calendar_today),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: Colors.grey.shade400)),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _dateTo,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _dateTo = d);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectModel?>(
            value: _selectedProject,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المشروع',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المشاريع')),
              ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _selectedProject = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UserModel?>(
            value: _selectedEngineer,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المهندس',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<UserModel?>(value: null, child: Text('جميع المهندسين')),
              ..._engineers.map((e) => DropdownMenuItem<UserModel?>(value: e, child: Text(e.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _selectedEngineer = v),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _runReport,
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
            label: Text(_loading ? 'جاري التحميل...' : 'عرض التقرير'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          if (_hasSearched && !_loading) ...[
            const SizedBox(height: 24),
            Text('عدد الصفوف: ${_rows.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد تقارير مفصّلة في هذه الفترة')),
              )
            else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.green.shade100),
                  columns: [
                    if (_canDeleteDetailedReports) const DataColumn(label: Text('حذف تقرير')),
                    const DataColumn(label: Text('المهندس')),
                    const DataColumn(label: Text('المشروع')),
                    const DataColumn(label: Text('مكان العمل')),
                    const DataColumn(label: Text('المراحل')),
                    const DataColumn(label: Text('المقاول')),
                    const DataColumn(label: Text('عدد العمال')),
                    const DataColumn(label: Text('سحب الخامات')),
                    const DataColumn(label: Text('ملخص الأعمال اليوم')),
                    const DataColumn(label: Text('بيان الصرف')),
                    const DataColumn(label: Text('قيمة المبلغ المنصرف')),
                    const DataColumn(label: Text('التاريخ')),
                  ],
                  rows: _rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            if (_canDeleteDetailedReports)
                              DataCell(
                                r.showDeleteReportAction && r.detailedReportId != null
                                    ? IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                                        tooltip: 'حذف التقرير المفصّل',
                                        onPressed: () => _deleteDetailedReport(r.detailedReportId),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            DataCell(SizedBox(width: 100, child: Text(r.engineerName, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 120, child: Text(r.projectName, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 140, child: Text(r.locationName, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 170, child: Text(r.phasesText, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 100, child: Text(r.contractorName, overflow: TextOverflow.ellipsis))),
                            DataCell(Text(r.workersText)),
                            DataCell(SizedBox(width: 280, child: Text(r.materialsText, maxLines: 8, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 260, child: Text(r.summaryText, maxLines: 8, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 180, child: Text(r.expenseDescriptionText, maxLines: 8, overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 140, child: Text(r.expenseAmountText, maxLines: 8, overflow: TextOverflow.ellipsis))),
                            DataCell(Text(DateFormat('yyyy/MM/dd', 'ar').format(r.reportDate))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('تصدير PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
