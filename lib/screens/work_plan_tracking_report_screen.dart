import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/contractor_model.dart';
import '../models/detailed_report_model.dart';
import '../models/location_withdrawal_for_period_model.dart';
import '../models/project_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/pdf_share.dart';

/// مكان العمل: الأب ثم الفرع بين أقواس (مثل التقرير المجمع).
String _formatLocationHierarchy(
  ProjectLocationModel loc,
  Map<int, ProjectLocationModel> byId,
) {
  final parent = loc.parentId != null ? byId[loc.parentId!] : null;
  if (parent != null) {
    return '${parent.name} (${loc.name})';
  }
  return loc.name;
}

String _fmtYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String _fmtDateFromString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return _fmtYmd(DateTime(parsed.year, parsed.month, parsed.day));
}

/// كل سحوبات المهندس للمشروع في **نفس يوم الخطة** (أي موقع فرعي)، لأن السحب قد يكون من موقع مختلف عن مكان عمل الخطة.
String _withdrawalsForUserProjectDay({
  required int? projectId,
  required int reportUserId,
  required String engineerName,
  required DateTime reportDate,
  required List<LocationWithdrawalForPeriodModel> withdrawals,
  required Map<int, ProjectLocationModel> locationById,
  required String Function(DateTime) dayKey,
}) {
  if (projectId == null) return '—';
  final dk = dayKey(reportDate);
  bool sameUser(LocationWithdrawalForPeriodModel w) =>
      w.userId == reportUserId ||
      w.userName.trim() == engineerName.trim();
  final relevant = <LocationWithdrawalForPeriodModel>[];
  for (final w in withdrawals) {
    if (w.projectId == projectId &&
        dayKey(w.createdAt) == dk &&
        sameUser(w)) {
      relevant.add(w);
    }
  }
  if (relevant.isEmpty) return '—';
  relevant.sort((a, b) => a.locationId.compareTo(b.locationId));
  final dateFmt = DateFormat('yyyy/MM/dd HH:mm');
  final planDay = dateFmt.format(reportDate.toLocal()).split(' ').first;
  final lines = <String>[];
  for (final w in relevant) {
    final wLoc = locationById[w.locationId];
    final locLabel = wLoc != null
        ? _formatLocationHierarchy(wLoc, locationById)
        : 'موقع #${w.locationId}';
    final parts = <String>[];
    for (final m in w.materials) {
      final u = m.unit.trim().isEmpty ? '' : ' ${m.unit}';
      final line = '${m.materialName} ${m.quantity}$u'.trim();
      if (line.isNotEmpty) parts.add(line);
    }
    final mat = parts.isEmpty ? '—' : parts.join('؛ ');
    final withdrawnAt = dateFmt.format(w.createdAt.toLocal());
    lines.add(
      'الموقع: $locLabel — تاريخ تنفيذ الخطة: $planDay — تاريخ السحب: $withdrawnAt — الخامات: $mat',
    );
  }
  return lines.join('\n');
}

Future<Map<int, Map<String, String?>>> _loadPlanExecutionStatusesApi(
  List<DetailedReportModel> reports,
  ApiStorageService api,
) async {
  final out = <int, Map<String, String?>>{};
  for (final r in reports) {
    if (r.id == null) continue;
    final id = r.id!;
    if (out.containsKey(id)) continue;
    try {
      final latest = await api.getLatestExecutedPlanStatus(
        sourcePlanId: id,
        userId: r.userId,
      );
      final status = latest?['status']?.toString();
      String? postponeText;
      if (status == 'postponed') {
        final reasonLabel = latest?['postpone_reason_label']?.toString();
        final reasonCustom = latest?['postpone_custom_reason']?.toString();
        final reasonNotes = latest?['postpone_notes']?.toString();
        final reopenDate = latest?['postpone_reopen_date']?.toString();
        postponeText =
            (reasonCustom != null && reasonCustom.trim().isNotEmpty)
                ? 'سبب التأجيل: ${reasonCustom.trim()}'
                : 'سبب التأجيل: ${reasonLabel ?? 'غير محدد'}';
        if (reopenDate != null && reopenDate.trim().isNotEmpty) {
          postponeText =
              '$postponeText\nمؤجل إلى تاريخ: ${_fmtDateFromString(reopenDate)}';
        }
        if (reasonNotes != null && reasonNotes.trim().isNotEmpty) {
          postponeText = '$postponeText\nملاحظات: ${reasonNotes.trim()}';
        }
      }
      out[id] = {
        'status': status,
        'modificationSummary': latest?['modification_summary']?.toString(),
        'postponedReasonText': postponeText,
      };
    } catch (_) {
      out[id] = {};
    }
  }
  return out;
}

