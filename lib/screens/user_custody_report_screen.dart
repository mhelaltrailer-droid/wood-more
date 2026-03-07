import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

/// تقرير عهدة المستخدم: اختيار مستخدم (ما عدا مسؤول التطبيق) + مدة → كل الحركات
class UserCustodyReportScreen extends StatefulWidget {
  final UserModel admin;

  const UserCustodyReportScreen({super.key, required this.admin});

  @override
  State<UserCustodyReportScreen> createState() => _UserCustodyReportScreenState();
}

class _UserCustodyReportScreenState extends State<UserCustodyReportScreen> {
  final _db = getStorage();
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final list = await _db.getUsers();
    final excluded = list.where((u) => u.role != 'app_admin').toList();
    if (!mounted) return;
    setState(() => _users = excluded);
  }

  Future<void> _run() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر المستخدم')));
      return;
    }
    setState(() => _loading = true);
    final list = await _db.getCustodyRecords(userId: _selectedUser!.id);
    final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
    final toEnd = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);
    final filtered = list.where((e) {
      final dt = DateTime.parse(e['created_at'] as String);
      return !dt.isBefore(from) && !dt.isAfter(toEnd);
    }).toList();
    if (!mounted) return;
    setState(() {
      _records = filtered;
      _loading = false;
    });
  }

  Future<void> _exportPdf() async {
    if (_records.isEmpty) return;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
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
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) pw.Center(child: pw.Container(height: 56, margin: const pw.EdgeInsets.only(bottom: 12), child: pw.Image(logoImage!, fit: pw.BoxFit.contain))),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                decoration: pw.BoxDecoration(color: PdfColors.green50, borderRadius: pw.BorderRadius.circular(8), border: pw.Border.all(color: PdfColors.green800)),
                child: pw.Center(child: pw.Text('تقرير عهدة المستخدم | User Custody Report', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900))),
              ),
              pw.SizedBox(height: 8),
              pw.Text('المستخدم: ${_selectedUser!.name}', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('من ${dateFormat.format(_dateFrom)} إلى ${dateFormat.format(_dateTo)}', textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1.2)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _cell('التاريخ', true),
                      _cell('البيان', true),
                      _cell('المبلغ', true),
                    ],
                  ),
                  ..._records.map((e) {
                    final dt = DateTime.parse(e['created_at'] as String);
                    return pw.TableRow(
                      children: [
                        _cell(dateFormat.format(dt), false),
                        _cell(e['note'] as String? ?? '—', false),
                        _cell((e['amount'] as num).toStringAsFixed(2), false),
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
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'تقرير_عهدة_${_selectedUser!.name}_${dateFormat.format(_dateFrom)}.pdf');
  }

  pw.Widget _cell(String text, bool isHeader) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(text, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 9, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal, color: isHeader ? PdfColors.green900 : PdfColors.black)),
      );

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير عهدة المستخدم'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<UserModel?>(
            value: _selectedUser,
            decoration: const InputDecoration(labelText: 'المستخدم', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('— اختر المستخدم —')),
              ..._users.map((u) => DropdownMenuItem(value: u, child: Text(u.name))),
            ],
            onChanged: (v) => setState(() => _selectedUser = v),
          ),
          const SizedBox(height: 12),
          ListTile(title: const Text('من تاريخ'), subtitle: Text(dateFormat.format(_dateFrom)), trailing: const Icon(Icons.calendar_today), onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _dateFrom, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _dateFrom = d);
          }),
          ListTile(title: const Text('إلى تاريخ'), subtitle: Text(dateFormat.format(_dateTo)), trailing: const Icon(Icons.calendar_today), onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _dateTo, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
            if (d != null) setState(() => _dateTo = d);
          }),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _loading ? null : _run, icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search), label: const Text('عرض التقرير'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20))),
          if (_records.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('النتائج (${_records.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._records.map((e) {
              final dt = DateTime.parse(e['created_at'] as String);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e['note'] as String? ?? '—'),
                  subtitle: Text(dateFormat.format(dt)),
                  trailing: Text((e['amount'] as num).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            }),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _exportPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('تصدير PDF'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20))),
          ],
        ],
      ),
    );
  }
}
