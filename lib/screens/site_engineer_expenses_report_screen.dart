import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/daily_report_model.dart';
import '../models/detailed_report_model.dart';
import '../models/user_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

const Set<String> _expenseReportRoles = {
  'site_engineer',
  'site_engineer_manager',
  'general_supervisor',
};

class _ExpenseRowData {
  final int reportId;
  final int expenseIndex;
  final int reportUserId;
  final DateTime reportDate;
  final String userName;
  final String description;
  final String amountText;
  final double amountValue;
  final String? imagePath;

  const _ExpenseRowData({
    required this.reportId,
    required this.expenseIndex,
    required this.reportUserId,
    required this.reportDate,
    required this.userName,
    required this.description,
    required this.amountText,
    required this.amountValue,
    this.imagePath,
  });
}

/// تقرير بنود صرف مهندسي المواقع (عهدة/مصروفات) — للمحاسب أو مسؤول التطبيق.
class SiteEngineerExpensesReportScreen extends StatefulWidget {
  final UserModel currentUser;
  final bool canDeleteExpenses;
  final String appBarTitle;

  const SiteEngineerExpensesReportScreen({
    super.key,
    required this.currentUser,
    this.canDeleteExpenses = false,
    this.appBarTitle = 'تقرير العهدة',
  });

  @override
  State<SiteEngineerExpensesReportScreen> createState() =>
      _SiteEngineerExpensesReportScreenState();
}

