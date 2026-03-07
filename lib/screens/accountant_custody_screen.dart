import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// شاشة العهدة للمحاسب: اختيار مستخدم أو جميع المستخدمين + مدة → تقرير الحركات مع رصيد أول/آخر المدة + تصدير PDF
class AccountantCustodyScreen extends StatefulWidget {
  final UserModel currentUser;

  const AccountantCustodyScreen({super.key, required this.currentUser});

  @override
  State<AccountantCustodyScreen> createState() => _AccountantCustodyScreenState();
}

class _AccountantCustodyScreenState extends State<AccountantCustodyScreen> {
  final _db = getStorage();
  List<UserModel> _users = [];
  UserModel? _selectedUser; // null = جميع المستخدمين
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _allRecordsForBalance = [];
  Map<int, String> _userNames = {};
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final list = await _db.getUsers();
    // جميع المستخدمين عدا مسؤول التطبيق فقط
    final excluded = list.where((u) => u.role != 'app_admin').toList().cast<UserModel>();
    excluded.sort((UserModel a, UserModel b) => a.name.compareTo(b.name));
    final names = <int, String>{for (var u in list) u.id: u.name};
    if (!mounted) return;
    setState(() {
      _users = excluded;
      _userNames = names;
    });
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toEnd = DateTime(_dateTo.year, _dateTo.month, _dateTo.day, 23, 59, 59);

      // حركات العهدة في المدة
      final custodyList = await _db.getCustodyRecords(userId: _selectedUser?.id);
      final custodyInPeriod = custodyList.where((e) {
        final dt = DateTime.parse(e['created_at'] as String);
        return !dt.isBefore(from) && !dt.isAfter(toEnd);
      }).map((e) => {
        'type': e['movement_type'] as String? ?? 'custody',
        'created_at': e['created_at'],
        'user_id': e['user_id'],
        'user_name': _userNames[e['user_id'] as int?],
        'note': e['note'] as String? ?? '—',
        'amount': (e['amount'] as num).toDouble(),
      }).toList();

      // حركات مصروفات التقارير اليومية في المدة
      final dailyReports = await _db.getDailyReports(dateFrom: from, dateTo: toEnd, userId: _selectedUser?.id);
      final expenseMovements = <Map<String, dynamic>>[];
      for (final r in dailyReports) {
        for (final e in r.expenses) {
          final amt = double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          if (e.description.trim().isEmpty && amt == 0) continue;
          expenseMovements.add({
            'type': 'expense',
            'created_at': DateTime(r.reportDate.year, r.reportDate.month, r.reportDate.day).toIso8601String(),
            'user_id': r.userId,
            'user_name': r.userName,
            'note': e.description.trim().isEmpty ? '—' : e.description,
            'amount': amt,
          });
        }
      }

      final combined = <Map<String, dynamic>>[...custodyInPeriod, ...expenseMovements];
      combined.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));

      if (!mounted) return;
      setState(() {
        _records = combined;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _typeLabel(Map<String, dynamic> e) {
    final t = e['type'] as String?;
    if (t == 'expense') return 'صرف';
    if (t == 'add_balance') return 'إضافة رصيد';
    if (t == 'withdraw_balance') return 'سحب رصيد';
    return 'عهدة';
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
    final userNameLabel = _selectedUser == null ? 'جميع المستخدمين' : _selectedUser!.name;

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        build: (ctx) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
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
                  color: pdf.PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: pdf.PdfColors.green800),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'تقرير العهدة | Custody Report',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.green900),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('المستخدم: $userNameLabel', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('من ${dateFormat.format(_dateFrom)} إلى ${dateFormat.format(_dateTo)}', textDirection: pw.TextDirection.rtl, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 14),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {0: const pw.FlexColumnWidth(0.7), 1: const pw.FlexColumnWidth(1.1), 2: const pw.FlexColumnWidth(1.3), 3: const pw.FlexColumnWidth(1.8), 4: const pw.FlexColumnWidth(1)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey300),
                    children: [
                      _cell('النوع', true),
                      _cell('التاريخ', true),
                      _cell('المستخدم', true),
                      _cell('البيان', true),
                      _cell('المبلغ', true),
                    ],
                  ),
                  ..._records.map((e) {
                    final dt = DateTime.parse(e['created_at'] as String);
                    final uname = (e['user_name'] as String?) ?? _userNames[e['user_id'] as int?] ?? '—';
                    return pw.TableRow(
                      children: [
                        _cell(_typeLabel(e), false),
                        _cell(dateFormat.format(dt), false),
                        _cell(uname, false),
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
    await Printing.sharePdf(bytes: bytes, filename: 'تقرير_العهدة_${dateFormat.format(_dateFrom)}_${dateFormat.format(_dateTo)}.pdf');
  }

  static pw.Widget _cell(String text, bool isHeader) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? pdf.PdfColors.green900 : pdf.PdfColors.black,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser))),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('تقرير العهدة - تحديد المستخدم والمدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserModel?>(
            value: _selectedUser,
            decoration: const InputDecoration(labelText: 'المستخدم', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المستخدمين')),
              ..._users.map((u) => DropdownMenuItem(value: u, child: Text(u.name))),
            ],
            onChanged: (v) => setState(() => _selectedUser = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('من تاريخ'),
            subtitle: Text(dateFormat.format(_dateFrom)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _dateFrom, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _dateFrom = d);
            },
          ),
          ListTile(
            title: const Text('إلى تاريخ'),
            subtitle: Text(dateFormat.format(_dateTo)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _dateTo, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _dateTo = d);
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.summarize),
            label: const Text('عرض'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          if (_records.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('الحركات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('الحركات (عهدة + إضافة رصيد + سحب رصيد + مصروفات التقارير اليومية)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._records.map((e) {
              final dt = DateTime.parse(e['created_at'] as String);
              final uname = (e['user_name'] as String?) ?? _userNames[e['user_id'] as int?] ?? '—';
              final typeLabel = _typeLabel(e);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(e['note'] as String? ?? '—'),
                  subtitle: Text('${dateFormat.format(dt)} • $uname • $typeLabel'),
                  trailing: Text((e['amount'] as num).toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            }),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير PDF'),
              onPressed: _exportPdf,
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
