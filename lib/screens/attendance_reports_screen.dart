import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/attendance_record_model.dart';
import '../services/storage_service.dart';

/// شاشة تقارير الحضور والانصراف - لمدير المهندسين (عرض فقط)
class AttendanceReportsScreen extends StatefulWidget {
  const AttendanceReportsScreen({super.key});

  @override
  State<AttendanceReportsScreen> createState() => _AttendanceReportsScreenState();
}

class _AttendanceReportsScreenState extends State<AttendanceReportsScreen> {
  final _db = getStorage();
  List<AttendanceRecordModel> _records = [];
  bool _isLoading = true;

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

  Future<void> _exportPdf() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سجلات لتصديرها')),
      );
      return;
    }
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final timeFormat = DateFormat('hh:mm a', 'ar');
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'تقرير الحضور والانصراف - Wood & More',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'تاريخ التقرير: ${dateFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Table(
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
              ..._records.map((r) => pw.TableRow(
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
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'تقرير_الحضور_والانصراف_${dateFormat.format(DateTime.now())}.pdf');
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: isHeader ? 10 : 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal),
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
            onPressed: _isLoading || _records.isEmpty ? null : _exportPdf,
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
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      final r = _records[index];
                      return _RecordCard(record: r);
                    },
                  ),
                ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final AttendanceRecordModel record;

  const _RecordCard({required this.record});

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
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
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
