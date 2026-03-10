import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/attendance_record_model.dart';
import '../models/user_model.dart';
import '../utils/pdf_share.dart';
import '../services/storage_service.dart';

/// صلاحية التعديل والحذف لسجلات الحضور والانصراف: مسؤول التطبيق (mouhammedhelal@gmail.com) فقط
bool canEditDeleteAttendance(UserModel? user) =>
    user != null && user.role == 'app_admin' && user.email.trim().toLowerCase() == 'mouhammedhelal@gmail.com';

/// شاشة تقارير الحضور والانصراف - لمدير المهندسين (عرض؛ تعديل/حذف لمسؤول التطبيق فقط)
class AttendanceReportsScreen extends StatefulWidget {
  final UserModel? currentUser;

  const AttendanceReportsScreen({super.key, this.currentUser});

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  final _db = getStorage();
  List<AttendanceRecordModel> _records = [];
  bool _isLoading = true;
  DateTime? _reportDateFrom;
  DateTime? _reportDateTo;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final records = await _db.getAllAttendanceRecords();
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  List<AttendanceRecordModel> get _displayRecords {
    if (_reportDateFrom == null || _reportDateTo == null) return _records;
    final from = DateTime(_reportDateFrom!.year, _reportDateFrom!.month, _reportDateFrom!.day);
    final to = DateTime(_reportDateTo!.year, _reportDateTo!.month, _reportDateTo!.day, 23, 59, 59, 999);
    return _records.where((r) => !r.dateTime.isBefore(from) && !r.dateTime.isAfter(to)).toList();
  }