String _formatExecutionStatusDisplay(Map<String, String?>? d, bool apiMode) {
  if (d == null || d.isEmpty) {
    return apiMode ? 'بانتظار الإجراء' : 'بانتظار الإجراء (يتطلب خادماً لحالة التنفيذ)';
  }
  final status = d['status']?.trim();
  if (status == null || status.isEmpty) {
    return apiMode ? 'بانتظار الإجراء' : 'بانتظار الإجراء (يتطلب خادماً لحالة التنفيذ)';
  }
  switch (status) {
    case 'confirmed':
      return 'تنفيذ';
    case 'confirmed_edited':
      final m = d['modificationSummary']?.trim();
      if (m != null && m.isNotEmpty) return 'تعديل + تنفيذ — $m';
      return 'تعديل + تنفيذ';
    case 'postponed':
      final t = d['postponedReasonText']?.trim();
      if (t != null && t.isNotEmpty) return 'تأجيل — $t';
      return 'تأجيل';
    default:
      return status;
  }
}

class _PlanTrackingRow {
  final int reportId;
  final String engineerName;
  final String projectName;
  /// تاريخ تنفيذ الخطة (اليوم المعروض في التقرير)
  final String planDateLabel;
  final String workplaceLevel1;
  final String planDetails;
  final String materialsWithdrawn;
  /// خطة اليوم فقط؛ عند خطة الغد يُترك «—»
  final String executionStatus;
  final String contractorName;

  _PlanTrackingRow({
    required this.reportId,
    required this.engineerName,
    required this.projectName,
    required this.planDateLabel,
    required this.workplaceLevel1,
    required this.planDetails,
    required this.materialsWithdrawn,
    required this.executionStatus,
    required this.contractorName,
  });
}

/// تقارير متابعة خطط اليوم/الغد — شكل مبدئي مطابق للنموذج (جدول + فلاتر).
class WorkPlanTrackingReportScreen extends StatefulWidget {
  final UserModel currentUser;

  const WorkPlanTrackingReportScreen({super.key, required this.currentUser});

  @override
  State<WorkPlanTrackingReportScreen> createState() =>
      _WorkPlanTrackingReportScreenState();
}

