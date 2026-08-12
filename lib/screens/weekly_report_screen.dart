import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/attendance_record_model.dart';
import '../models/detailed_report_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/pdf_share.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _dayKey(DateTime d) {
  final x = _dateOnly(d);
  return '${x.year.toString().padLeft(4, '0')}-'
      '${x.month.toString().padLeft(2, '0')}-'
      '${x.day.toString().padLeft(2, '0')}';
}

/// بداية أسبوع العمل (السبت) للأسبوع الذي يقع فيه [day].
DateTime saturdayOfWorkWeek(DateTime day) {
  final d = _dateOnly(day);
  final daysFromSaturday = (d.weekday + 1) % 7;
  return d.subtract(Duration(days: daysFromSaturday));
}

/// نهاية أسبوع العمل (الخميس) للأسبوع الذي يقع فيه [day].
DateTime thursdayOfWorkWeek(DateTime day) =>
    saturdayOfWorkWeek(day).add(const Duration(days: 5));

const _weeklyReportPdfHeaders = <String>[
  'اليوم/التاريخ',
  'الاسم',
  'الحضور',
  'الانصراف',
  'خطة عمل اليوم',
  'خطة عمل الغد',
];

const _weeklyReportPdfColumnWidths = <double>[1.6, 1.4, 1.3, 1.3, 1.0, 1.0];

const _arabicWeekdayNames = <int, String>{
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
};

String _formatDayDateLabel(DateTime d) {
  final dayName = _arabicWeekdayNames[d.weekday] ?? '';
  final ymd =
      '${d.year.toString().padLeft(4, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}';
  return '$dayName $ymd';
}

/// null في حقول الحالة = يوم مستقبلي (بعد اليوم الحالي) → يُعرض « - » بدل ✓/✗
class _WeeklyReportRow {
  final DateTime day;
  final String dayLabel;
  final String name;
  final bool isFutureDay;
  final bool? hasCheckIn;
  final String checkInNotes;
  final bool? hasCheckOut;
  final String checkOutNotes;
  final bool? hasTodayPlan;
  final bool? hasTomorrowPlan;

  const _WeeklyReportRow({
    required this.day,
    required this.dayLabel,
    required this.name,
    required this.isFutureDay,
    required this.hasCheckIn,
    required this.checkInNotes,
    required this.hasCheckOut,
    required this.checkOutNotes,
    required this.hasTodayPlan,
    required this.hasTomorrowPlan,
  });
}

bool _isExcludedWeeklyReportEngineer(UserModel u) {
  final name = u.name.trim().toLowerCase();
  return name == 'test site engineer' || name == 'mansur';
}

/// التقرير الأسبوعي — لمسؤول التطبيق ومدير المشروعات ومدير العمليات.
class WeeklyReportScreen extends StatefulWidget {
  final UserModel? currentUser;

  const WeeklyReportScreen({super.key, this.currentUser});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  final _db = getStorage();

  late DateTime _dateFrom;
  late DateTime _dateTo;
  ProjectModel? _selectedProject;
  UserModel? _selectedEngineer;

  List<ProjectModel> _projects = [];
  List<UserModel> _engineers = [];

  List<_WeeklyReportRow> _rows = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateFrom = saturdayOfWorkWeek(now);
    _dateTo = thursdayOfWorkWeek(now);
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final projects = await _db.getProjects();
      final siteEngineers = await _db.getSiteEngineers();
      final allUsers = await _db.getUsers();
      final supervisors = allUsers
          .where((u) => u.role == 'general_supervisor')
          .toList();

