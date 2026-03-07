import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// شاشة العهدة - لمدير المهندسين فقط: إدخال عهدة + تقرير العهدة مع تصدير PDF
class ManagerCustodyScreen extends StatefulWidget {
  final UserModel currentUser;

  const ManagerCustodyScreen({super.key, required this.currentUser});

  @override
  State<ManagerCustodyScreen> createState() => _ManagerCustodyScreenState();
}

class _ManagerCustodyScreenState extends State<ManagerCustodyScreen> {
  final _db = getStorage();
  final _noteC = TextEditingController();
  final _amountC = TextEditingController();
  final _documentC = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _noteC.dispose();
    _amountC.dispose();
    _documentC.dispose();
    super.dispose();
  }

  static String _mimeFromExtension(String? path) {
    final ext = path?.split('.').last.toLowerCase() ?? '';
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'png' || ext == 'gif' || ext == 'webp') return 'image/$ext';
    return 'image/jpeg';
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;
      final mime = _mimeFromExtension(file.name);
      _documentC.text = 'data:$mime;base64,${base64Encode(bytes)}';
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرفاق: ${file.name}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _save() async {
    final note = _noteC.text.trim();
    final amountStr = _amountC.text.trim().replaceAll(RegExp(r'[^\d.]'), '');
    final amount = double.tryParse(amountStr);
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل بيان الصرف')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل المبلغ صحيحاً')));
      return;
    }
    setState(() => _loading = true);
    try {
      final docPath = _documentC.text.trim().isEmpty ? null : _documentC.text.trim();
      await _db.addCustody(widget.currentUser.id, amount, note, docPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green));
      _noteC.clear();
      _amountC.clear();
      _documentC.clear();
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showReport() async {
    DateTime dateFrom = DateTime.now();
    DateTime dateTo = DateTime.now();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('تقرير العهدة - تحديد المدة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('من تاريخ'),
                subtitle: Text(DateFormat('yyyy/MM/dd', 'ar').format(dateFrom)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: dateFrom, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setDialog(() => dateFrom = d);
                },
              ),
              ListTile(
                title: const Text('إلى تاريخ'),
                subtitle: Text(DateFormat('yyyy/MM/dd', 'ar').format(dateTo)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: dateTo, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setDialog(() => dateTo = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: const Text('عرض'),
            ),
          ],
        ),
      ),
    );
    final list = await _db.getCustodyRecords(userId: widget.currentUser.id);
    final from = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toEnd = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
    final filtered = list.where((e) {
      final dt = DateTime.parse(e['created_at'] as String);
      return !dt.isBefore(from) && !dt.isAfter(toEnd);
    }).toList();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CustodyReportScreen(
          currentUser: widget.currentUser,
          records: filtered,
          dateFrom: dateFrom,
          dateTo: dateTo,
          userName: widget.currentUser.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العهدة'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser))),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('إدخال عهدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('المستخدم', style: TextStyle(color: Colors.grey)),
            subtitle: Text(widget.currentUser.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            tileColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteC,
            decoration: const InputDecoration(labelText: 'بيان الصرف', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: Text(_documentC.text.isEmpty ? 'إرفاق مستند (إن وجد)' : 'تم إرفاق مستند'),
            onPressed: _pickDocument,
          ),
          if (_documentC.text.isNotEmpty)
            ListTile(
              title: const Text('مستند مرفق', style: TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _documentC.clear()),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                  label: const Text('حفظ'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showReport,
                  icon: const Icon(Icons.summarize),
                  label: const Text('تقرير العهدة'),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1B5E20), side: const BorderSide(color: Color(0xFF1B5E20)), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustodyReportScreen extends StatelessWidget {
  final UserModel currentUser;
  final List<Map<String, dynamic>> records;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String userName;

  const _CustodyReportScreen({required this.currentUser, required this.records, required this.dateFrom, required this.dateTo, required this.userName});

  Future<void> _exportPdf(BuildContext context) async {
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
                    'تقرير العهدة | Custody Report',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('المستخدم: $userName', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('من ${dateFormat.format(dateFrom)} إلى ${dateFormat.format(dateTo)}', textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 14),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {0: const pw.FlexColumnWidth(1.5), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1.2)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _cell('التاريخ', isHeader: true),
                      _cell('البيان', isHeader: true),
                      _cell('المبلغ', isHeader: true),
                    ],
                  ),
                  ...records.map((e) {
                    final dt = DateTime.parse(e['created_at'] as String);
                    final note = e['note'] as String? ?? '—';
                    return pw.TableRow(
                      children: [
                        _cell(dateFormat.format(dt), isHeader: false),
                        _cell(note, isHeader: false),
                        _cell((e['amount'] as num).toStringAsFixed(2), isHeader: false),
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
    await Printing.sharePdf(bytes: bytes, filename: 'تقرير_العهدة_${dateFormat.format(dateFrom)}_${dateFormat.format(dateTo)}.pdf');
  }

  static pw.Widget _cell(String text, {required bool isHeader}) {
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
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير العهدة'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('المستخدم: $userName', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('من ${dateFormat.format(dateFrom)} إلى ${dateFormat.format(dateTo)}', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد حركات في المدة المحددة')))
          else
            ...records.map((e) {
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
          if (records.isNotEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير PDF'),
              onPressed: () => _exportPdf(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
