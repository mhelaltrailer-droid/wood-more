import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/user_model.dart';
import '../core/app_theme.dart';
import 'admin_dashboard_screen.dart';

/// نموذج خصم من المرتب | Salary Deduction Form - يظهر لمسؤول التطبيق فقط
class SalaryDeductionScreen extends StatefulWidget {
  final UserModel admin;

  const SalaryDeductionScreen({super.key, required this.admin});

  @override
  State<SalaryDeductionScreen> createState() => _SalaryDeductionScreenState();
}

class _SalaryDeductionScreenState extends State<SalaryDeductionScreen> {
  final _employeeNameC = TextEditingController();
  final _employeeIdC = TextEditingController();
  final _departmentC = TextEditingController();
  final _positionC = TextEditingController();
  final _deductionDateC = TextEditingController();
  final _codeControllers = List.generate(5, (_) => TextEditingController());
  final _amountControllers = List.generate(5, (_) => TextEditingController());
  final _signatureControllers = List.generate(4, (_) => TextEditingController());

  static const List<String> _deductionReasons = [
    'تأخير | Late Arrival',
    'غياب غير مبرر | Unexcused Absence',
    'تلف / فقد أدوات | Damage / Loss',
    'خصم سلفة | Advance Deduction',
    'أخرى | Other',
  ];

  static const List<String> _signatureLabels = [
    'الموظف | Employee Signature',
    'المدير المباشر | Supervisor Signature',
    'الموارد البشرية | HR Signature',
    'مدير العمليات | Operations Manager Signature',
  ];

  @override
  void initState() {
    super.initState();
    _deductionDateC.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _employeeNameC.dispose();
    _employeeIdC.dispose();
    _departmentC.dispose();
    _positionC.dispose();
    _deductionDateC.dispose();
    for (final c in _codeControllers) c.dispose();
    for (final c in _amountControllers) c.dispose();
    for (final c in _signatureControllers) c.dispose();
    super.dispose();
  }

  double get _totalDeduction {
    double sum = 0;
    for (final c in _amountControllers) {
      sum += double.tryParse(c.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('نموذج خصم من المرتب'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => AdminDashboardScreen(currentUser: widget.admin)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSectionTitle('بيانات الموظف | Employee Details'),
            const SizedBox(height: 12),
            _buildField('اسم الموظف | Employee Name', _employeeNameC),
            _buildField('رقم الموظف | Employee ID', _employeeIdC),
            _buildField('القسم | Department', _departmentC),
            _buildField('الوظيفة | Position', _positionC),
            _buildField('تاريخ الخصم | Deduction Date', _deductionDateC),
            const SizedBox(height: 24),
            _buildSectionTitle('تفاصيل الخصم | Deduction Details'),
            const SizedBox(height: 12),
            _buildDeductionTable(),
            const SizedBox(height: 24),
            _buildSectionTitle('التوقيعات | Signatures'),
            const SizedBox(height: 12),
            ..._signatureLabels.asMap().entries.map((e) => _buildField(e.value, _signatureControllers[e.key])),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ النموذج محلياً'), backgroundColor: Color(0xFF1B5E20)),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ النموذج'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _printForm,
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة النموذج'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printForm() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'Wood and More - نموذج خصم من المرتب | Salary Deduction Form',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('بيانات الموظف | Employee Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _pdfRow('اسم الموظف | Employee Name', _employeeNameC.text),
            _pdfRow('رقم الموظف | Employee ID', _employeeIdC.text),
            _pdfRow('القسم | Department', _departmentC.text),
            _pdfRow('الوظيفة | Position', _positionC.text),
            _pdfRow('تاريخ الخصم | Deduction Date', _deductionDateC.text),
            pw.SizedBox(height: 16),
            pw.Text('تفاصيل الخصم | Deduction Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1.2)},
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('سبب الخصم | Reason', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('الكود | Code', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('المبلغ (جنيه) | Amount (EGP)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ],
                ),
                ...List.generate(5, (i) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_deductionReasons[i], style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_codeControllers[i].text, style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_amountControllers[i].text, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    )),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('إجمالي الخصم | Total Deduction', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('', style: const pw.TextStyle(fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(_totalDeduction.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text('التوقيعات | Signatures', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ..._signatureLabels.asMap().entries.map((e) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: 140, child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 9))),
                        pw.Expanded(child: pw.Container(height: 16, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)))),
                      ],
                    ),
                  );
                }),
          ],
        ),
      ),
    );
    final bytes = await doc.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'نموذج_خصم_من_المرتب.pdf');
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 160, child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
          pw.Expanded(child: pw.Text(value.isEmpty ? '—' : value, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
      ),
      child: Text(
        'Wood and More - نموذج خصم من المرتب | Salary Deduction Form',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryGreenDark,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Table(
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.2)},
        border: TableBorder.symmetric(
          inside: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.35)),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.2)),
            children: [
              _tableCell('سبب الخصم | Reason', isHeader: true),
              _tableCell('الكود | Code', isHeader: true),
              _tableCell('المبلغ (جنيه) | Amount (EGP)', isHeader: true),
            ],
          ),
          ...List.generate(5, (i) => TableRow(
                children: [
                  _tableCell(_deductionReasons[i], isHeader: false),
                  _tableCellInput(_codeControllers[i]),
                  _tableCellInput(_amountControllers[i], isAmount: true),
                ],
              )),
          TableRow(
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12)),
            children: [
              _tableCell('إجمالي الخصم | Total Deduction', isHeader: true),
              const TableCell(child: SizedBox.shrink()),
              TableCell(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _totalDeduction.toStringAsFixed(2),
                    style: const TextStyle(
                      color: AppTheme.primaryGreenDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {required bool isHeader}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          color: isHeader ? AppTheme.primaryGreenDark : Colors.black87,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _tableCellInput(TextEditingController controller, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: TextField(
        controller: controller,
        keyboardType: isAmount ? TextInputType.number : TextInputType.text,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.black87, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          filled: true,
          fillColor: const Color(0xFFF1F8E9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppTheme.primaryGreen.withOpacity(0.35)),
          ),
        ),
      ),
    );
  }
}