class _SiteEngineerExpensesReportScreenState
    extends State<SiteEngineerExpensesReportScreen> {
  final _db = getStorage();
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  DateTime _dateFrom = DateTime.now();
  DateTime _dateTo = DateTime.now();
  List<_ExpenseRowData> _rows = [];
  final Map<int, DetailedReportModel> _reportsById = {};
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  static bool _expenseHasContent(ExpenseItem e) {
    final a = double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    return e.description.trim().isNotEmpty ||
        a != 0 ||
        (e.imagePath != null && e.imagePath!.trim().isNotEmpty);
  }

  Future<void> _loadUsers() async {
    final list = await _db.getUsers();
    final filtered = list
        .where((u) => _expenseReportRoles.contains(u.role))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (!mounted) return;
    setState(() => _users = filtered);
  }

  List<_ExpenseRowData> _buildRowsFromReports(List<DetailedReportModel> reports) {
    final allowedIds = _users.map((u) => u.id).toSet();
    final out = <_ExpenseRowData>[];
    for (final report in reports) {
      if (report.id == null) continue;
      if (!allowedIds.contains(report.userId)) continue;
      for (var i = 0; i < report.expenses.length; i++) {
        final e = report.expenses[i];
        if (!_expenseHasContent(e)) continue;
        final amountValue =
            double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final day = DateTime(
          report.reportDatetime.year,
          report.reportDatetime.month,
          report.reportDatetime.day,
        );
        out.add(
          _ExpenseRowData(
            reportId: report.id!,
            expenseIndex: i,
            reportUserId: report.userId,
            reportDate: day,
            userName: report.userName,
            description: e.description.trim().isEmpty ? '—' : e.description.trim(),
            amountText: e.amount.trim().isEmpty
                ? amountValue.toStringAsFixed(2)
                : e.amount.trim(),
            amountValue: amountValue,
            imagePath: e.imagePath,
          ),
        );
      }
    }
    out.sort((a, b) {
      final d = b.reportDate.compareTo(a.reportDate);
      if (d != 0) return d;
      return a.userName.compareTo(b.userName);
    });
    return out;
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final from = DateTime(_dateFrom.year, _dateFrom.month, _dateFrom.day);
      final toEnd = DateTime(
        _dateTo.year,
        _dateTo.month,
        _dateTo.day,
        23,
        59,
        59,
      );
      final reports = await _db.getDetailedReports(
        dateFrom: from,
        dateTo: toEnd,
        userId: _selectedUser?.id,
      );
      final reportsById = <int, DetailedReportModel>{
        for (final r in reports)
          if (r.id != null) r.id!: r,
      };
      final rows = _buildRowsFromReports(reports);
      if (!mounted) return;
      setState(() {
        _reportsById
          ..clear()
          ..addAll(reportsById);
        _rows = rows;
        _loading = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteExpense(_ExpenseRowData row) async {
    final report = _reportsById[row.reportId];
    if (report == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف بند الصرف'),
        content: Text(
          'حذف البند:\n${row.description}\nبمبلغ ${row.amountText}؟',
        ),
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
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final updated = List<ExpenseItem>.from(report.expenses);
      if (row.expenseIndex < 0 || row.expenseIndex >= updated.length) {
        throw Exception('البند غير موجود');
      }
      updated.removeAt(row.expenseIndex);
      await _db.patchDetailedReportExpenses(
        reportId: row.reportId,
        userId: row.reportUserId,
        expenses: updated,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف بند الصرف'), backgroundColor: Colors.green),
      );
      await _run();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  static Uint8List? _decodeDataUri(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (!path.startsWith('data:')) return null;
    final comma = path.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(path.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  void _openFullImage(String imagePath) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('تعذر عرض الصورة'),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentCell(_ExpenseRowData row) {
    final path = row.imagePath?.trim();
    if (path == null || path.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.grey));
    }
    return InkWell(
      onTap: () => _openFullImage(path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          path,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 40),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_rows.isEmpty) return;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final fontBase = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final userNameLabel =
        _selectedUser == null ? 'جميع المستخدمين' : _selectedUser!.name;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (ctx) => [
          if (logoImage != null)
            pw.Center(
              child: pw.Container(
                height: 48,
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
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
                'تقرير بنود الصرف | Expense Items Report',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: pdf.PdfColors.green900,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('المستخدم: $userNameLabel', textDirection: pw.TextDirection.rtl),
          pw.Text(
            'من ${dateFormat.format(_dateFrom)} إلى ${dateFormat.format(_dateTo)}',
            textDirection: pw.TextDirection.rtl,
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.9),
              1: const pw.FlexColumnWidth(1.1),
              2: const pw.FlexColumnWidth(2.2),
              3: const pw.FlexColumnWidth(0.9),
              4: const pw.FlexColumnWidth(0.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey300),
                children: [
                  _pdfCell('التاريخ', true),
                  _pdfCell('المستخدم', true),
                  _pdfCell('بند الصرف', true),
                  _pdfCell('المبلغ', true),
                  _pdfCell('المرفق', true),
                ],
              ),
              ..._rows.map((row) {
                final bytes = _decodeDataUri(row.imagePath);
                pw.Widget attachmentWidget;
                if (bytes != null) {
                  attachmentWidget = pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Image(
                      pw.MemoryImage(bytes),
                      width: 48,
                      height: 48,
                      fit: pw.BoxFit.cover,
                    ),
                  );
                } else if (row.imagePath != null &&
                    row.imagePath!.trim().isNotEmpty) {
                  attachmentWidget = _pdfCell('مرفق', false);
                } else {
                  attachmentWidget = _pdfCell('—', false);
                }
                return pw.TableRow(
                  children: [
                    _pdfCell(dateFormat.format(row.reportDate), false),
                    _pdfCell(row.userName, false),
                    _pdfCell(row.description, false),
                    _pdfCell(row.amountText, false),
                    attachmentWidget,
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'بنود_الصرف_${dateFormat.format(_dateFrom)}_${dateFormat.format(_dateTo)}.pdf',
    );
  }

  static pw.Widget _pdfCell(String text, bool isHeader) {
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
        title: Text(widget.appBarTitle),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(currentUser: widget.currentUser),
              ),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'بنود صرف العهدة/المصروفات — تحديد المستخدم والمدة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'يعرض بنود الصرف المُدخلة من مهندسي المواقع (ومديري المشروعات والمشرف العام عند وجودها)',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserModel?>(
            value: _selectedUser,
            decoration: const InputDecoration(
              labelText: 'المستخدم',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('جميع المستخدمين')),
              ..._users.map(
                (u) => DropdownMenuItem(value: u, child: Text(u.name)),
              ),
            ],
            onChanged: (v) => setState(() => _selectedUser = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('من تاريخ'),
            subtitle: Text(dateFormat.format(_dateFrom)),
            trailing: const Icon(Icons.calendar_today),
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
          ListTile(
            title: const Text('إلى تاريخ'),
            subtitle: Text(dateFormat.format(_dateTo)),
            trailing: const Icon(Icons.calendar_today),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _run,
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.summarize),
            label: const Text('عرض'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_hasSearched && !_loading) ...[
            const SizedBox(height: 24),
            Text(
              'عدد البنود: ${_rows.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد بنود صرف في هذه المدة')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.green.shade100),
                  columns: [
                    if (widget.canDeleteExpenses)
                      const DataColumn(label: Text('حذف')),
                    const DataColumn(label: Text('التاريخ')),
                    const DataColumn(label: Text('المستخدم')),
                    const DataColumn(label: Text('بند الصرف')),
                    const DataColumn(label: Text('المبلغ')),
                    const DataColumn(label: Text('المرفقات')),
                  ],
                  rows: _rows
                      .map(
                        (row) => DataRow(
                          cells: [
                            if (widget.canDeleteExpenses)
                              DataCell(
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Colors.red.shade700,
                                  ),
                                  tooltip: 'حذف بند الصرف',
                                  onPressed: () => _deleteExpense(row),
                                ),
                              ),
                            DataCell(Text(dateFormat.format(row.reportDate))),
                            DataCell(
                              SizedBox(
                                width: 110,
                                child: Text(
                                  row.userName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Text(
                                  row.description,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(row.amountText)),
                            DataCell(_attachmentCell(row)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            if (_rows.isNotEmpty) ...[
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
        ],
      ),
    );
  }
}
