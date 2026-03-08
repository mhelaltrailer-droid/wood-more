import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// واجهة الماليات للمحاسب: الاطلاع على أرصدة المستخدمين، إضافة/سحب رصيد، وإنشاء تقرير بكل الحركات
class AccountantFinanceScreen extends StatefulWidget {
  final UserModel currentUser;

  const AccountantFinanceScreen({super.key, required this.currentUser});

  @override
  State<AccountantFinanceScreen> createState() => _AccountantFinanceScreenState();
}

class _AccountantFinanceScreenState extends State<AccountantFinanceScreen> {
  final _db = getStorage();
  List<UserModel> _users = [];
  Map<int, double> _balances = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _db.getUsers();
      // عرض كل المستخدمين ما عدا مسؤول التطبيق فقط (بما فيهم المحاسب لمعرفة الرصيد والمبالغ المتبقية)
      final excluded = list.where((u) => u.role != 'app_admin').toList().cast<UserModel>();
      excluded.sort((UserModel a, UserModel b) => a.name.compareTo(b.name));
      final balances = <int, double>{};
      for (final u in excluded) {
        try {
          balances[u.id] = await _db.getEngineerBalance(u.id);
        } catch (_) {
          balances[u.id] = 0.0;
        }
      }
      if (!mounted) return;
      setState(() {
        _users = excluded;
        _balances = balances;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addBalance(UserModel user) async {
    final amountC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة رصيد - ${user.name}'),
        content: TextField(
          controller: amountC,
          decoration: const InputDecoration(labelText: 'المبلغ'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amountC.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    try {
      final current = await _db.getEngineerBalance(user.id);
      await _db.setEngineerBalance(user.id, current + amount);
      await _db.addBalanceMovement(user.id, amount, 'إضافة رصيد', 'add_balance');
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الرصيد'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _withdrawBalance(UserModel user) async {
    final amountC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سحب رصيد - ${user.name}'),
        content: TextField(
          controller: amountC,
          decoration: const InputDecoration(labelText: 'المبلغ'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('سحب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amountC.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    try {
      final current = await _db.getEngineerBalance(user.id);
      await _db.setEngineerBalance(user.id, current - amount);
      await _db.addBalanceMovement(user.id, amount, 'سحب رصيد', 'withdraw_balance');
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم سحب الرصيد'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _showCreateReport() async {
    DateTime dateFrom = DateTime.now();
    DateTime dateTo = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إنشاء تقرير - تحديد المدة'),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('عرض التقرير')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final from = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toEnd = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);

    // حركات العهدة في المدة
    final custodyRecords = await _db.getCustodyRecords(userId: null);
    final custodyInPeriod = custodyRecords.where((e) {
      final dt = DateTime.parse(e['created_at'] as String);
      return !dt.isBefore(from) && !dt.isAfter(toEnd);
    }).toList();

    // مصروفات التقارير اليومية في المدة (لضبط الأرصدة)
    final dailyReports = await _db.getDailyReports(dateFrom: from, dateTo: toEnd);
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

    // دمج الحركات (عهدة + إضافة رصيد + سحب رصيد + صرف تقارير يومية) وترتيب حسب التاريخ
    final combined = <Map<String, dynamic>>[];
    for (final e in custodyInPeriod) {
      combined.add({
        'type': e['movement_type'] as String? ?? 'custody',
        'created_at': e['created_at'] as String,
        'user_id': e['user_id'],
        'user_name': null,
        'note': e['note'] as String? ?? '—',
        'amount': (e['amount'] as num).toDouble(),
      });
    }
    for (final e in expenseMovements) {
      combined.add(e);
    }
    combined.sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));

    final userNames = {for (var u in _users) u.id: u.name};
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AccountantFinanceReportScreen(
          dateFrom: dateFrom,
          dateTo: dateTo,
          movements: combined,
          userNames: userNames,
          users: _users,
          balances: Map.from(_balances),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الماليات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
          await saveLastRoute('home');
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser)));
        },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('أرصدة المستخدمين', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._users.map((u) {
                  final balance = _balances[u.id] ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('الرصيد الحالي: ${balance.toStringAsFixed(2)}',  style: TextStyle(color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text('إضافة رصيد'),
                                    onPressed: () => _addBalance(u),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.remove, size: 20),
                                    label: const Text('سحب رصيد'),
                                    onPressed: () => _withdrawBalance(u),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _showCreateReport,
                  icon: const Icon(Icons.summarize),
                  label: const Text('إنشاء تقرير'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AccountantFinanceReportScreen extends StatelessWidget {
  final DateTime dateFrom;
  final DateTime dateTo;
  final List<Map<String, dynamic>> movements;
  final Map<int, String> userNames;
  final List<UserModel> users;
  final Map<int, double> balances;

  const _AccountantFinanceReportScreen({
    required this.dateFrom,
    required this.dateTo,
    required this.movements,
    required this.userNames,
    required this.users,
    required this.balances,
  });

  String _userName(Map<String, dynamic> e) {
    final id = e['user_id'] as int?;
    if (id == null) return '—';
    final fromMap = e['user_name'] as String?;
    if (fromMap != null && fromMap.isNotEmpty) return fromMap;
    return userNames[id] ?? '—';
  }

  String _typeLabel(Map<String, dynamic> e) {
    final t = e['type'] as String?;
    if (t == 'expense') return 'صرف';
    if (t == 'add_balance') return 'إضافة رصيد';
    if (t == 'withdraw_balance') return 'سحب رصيد';
    return 'عهدة';
  }

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
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (ctx) => pw.Directionality(
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
                  color: pdf.PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: pdf.PdfColors.green800),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'تقرير الحركات المالية (عهدة + مصروفات) | Finance Report',
                    textDirection: pw.TextDirection.rtl,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: pdf.PdfColors.green900),
                  ),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('من ${dateFormat.format(dateFrom)} إلى ${dateFormat.format(dateTo)}', textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: {0: const pw.FlexColumnWidth(0.8), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1.2), 3: const pw.FlexColumnWidth(1.8), 4: const pw.FlexColumnWidth(1)},
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
                  ...movements.map((e) {
                    final dt = DateTime.parse(e['created_at'] as String);
                    return pw.TableRow(
                      children: [
                        _cell(_typeLabel(e), false),
                        _cell(dateFormat.format(dt), false),
                        _cell(_userName(e), false),
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
    await Printing.sharePdf(bytes: bytes, filename: 'تقرير_مالي_${dateFormat.format(dateFrom)}_${dateFormat.format(dateTo)}.pdf');
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
        title: const Text('تقرير الحركات المالية'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('من ${dateFormat.format(dateFrom)} إلى ${dateFormat.format(dateTo)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('الحركات تشمل: عهدة + إضافة رصيد + سحب رصيد + مصروفات التقارير اليومية', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          if (movements.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد حركات في المدة المحددة')))
          else
            ...movements.map((e) {
              final dt = DateTime.parse(e['created_at'] as String);
              final uname = _userName(e);
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
          if (movements.isNotEmpty) ...[
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