  void _showCreateReportDialog() {
    DateTime from = _reportDateFrom ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime to = _reportDateTo ?? DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إنشاء تقرير - تحديد المدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('من تاريخ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ListTile(
                  title: Text(DateFormat('yyyy/MM/dd', 'ar').format(from)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: from,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialog(() => from = picked);
                  },
                ),
                const SizedBox(height: 16),
                const Text('إلى تاريخ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ListTile(
                  title: Text(DateFormat('yyyy/MM/dd', 'ar').format(to)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: to,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialog(() => to = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (from.isAfter(to)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('من تاريخ يجب أن يكون قبل إلى تاريخ')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                setState(() {
                  _reportDateFrom = from;
                  _reportDateTo = to;
                });
              },
              child: const Text('عرض التقرير'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearReportRange() {
    setState(() {
      _reportDateFrom = null;
      _reportDateTo = null;
    });
  }

  Future<void> _deleteRecord(AttendanceRecordModel record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف سجل ${record.isCheckIn ? "حضور" : "انصراف"} لـ ${record.userName}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.deleteAttendanceRecord(record.id);
      _loadRecords();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف السجل'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportPdf() async {
    final toExport = _displayRecords;
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سجلات لتصديرها')),
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
    final dateFromStr = _reportDateFrom != null ? dateFormat.format(_reportDateFrom!) : dateFormat.format(DateTime.now());
    final dateToStr = _reportDateTo != null ? dateFormat.format(_reportDateTo!) : dateFormat.format(DateTime.now());
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
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
                    child: pw.Image(logoImage!, fit: pw.BoxFit.contain),
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
                    'تقرير الحضور والانصراف | Attendance Report',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'من $dateFromStr إلى $dateToStr',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(2),
                6: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('المهندس', isHeader: true),
                    _cell('نوع التسجيل', isHeader: true),
                    _cell('التاريخ', isHeader: true),
                    _cell('الوقت', isHeader: true),
                    _cell('المشروع', isHeader: true),
                    _cell('الموقع', isHeader: true),
                    _cell('ملاحظات', isHeader: true),
                  ],
                ),
                ...toExport.map((r) => pw.TableRow(
                      children: [
                        _cell(r.userName),
                        _cell(r.isCheckIn ? 'حضور' : 'انصراف'),
                        _cell(dateFormat.format(r.dateTime)),
                        _cell(timeFormat.format(r.dateTime)),
                        _cell(r.projectName ?? '-'),
                        _cell(r.location),
                        _cell(r.notes ?? '-'),
                      ],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await sharePdfBytes(bytes, 'تقرير_الحضور_والانصراف_${dateFromStr}_${dateToStr}.pdf');
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
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
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير الحضور والانصراف'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _isLoading || _displayRecords.isEmpty ? null : _exportPdf,
            tooltip: 'إخراج تقرير PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadRecords,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد سجلات حضور حتى الآن',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecords,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_reportDateFrom != null && _reportDateTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Card(
                            color: const Color(0xFF1B5E20).withOpacity(0.08),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(Icons.date_range, color: const Color(0xFF1B5E20)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'تقرير من ${DateFormat('yyyy/MM/dd', 'ar').format(_reportDateFrom!)} إلى ${DateFormat('yyyy/MM/dd', 'ar').format(_reportDateTo!)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_displayRecords.isEmpty && _reportDateFrom != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'لا توجد سجلات في المدة المحددة',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_displayRecords.length, (index) {
                          final r = _displayRecords[index];
                          return _RecordCard(
                            record: r,
                            canDelete: canEditDeleteAttendance(widget.currentUser),
                            onDelete: () => _deleteRecord(r),
                          );
                        }),
                      const SizedBox(height: 16),
                      if (_reportDateFrom == null || _reportDateTo == null)
                        Center(
                          child: FilledButton.icon(
                            onPressed: _showCreateReportDialog,
                            icon: const Icon(Icons.summarize),
                            label: const Text('إنشاء تقرير'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Column(
                            children: [
                              FilledButton.icon(
                                onPressed: _displayRecords.isEmpty ? null : _exportPdf,
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('تصدير PDF'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5E20),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _clearReportRange,
                                child: const Text('عرض الكل'),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final AttendanceRecordModel record;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _RecordCard({required this.record, this.canDelete = false, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(record.dateTime);
    final timeStr = DateFormat('hh:mm a', 'ar').format(record.dateTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: record.isCheckIn ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.isCheckIn ? 'حضور' : 'انصراف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: record.isCheckIn ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                if (canDelete && onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'حذف السجل',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: Icons.person, label: 'المهندس', value: record.userName),
            _InfoRow(icon: Icons.access_time, label: 'الوقت', value: timeStr),
            if (record.projectName != null && record.projectName!.isNotEmpty)
              _InfoRow(icon: Icons.business, label: 'المشروع', value: record.projectName!),
            _LocationRow(location: record.location),
            if (record.notes != null && record.notes!.isNotEmpty)
              _InfoRow(icon: Icons.note, label: 'ملاحظات', value: record.notes!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

/// عرض الموقع: رابط لفتح الخريطة بدلاً من إظهار الإحداثيات فقط
class _LocationRow extends StatelessWidget {
  final String location;

  const _LocationRow({required this.location});

  bool get _isCoordinates {
    final parts = location.split(',').map((s) => s.trim()).toList();
    if (parts.length != 2) return false;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    return lat != null && lng != null;
  }

  String get _mapUrl {
    final parts = location.split(',').map((s) => s.trim()).toList();
    if (parts.length != 2) return '';
    return 'https://www.google.com/maps?q=${parts[0]},${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text('الموقع', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(
            child: _isCoordinates
                ? InkWell(
                    onTap: () async {
                      final uri = Uri.parse(_mapUrl);
                      try {
                        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                        if (!launched && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تعذر فتح الخريطة. جرّب فتح الرابط من المتصفح.'), backgroundColor: Colors.orange),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تعذر فتح الخريطة: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.map, size: 18, color: Color(0xFF1B5E20)),
                        const SizedBox(width: 6),
                        Text(
                          'عرض على الخريطة',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1B5E20),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(location, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