class _WorkPlanTrackingReportScreenState
    extends State<WorkPlanTrackingReportScreen> {
  final _db = getStorage();

  List<ProjectModel> _projects = [];
  List<UserModel> _engineers = [];

  /// مقاولون للقائمة المنسدلة (بدون «لايوجد/ذاتي»)
  List<ContractorModel> _contractors = [];
  Map<int, ContractorModel> _contractorById = {};

  /// false = خطة اليوم، true = خطة الغد
  bool _tomorrowPlan = false;
  late DateTime _dateFrom;
  late DateTime _dateTo;
  ProjectModel? _selectedProject;
  UserModel? _selectedEngineer;
  ContractorModel? _selectedContractor;

  List<_PlanTrackingRow> _rows = [];
  bool _loading = false;
  bool _hasSearched = false;

  /// يظهر عمود الخامات فقط إن وُجدت سحوبات في الفترة المفلترة
  bool _showMaterialsColumn = false;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dayKey(DateTime t) {
    final l = t.toLocal();
    return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final t = _dateOnly(DateTime.now());
    _dateFrom = t;
    _dateTo = t;
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final projects = await _db.getProjects();
      final engineers = await _db.getSiteEngineers();
      final contractors = await _db.getContractors();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _engineers = engineers;
        _contractorById = {for (final c in contractors) c.id: c};
        _contractors = contractors.where((c) {
          final n = c.name.trim().toLowerCase();
          return n != 'لايوجد مقاول' && n != 'ذاتي';
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _pickDateFrom() async {
    final t = _dateOnly(DateTime.now());
    final first = t.subtract(const Duration(days: 30));
    final last = t.add(const Duration(days: 90));
    var initial = _dateFrom;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateFrom = _dateOnly(picked);
      if (_dateTo.isBefore(_dateFrom)) _dateTo = _dateFrom;
    });
  }

  Future<void> _pickDateTo() async {
    final t = _dateOnly(DateTime.now());
    final first = t.subtract(const Duration(days: 30));
    final last = t.add(const Duration(days: 90));
    var initial = _dateTo;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateTo = _dateOnly(picked);
      if (_dateTo.isBefore(_dateFrom)) _dateFrom = _dateTo;
    });
  }

  Future<void> _runReport() async {
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final dayStart = _dateFrom;
      final dayEnd = DateTime(
        _dateTo.year,
        _dateTo.month,
        _dateTo.day,
        23,
        59,
        59,
        999,
      );
      final reports = await _db.getDetailedReports(
        dateFrom: dayStart,
        dateTo: dayEnd,
        userId: _selectedEngineer?.id,
        projectId: _selectedProject?.id,
      );
      final contractorById = _contractorById;
      final projectById = {for (final p in _projects) p.id: p};

      final withdrawals = await _db.getLocationWithdrawalsForPeriod(
        dateFrom: dayStart,
        dateTo: dayEnd,
        projectId: _selectedProject?.id,
      );
      final showMaterials = withdrawals.isNotEmpty;
      final db = _db;
      final apiMode = db is ApiStorageService;
      Map<int, Map<String, String?>> planStatuses = {};
      if (!_tomorrowPlan && apiMode) {
        planStatuses = await _loadPlanExecutionStatusesApi(
          reports,
          db,
        );
      }

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
        return r.projectName?.trim().isNotEmpty == true
            ? r.projectName!.trim()
            : '—';
      }

      final matByPlanKey = <String, String>{};
      String withdrawalCacheKey(DetailedReportModel r) =>
          '${r.id}_${_dayKey(r.reportDatetime)}_${r.projectId}_${r.userId}';

      String materialsForReport(DetailedReportModel report) {
        if (!showMaterials) return '';
        return matByPlanKey.putIfAbsent(
          withdrawalCacheKey(report),
          () => _withdrawalsForUserProjectDay(
            projectId: report.projectId,
            reportUserId: report.userId,
            engineerName: report.userName,
            reportDate: report.reportDatetime,
            withdrawals: withdrawals,
            locationById: locationById,
            dayKey: _dayKey,
          ),
        );
      }

      String executionForReport(DetailedReportModel report) {
        if (_tomorrowPlan) return '—';
        return _formatExecutionStatusDisplay(
          report.id != null ? planStatuses[report.id!] : null,
          apiMode,
        );
      }

      final planDateFmt = DateFormat('yyyy/MM/dd', 'ar');
      final out = <_PlanTrackingRow>[];
      for (final report in reports) {
        if (report.id == null) continue;
        final proj = projectLabel(report);
        final summaryText = (report.summary ?? '').trim().isEmpty
            ? '—'
            : report.summary!.trim();
        final planDateLabel =
            planDateFmt.format(report.reportDatetime.toLocal());

        if (report.lines.isEmpty) {
          if (report.id == null) continue;
          out.add(
            _PlanTrackingRow(
              reportId: report.id!,
              engineerName: report.userName,
              projectName: proj,
              planDateLabel: planDateLabel,
              workplaceLevel1: '—',
              planDetails: summaryText,
              materialsWithdrawn: materialsForReport(report),
              executionStatus: executionForReport(report),
              contractorName: '—',
            ),
          );
          continue;
        }

        final grouped = <String, List<DetailedReportLineModel>>{};
        for (final line in report.lines) {
          final key = '${line.contractorId ?? 0}_${line.locationId ?? 0}';
          grouped.putIfAbsent(key, () => <DetailedReportLineModel>[]).add(line);
        }
        final hasMeaningfulGroup = grouped.values.any((lines) {
          final firstLine = lines.first;
          return firstLine.contractorId != null || firstLine.locationId != null;
        });

        for (final g in grouped.values) {
          final first = g.first;
          // تجاهل الصفوف الفارغة (بدون مقاول وبدون موقع) إذا كانت هناك صفوف فعلية لنفس الخطة.
          if (hasMeaningfulGroup &&
              first.contractorId == null &&
              first.locationId == null) {
            continue;
          }
          final cname = first.contractorId == null
              ? '—'
              : (contractorById[first.contractorId!]?.name ?? '—');
          if (_selectedContractor != null &&
              first.contractorId != _selectedContractor!.id) {
            continue;
          }

          String locDisplay = '—';
          if (first.locationId != null) {
            final loc = locationById[first.locationId!];
            if (loc != null) {
              locDisplay = _formatLocationHierarchy(loc, locationById);
            }
          }

          out.add(
            _PlanTrackingRow(
              reportId: report.id!,
              engineerName: report.userName,
              projectName: proj,
              planDateLabel: planDateLabel,
              workplaceLevel1: locDisplay,
              planDetails: summaryText,
              materialsWithdrawn: materialsForReport(report),
              executionStatus: executionForReport(report),
              contractorName: cname,
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = out;
        _showMaterialsColumn = showMaterials;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _showMaterialsColumn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePlanFromTracking(_PlanTrackingRow row) async {
    if (!widget.currentUser.canManageAnySiteWorkPlan) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الخطة'),
        content: Text(
          'سيتم حذف هذه الخطة نهائياً.\n\n'
          'المهندس: ${row.engineerName}\n'
          'المشروع: ${row.projectName}\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.deleteDetailedReport(row.reportId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الخطة'),
          backgroundColor: Colors.green,
        ),
      );
      await _runReport();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر حذف الخطة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات لتصديرها')),
      );
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

    final rangeLabel = DateFormat('yyyy-MM-dd', 'ar');
    final planKind = _tomorrowPlan ? 'خطة الغد' : 'خطة اليوم';
    final projectLine = _selectedProject == null
        ? 'جميع المشاريع'
        : _selectedProject!.name;
    final engineerLine =
        _selectedEngineer == null ? 'جميع المهندسين' : _selectedEngineer!.name;
    final contractorLine = _selectedContractor == null
        ? 'جميع المقاولين'
        : _selectedContractor!.name;

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
                'تقارير متابعة خطة اليوم/الغد | Work Plan Tracking',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            '$planKind — من ${rangeLabel.format(_dateFrom)} إلى ${rangeLabel.format(_dateTo)}',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.Text(
            'المشروع: $projectLine — المهندس: $engineerLine — المقاول: $contractorLine',
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(width: 0.45, color: PdfColors.grey600),
            columnWidths: _pdfColumnWidths(
              showMaterials: _showMaterialsColumn,
              showExecution: !_tomorrowPlan,
            ),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: _pdfHeaderCells(
                  showMaterials: _showMaterialsColumn,
                  showExecution: !_tomorrowPlan,
                ),
              ),
              ..._rows.map(
                (r) => pw.TableRow(
                  children: _pdfDataCells(
                    r,
                    showMaterials: _showMaterialsColumn,
                    showExecution: !_tomorrowPlan,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    final slug = _tomorrowPlan ? 'غد' : 'اليوم';
    await sharePdfBytes(
      bytes,
      'تقرير_متابعة_خطة_${slug}_${rangeLabel.format(_dateFrom)}_${rangeLabel.format(_dateTo)}.pdf',
    );
  }

  pw.Widget _pdfCellHdr(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          t,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green900,
          ),
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

  Map<int, pw.TableColumnWidth> _pdfColumnWidths({
    required bool showMaterials,
    required bool showExecution,
  }) {
    final m = <int, pw.TableColumnWidth>{};
    var i = 0;
    void add(double f) => m[i++] = pw.FlexColumnWidth(f);
    add(1);
    add(1.1);
    add(0.75);
    add(1.15);
    add(1.6);
    if (showMaterials) add(2.0);
    if (showExecution) add(1.55);
    add(1);
    return m;
  }

  List<pw.Widget> _pdfHeaderCells({
    required bool showMaterials,
    required bool showExecution,
  }) {
    return [
      _pdfCellHdr('اسم المهندس'),
      _pdfCellHdr('اسم المشروع'),
      _pdfCellHdr('تاريخ الخطة'),
      _pdfCellHdr('مكان العمل — المستوى الأول'),
      _pdfCellHdr('تفاصيل خطة العمل'),
      if (showMaterials) _pdfCellHdr('الخامات المسحوبة — إن وجدت'),
      if (showExecution) _pdfCellHdr('حالة التنفيذ'),
      _pdfCellHdr('المقاول'),
    ];
  }

  List<pw.Widget> _pdfDataCells(
    _PlanTrackingRow r, {
    required bool showMaterials,
    required bool showExecution,
  }) {
    return [
      _pdfCellBody(r.engineerName),
      _pdfCellBody(r.projectName),
      _pdfCellBody(r.planDateLabel),
      _pdfCellBody(r.workplaceLevel1),
      _pdfCellBody(r.planDetails),
      if (showMaterials) _pdfCellBody(r.materialsWithdrawn),
      if (showExecution) _pdfCellBody(r.executionStatus),
      _pdfCellBody(r.contractorName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = _tomorrowPlan
        ? 'تقارير خطة عمل الغد'
        : 'تقارير خطة عمل اليوم';
    final dateFmt = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('تقارير متابعة خطط اليوم/الغد'),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (_hasSearched && _rows.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'تصدير PDF',
              onPressed: _loading ? null : _exportPdf,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نفس المنطقة (التقرير اليومي المجمع)',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('خطة اليوم'),
                        icon: Icon(Icons.today, size: 18),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('خطة الغد'),
                        icon: Icon(Icons.event, size: 18),
                      ),
                    ],
                    selected: {_tomorrowPlan},
                    onSelectionChanged: (s) {
                      setState(() {
                        _tomorrowPlan = s.first;
                        _rows = [];
                        _hasSearched = false;
                        _showMaterialsColumn = false;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'من تاريخ',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            dateFmt.format(_dateFrom),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _pickDateFrom,
                        child: const Text('تغيير'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'إلى تاريخ',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            dateFmt.format(_dateTo),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _pickDateTo,
                        child: const Text('تغيير'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ProjectModel?>(
                    value: _selectedProject,
                    decoration: const InputDecoration(
                      labelText: 'المشروع',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<ProjectModel?>(
                        value: null,
                        child: Text('جميع المشاريع'),
                      ),
                      ..._projects.map(
                        (p) => DropdownMenuItem<ProjectModel?>(
                          value: p,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedProject = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserModel?>(
                    value: _selectedEngineer,
                    decoration: const InputDecoration(
                      labelText: 'المهندس',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<UserModel?>(
                        value: null,
                        child: Text('جميع المهندسين'),
                      ),
                      ..._engineers.map(
                        (u) => DropdownMenuItem<UserModel?>(
                          value: u,
                          child: Text(u.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedEngineer = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ContractorModel?>(
                    value: _selectedContractor,
                    decoration: const InputDecoration(
                      labelText: 'المقاول',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<ContractorModel?>(
                        value: null,
                        child: Text('جميع المقاولين'),
                      ),
                      ..._contractors.map(
                        (c) => DropdownMenuItem<ContractorModel?>(
                          value: c,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedContractor = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loading ? null : _runReport,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.table_chart),
                    label: Text(_loading ? 'جاري التحميل...' : 'عرض التقرير'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (_hasSearched && _rows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _loading ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('تصدير PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(flex: 10, child: _buildTableArea()),
        ],
      ),
    );
  }

  Widget _buildTableArea() {
    if (!_hasSearched) {
      return Center(
        child: Text(
          'اضغط «عرض التقرير» بعد ضبط الفلاتر',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          'لا توجد صفوف تطابق الفلاتر لهذا التاريخ',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    final showExecCol = !_tomorrowPlan;
    final showMatCol = _showMaterialsColumn;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFE8F5E9)),
            border: TableBorder.all(color: Colors.grey.shade400, width: 0.8),
            columns: [
              DataColumn(
                label: Text(
                  'اسم المهندس',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'اسم المشروع',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'تاريخ الخطة',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'مكان العمل — المستوى الأول',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'تفاصيل خطة العمل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (showMatCol)
                DataColumn(
                  label: Text(
                    'الخامات المسحوبة — إن وجدت',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (showExecCol)
                DataColumn(
                  label: Text(
                    'حالة التنفيذ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              DataColumn(
                label: Text(
                  'المقاول',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.currentUser.canManageAnySiteWorkPlan)
                const DataColumn(
                  label: Text(
                    'إجراء',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
            rows: _rows
                .map(
                  (r) => DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: Text(r.engineerName, softWrap: true),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 120,
                          child: Text(r.projectName, softWrap: true),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 96,
                          child: Text(r.planDateLabel, softWrap: true),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Text(r.workplaceLevel1, softWrap: true),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Text(r.planDetails, softWrap: true),
                        ),
                      ),
                      if (showMatCol)
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Text(
                              r.materialsWithdrawn.isEmpty
                                  ? '—'
                                  : r.materialsWithdrawn,
                              softWrap: true,
                            ),
                          ),
                        ),
                      if (showExecCol)
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(r.executionStatus, softWrap: true),
                          ),
                        ),
                      DataCell(
                        SizedBox(
                          width: 110,
                          child: Text(r.contractorName, softWrap: true),
                        ),
                      ),
                      if (widget.currentUser.canManageAnySiteWorkPlan)
                        DataCell(
                          IconButton(
                            tooltip: 'حذف الخطة',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: _loading
                                ? null
                                : () => _deletePlanFromTracking(r),
                          ),
                        ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
