import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/worker_hours_calc.dart';

const TextStyle _kWorkerHoursTableCellStyle = TextStyle(
  fontSize: 13,
  height: 1.5,
);

const double _kWorkerHoursPdfLineSpacing = 4.0;

/// تقرير ساعات العمل: مدة + مستخدمون (مهندس موقع / مشرف عام) → ساعات يومية وإجمالي.
class WorkerHoursReportScreen extends StatefulWidget {
  final UserModel admin;

  const WorkerHoursReportScreen({super.key, required this.admin});

  @override
  State<WorkerHoursReportScreen> createState() =>
      _WorkerHoursReportScreenState();
}

class _WorkerHoursReportScreenState extends State<WorkerHoursReportScreen> {
  final _db = getStorage();

  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<UserModel> _attendanceUsers = [];
  Set<int> _selectedUserIds = {};
  List<WorkerHoursReportRow> _rows = [];
  bool _loading = false;
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _dateFrom = today;
    _dateTo = today;
    _loadUsers();
  }

  Future<List<UserModel>> _fetchAttendanceUsers() async {
    List<UserModel> engineers;
    List<UserModel> supervisors;
    if (_db is ApiStorageService) {
      engineers = await _db.getSiteEngineers();
      final all = await _db.getUsers(requesterEmail: widget.admin.email);
      supervisors = all.where((u) => u.isGeneralSupervisor).toList();
    } else {
      engineers = await _db.getSiteEngineers();
      final all = await _db.getUsers();
      supervisors = all.where((u) => u.isGeneralSupervisor).toList();
    }
    final byId = <int, UserModel>{for (final u in engineers) u.id: u};
    for (final u in supervisors) {
      byId[u.id] = u;
    }
    return byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final filtered = await _fetchAttendanceUsers();
      if (!mounted) return;
      setState(() {
        _attendanceUsers = filtered;
        _selectedUserIds = filtered.map((u) => u.id).toSet();
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingUsers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل المستخدمين: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool get _allUsersSelected =>
      _attendanceUsers.isNotEmpty &&
      _selectedUserIds.length == _attendanceUsers.length;

  String get _usersSelectionLabel {
    if (_attendanceUsers.isEmpty) return 'لا يوجد مستخدمون';
    if (_allUsersSelected) return 'الجميع (${_attendanceUsers.length})';
    if (_selectedUserIds.isEmpty) return 'لم يُختر أحد';
    if (_selectedUserIds.length == 1) {
      final id = _selectedUserIds.single;
      return _attendanceUsers.firstWhere((u) => u.id == id).name;
    }
    return '${_selectedUserIds.length} مستخدمين';
  }

  Future<void> _pickUsers() async {
    if (_attendanceUsers.isEmpty) return;
    final temp = Set<int>.from(_selectedUserIds);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('اختيار المستخدمين'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text(
                        'الجميع',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: temp.length == _attendanceUsers.length,
                      tristate: temp.isNotEmpty &&
                          temp.length < _attendanceUsers.length,
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            temp
                              ..clear()
                              ..addAll(_attendanceUsers.map((u) => u.id));
                          } else {
                            temp.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ..._attendanceUsers.map(
                      (user) => CheckboxListTile(
                        title: Text(user.name),
                        subtitle: Text(
                          user.role == 'general_supervisor'
                              ? UserModel.generalSupervisorRoleLabel
                              : 'مهندس موقع',
                        ),
                        value: temp.contains(user.id),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              temp.add(user.id);
                            } else {
                              temp.remove(user.id);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, temp),
                  child: const Text('تطبيق'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _selectedUserIds = result);
  }

  Future<void> _run() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر مستخدماً واحداً على الأقل'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final allRecords = await _db.getAllAttendanceRecords();
      final selectedUsers = _attendanceUsers
          .where((u) => _selectedUserIds.contains(u.id))
          .map((u) => (id: u.id, name: u.name));
      final rows = buildWorkerHoursReport(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        allRecords: allRecords,
        users: selectedUsers,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportPdf() async {
    if (_rows.isEmpty) return;
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
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        build: (ctx) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
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
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.green800),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'تقرير ساعات العمال | Worker Hours Report',
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(1.1),
              2: const pw.FlexColumnWidth(2.4),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(2.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfCell('المدة الزمنية', true),
                  _pdfCell('اسم المستخدم', true),
                  _pdfCell('ساعات العمل', true),
                  _pdfCell('إجمالي الساعات', true),
                  _pdfCell('الملاحظات', true),
                ],
              ),
              ..._rows.map(
                (row) => pw.TableRow(
                  children: [
                    _pdfCell(
                      formatWorkerHoursPeriodLabel(row.dateFrom, row.dateTo),
                      false,
                    ),
                    _pdfCell(row.userName, false),
                    _pdfCell(_breakdownForRow(row), false),
                    _pdfCell(
                      formatWorkerHoursDuration(row.totalDuration),
                      false,
                    ),
                    _pdfCell(formatWorkerHoursNotes(row.notes), false),
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
    final range = DateFormat('yyyy-MM-dd', 'ar');
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'تقرير_ساعات_العمال_${range.format(_dateFrom)}_${range.format(_dateTo)}.pdf',
    );
  }

  pw.Widget _pdfCell(String text, bool isHeader) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Paragraph(
            text: text.trim().isEmpty ? '—' : text,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: isHeader ? 9.5 : 8.5,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? PdfColors.green900 : PdfColors.black,
              lineSpacing: _kWorkerHoursPdfLineSpacing,
            ),
          ),
        ),
      );

  Widget _tableCell(String text, {required double width}) {
    final display = text.trim().isEmpty ? '—' : text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: SizedBox(
        width: width,
        child: Text(
          display,
          softWrap: true,
          style: _kWorkerHoursTableCellStyle,
        ),
      ),
    );
  }

  String _breakdownForRow(WorkerHoursReportRow row) {
    final active = row.activeDays;
    if (active.isEmpty) return '0:00';
    return formatWorkerHoursBreakdown(active.map((d) => d.duration));
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
      _dateFrom = dateOnly(picked);
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
      _dateTo = dateOnly(picked);
      if (_dateFrom.isAfter(_dateTo)) _dateFrom = _dateTo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: const Text('ساعات العمال'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('من تاريخ'),
            subtitle: Text(dateFormat.format(_dateFrom)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDateFrom,
          ),
          ListTile(
            title: const Text('إلى تاريخ'),
            subtitle: Text(dateFormat.format(_dateTo)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDateTo,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('المستخدمون'),
            subtitle: Text(_usersSelectionLabel),
            trailing: _loadingUsers
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.people),
            onTap: _loadingUsers ? null : _pickUsers,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search),
            label: const Text('عرض التقرير'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
            ),
          ),
          if (_rows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'النتائج (${_rows.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFE8F5E9),
                  ),
                  border: TableBorder.all(
                    color: Colors.grey.shade400,
                    width: 0.8,
                  ),
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  headingRowHeight: 56,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: double.infinity,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'المدة الزمنية',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'اسم المستخدم',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'ساعات العمل',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'إجمالي الساعات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'الملاحظات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _rows
                      .map(
                        (row) => DataRow(
                          cells: [
                            DataCell(
                              _tableCell(
                                formatWorkerHoursPeriodLabel(
                                  row.dateFrom,
                                  row.dateTo,
                                ),
                                width: 140,
                              ),
                            ),
                            DataCell(
                              _tableCell(row.userName, width: 120),
                            ),
                            DataCell(
                              _tableCell(
                                _breakdownForRow(row),
                                width: 300,
                              ),
                            ),
                            DataCell(
                              _tableCell(
                                formatWorkerHoursDuration(row.totalDuration),
                                width: 100,
                              ),
                            ),
                            DataCell(
                              _tableCell(
                                formatWorkerHoursNotes(row.notes),
                                width: 340,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير PDF'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