      final byId = <int, UserModel>{};
      for (final u in [...siteEngineers, ...supervisors]) {
        if (_isExcludedWeeklyReportEngineer(u)) continue;
        byId[u.id] = u;
      }
      final engineers = byId.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        _projects = projects;
        _engineers = engineers;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل الفلاتر: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateFrom = _dateOnly(picked);
      if (_dateTo.isBefore(_dateFrom)) _dateTo = _dateFrom;
    });
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateTo = _dateOnly(picked);
      if (_dateTo.isBefore(_dateFrom)) _dateFrom = _dateTo;
    });
  }

  void _resetDefaultWeek() {
    final now = DateTime.now();
    setState(() {
      _dateFrom = saturdayOfWorkWeek(now);
      _dateTo = thursdayOfWorkWeek(now);
    });
  }

  bool _matchesProject(AttendanceRecordModel r) {
    final pid = _selectedProject?.id;
    if (pid == null) return true;
    return r.projectId == pid;
  }

  bool _matchesPlanProject(DetailedReportModel r) {
    final pid = _selectedProject?.id;
    if (pid == null) return true;
    return r.projectId == pid;
  }

  String _joinNotes(Iterable<String?> notes) {
    final parts = <String>[];
    for (final n in notes) {
      final t = n?.trim();
      if (t != null && t.isNotEmpty && !parts.contains(t)) {
        parts.add(t);
      }
    }
    return parts.join('\n');
  }

  Future<void> _runReport() async {
    if (_dateFrom.isAfter(_dateTo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('من تاريخ يجب أن يكون قبل إلى تاريخ')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    try {
      final people = _selectedEngineer != null
          ? [_selectedEngineer!]
          : List<UserModel>.from(_engineers);

      if (people.isEmpty) {
        if (!mounted) return;
        setState(() {
          _rows = [];
          _loading = false;
        });
        return;
      }

      final attendance = await _db.getAllAttendanceRecords();
      // نحمّل خطط حتى تاريخ النهاية + يوم إضافي لعمود «خطة عمل الغد».
      final plans = await _db.getDetailedReports(
        dateFrom: _dateFrom,
        dateTo: _dateTo.add(const Duration(days: 1)),
        userId: _selectedEngineer?.id,
        projectId: _selectedProject?.id,
      );

      final checkInByUserDay = <String, List<AttendanceRecordModel>>{};
      final checkOutByUserDay = <String, List<AttendanceRecordModel>>{};
      for (final r in attendance) {
        if (!_matchesProject(r)) continue;
        final key = '${r.userId}|${_dayKey(r.dateTime)}';
        if (r.isCheckIn) {
          (checkInByUserDay[key] ??= []).add(r);
        } else if (r.isCheckOut) {
          (checkOutByUserDay[key] ??= []).add(r);
        }
      }

      final planKeys = <String>{};
      for (final p in plans) {
        if (!_matchesPlanProject(p)) continue;
        planKeys.add('${p.userId}|${_dayKey(p.reportDatetime)}');
      }

      final today = _dateOnly(DateTime.now());
      final rows = <_WeeklyReportRow>[];
      for (var d = _dateFrom;
          !d.isAfter(_dateTo);
          d = d.add(const Duration(days: 1))) {
        final dayLabel = _formatDayDateLabel(d);
        final dayK = _dayKey(d);
        final tomorrowK = _dayKey(d.add(const Duration(days: 1)));
        final isFutureDay = d.isAfter(today);

        for (final person in people) {
          if (isFutureDay) {
            rows.add(
              _WeeklyReportRow(
                day: d,
                dayLabel: dayLabel,
                name: person.name,
                isFutureDay: true,
                hasCheckIn: null,
                checkInNotes: '',
                hasCheckOut: null,
                checkOutNotes: '',
                hasTodayPlan: null,
                hasTomorrowPlan: null,
              ),
            );
            continue;
          }

          final attKey = '${person.id}|$dayK';
          final checkIns = checkInByUserDay[attKey] ?? const [];
          final checkOuts = checkOutByUserDay[attKey] ?? const [];
          rows.add(
            _WeeklyReportRow(
              day: d,
              dayLabel: dayLabel,
              name: person.name,
              isFutureDay: false,
              hasCheckIn: checkIns.isNotEmpty,
              checkInNotes: _joinNotes(checkIns.map((e) => e.notes)),
              hasCheckOut: checkOuts.isNotEmpty,
              checkOutNotes: _joinNotes(checkOuts.map((e) => e.notes)),
              hasTodayPlan: planKeys.contains('${person.id}|$dayK'),
              hasTomorrowPlan: planKeys.contains('${person.id}|$tomorrowK'),
            ),
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل التقرير: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _statusCell({
    required bool? ok,
    String notes = '',
  }) {
    if (ok == null) {
      return Text(
        ' - ',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green.shade700 : Colors.red.shade700,
          size: 22,
        ),
        if (notes.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            notes,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
          ),
        ],
      ],
    );
  }

  static const _pdfStatusIconSize = 14.0;

  pw.Widget _pdfStatusIcon(bool ok) {
    final color = ok ? PdfColors.green700 : PdfColors.red700;
    const size = _pdfStatusIconSize;
    return pw.SizedBox(
      width: size,
      height: size,
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Container(
            width: size,
            height: size,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.CustomPaint(
            size: PdfPoint(size, size),
            painter: (canvas, s) {
              canvas
                ..setStrokeColor(PdfColors.white)
                ..setLineWidth(1.4);
              if (ok) {
                canvas
                  ..moveTo(s.x * 0.22, s.y * 0.48)
                  ..lineTo(s.x * 0.42, s.y * 0.28)
                  ..lineTo(s.x * 0.78, s.y * 0.72)
                  ..strokePath();
              } else {
                canvas
                  ..moveTo(s.x * 0.28, s.y * 0.28)
                  ..lineTo(s.x * 0.72, s.y * 0.72)
                  ..moveTo(s.x * 0.72, s.y * 0.28)
                  ..lineTo(s.x * 0.28, s.y * 0.72)
                  ..strokePath();
              }
            },
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfStatusCell({
    required bool? ok,
    String notes = '',
    required pw.Font font,
  }) {
    if (ok == null) {
      return pw.Text(
        ' - ',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: font,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
      );
    }
    final noteText = notes.trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _pdfStatusIcon(ok),
        if (noteText.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              noteText,
              textAlign: pw.TextAlign.center,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey800),
            ),
          ),
      ],
    );
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

    final engineerLabel =
        _selectedEngineer == null ? 'الجميع' : _selectedEngineer!.name;
    final projectLabel =
        _selectedProject == null ? 'جميع المشاريع' : _selectedProject!.name;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (logoImage != null)
                pw.Center(
                  child: pw.Container(
                    height: 48,
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green800),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'التقرير الأسبوعي | Weekly Report',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'من ${dateFormat.format(_dateFrom)} إلى ${dateFormat.format(_dateTo)}'
                '  |  المهندس: $engineerLabel  |  المشروع: $projectLabel',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: {
                for (var i = 0; i < _weeklyReportPdfColumnWidths.length; i++)
                  i: pw.FlexColumnWidth(
                    _weeklyReportPdfColumnWidths.reversed.elementAt(i),
                  ),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green50),
                  children: [
                    for (final h in _weeklyReportPdfHeaders.reversed)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          h,
                          textAlign: pw.TextAlign.center,
                          textDirection: pw.TextDirection.rtl,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900,
                          ),
                        ),
                      ),
                  ],
                ),
                ..._rows.map(
                  (r) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: _pdfStatusCell(
                          ok: r.hasTomorrowPlan,
                          font: fontBase,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: _pdfStatusCell(ok: r.hasTodayPlan, font: fontBase),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: _pdfStatusCell(
                          ok: r.hasCheckOut,
                          notes: r.checkOutNotes,
                          font: fontBase,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: _pdfStatusCell(
                          ok: r.hasCheckIn,
                          notes: r.checkInNotes,
                          font: fontBase,
                        ),
                      ),
                      _pdfTextCell(r.name, fontBase),
                      _pdfTextCell(r.dayLabel, fontBase),
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
    final fileName =
        'weekly_report_${dateFormat.format(_dateFrom)}_${dateFormat.format(_dateTo)}.pdf'
            .replaceAll('/', '-');
    await sharePdfBytes(bytes, fileName);
  }

  pw.Widget _pdfTextCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(font: font, fontSize: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('yyyy/MM/dd', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير الأسبوعي'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (_hasSearched && _rows.isNotEmpty)
            IconButton(
              tooltip: 'تصدير PDF',
              onPressed: _loading ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text('من', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pickDateFrom,
                          child: Text(dateFmt.format(_dateFrom)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('إلى', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pickDateTo,
                          child: Text(dateFmt.format(_dateTo)),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _resetDefaultWeek,
                      child: const Text('إعادة المدة الافتراضية (سبت–خميس)'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<UserModel?>(
                    value: _selectedEngineer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم المهندس',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<UserModel?>(
                        value: null,
                        child: Text('الجميع'),
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
                  DropdownButtonFormField<ProjectModel?>(
                    value: _selectedProject,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم المشروع',
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
          Expanded(flex: 7, child: _buildTableArea()),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B5E20),
        ),
      ),
    );
  }

  Widget _tableTextCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _tableStatusCell({required bool? ok, String notes = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Center(child: _statusCell(ok: ok, notes: notes)),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          'لا توجد بيانات ضمن الفلاتر المحددة',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: constraints.maxWidth - 24,
              child: Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: FlexColumnWidth(1.6),
                  1: FlexColumnWidth(1.4),
                  2: FlexColumnWidth(1.0),
                  3: FlexColumnWidth(1.0),
                  4: FlexColumnWidth(1.0),
                  5: FlexColumnWidth(1.0),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                    ),
                    children: [
                      _tableHeaderCell('اليوم/التاريخ'),
                      _tableHeaderCell('الاسم'),
                      _tableHeaderCell('الحضور'),
                      _tableHeaderCell('الانصراف'),
                      _tableHeaderCell('خطة عمل اليوم'),
                      _tableHeaderCell('خطة عمل الغد'),
                    ],
                  ),
                  ..._rows.map(
                    (r) => TableRow(
                      children: [
                        _tableTextCell(r.dayLabel),
                        _tableTextCell(r.name),
                        _tableStatusCell(
                          ok: r.hasCheckIn,
                          notes: r.checkInNotes,
                        ),
                        _tableStatusCell(
                          ok: r.hasCheckOut,
                          notes: r.checkOutNotes,
                        ),
                        _tableStatusCell(ok: r.hasTodayPlan),
                        _tableStatusCell(ok: r.hasTomorrowPlan),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
