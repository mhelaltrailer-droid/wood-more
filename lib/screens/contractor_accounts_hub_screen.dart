import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/cont_invoices_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/contractor_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/cont_invoice_statement_pdf.dart';
import '../widgets/cont_invoice_payment_dialog.dart';
import 'cont_invoices_work_screen.dart';

enum _DateFilterKind { statement, payment }

class _ContractorAccountRow {
  final int? contractorId;
  final String contractorName;
  final double due;
  final double paid;
  final double remaining;
  final List<ContInvoiceModel> invoices;

  const _ContractorAccountRow({
    required this.contractorId,
    required this.contractorName,
    required this.due,
    required this.paid,
    required this.remaining,
    required this.invoices,
  });
}

class ContractorAccountsHubScreen extends StatefulWidget {
  final UserModel currentUser;

  const ContractorAccountsHubScreen({super.key, required this.currentUser});

  @override
  State<ContractorAccountsHubScreen> createState() =>
      _ContractorAccountsHubScreenState();
}

class _ContractorAccountsHubScreenState
    extends State<ContractorAccountsHubScreen> {
  final _storage = getStorage();
  final _moneyFmt = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  bool _printing = false;
  String? _error;
  List<ContInvoiceModel> _allPosted = const [];
  List<_ContractorAccountRow> _rows = const [];
  String? _projectFilter;
  final Set<String> _contractorKeys = {};
  DateTime? _from;
  DateTime? _to;
  _DateFilterKind _dateKind = _DateFilterKind.statement;

  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;
  bool get _hasRange => _from != null || _to != null;

  String get _paidLabel =>
      _dateKind == _DateFilterKind.payment && _hasRange ? 'مصروف الفترة' : 'مصروف';

  String get _dateKindLabel => _dateKind == _DateFilterKind.statement
      ? 'أساس الفترة: تاريخ المستخلص'
      : 'أساس الفترة: تاريخ الدفعة';

  String get _rangeLabel {
    return [
      if (_from != null) 'من ${_dateFmt.format(_from!)}',
      if (_to != null) 'إلى ${_dateFmt.format(_to!)}',
      if (_projectFilter != null) 'مشروع: $_projectFilter',
      if (_contractorKeys.isNotEmpty) 'مقاول: $_contractorFilterLabel',
      _dateKindLabel,
    ].join('  |  ');
  }

  String get _filterHint => _dateKind == _DateFilterKind.statement
      ? 'تاريخ المستخلص: يظهر مستحقات الفترة حتى لو الدفعة اتأخرت بعدها.'
      : 'تاريخ الدفعة: يظهر ما تم صرفه نقداً داخل الفترة حتى لو المستخلص أقدم.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isPosted(ContInvoiceModel inv) {
    return inv.status == contStatusApproved ||
        inv.status == contStatusPartiallyPaid ||
        inv.status == contStatusPaid;
  }

  Future<List<ContInvoiceModel>> _hydratePayments(
    List<ContInvoiceModel> invoices,
  ) async {
    final missing = invoices
        .where(
          (inv) =>
              inv.id != null && inv.payments.isEmpty && inv.paidAmount > 0,
        )
        .toList();
    if (missing.isEmpty) return invoices;
    final fetched = <int, ContInvoiceModel>{};
    await Future.wait(
      missing.map((inv) async {
        try {
          fetched[inv.id!] = await _api.getContInvoiceDetail(
            inv.id!,
            widget.currentUser.id,
          );
        } catch (_) {}
      }),
    );
    if (fetched.isEmpty) return invoices;
    return invoices.map((inv) => fetched[inv.id] ?? inv).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_isApi) throw Exception('يتطلب الاتصال بالخادم');
      final list = await _api.getContInvoices(widget.currentUser.id);
      final posted = await _hydratePayments(list.where(_isPosted).toList());
      if (!mounted) return;
      setState(() {
        _allPosted = posted;
        _loading = false;
      });
      _rebuildRows();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _dayInRange(DateTime? d) {
    if (d == null) return !_hasRange;
    final day = _day(d);
    if (_from != null && day.isBefore(_day(_from!))) return false;
    if (_to != null && day.isAfter(_day(_to!))) return false;
    return true;
  }

  String _contractorKey(ContInvoiceModel inv) {
    return inv.contractorId != null
        ? 'id:${inv.contractorId}'
        : 'name:${inv.contractorName.trim().toLowerCase()}';
  }

  bool _invoiceMatches(ContInvoiceModel inv) {
    if (_projectFilter != null &&
        inv.projectName.trim() != _projectFilter) {
      return false;
    }
    if (_contractorKeys.isNotEmpty &&
        !_contractorKeys.contains(_contractorKey(inv))) {
      return false;
    }
    if (!_hasRange) return true;
    if (_dateKind == _DateFilterKind.statement) {
      return _dayInRange(inv.statementDate);
    }
    return inv.payments.any((p) => _dayInRange(p.createdAt?.toLocal()));
  }

  List<ContInvoicePaymentModel> _paymentsInView(ContInvoiceModel inv) {
    if (_dateKind != _DateFilterKind.payment || !_hasRange) {
      return inv.payments;
    }
    return inv.payments
        .where((p) => _dayInRange(p.createdAt?.toLocal()))
        .toList();
  }

  double _paidForInvoice(ContInvoiceModel inv) {
    if (_dateKind == _DateFilterKind.payment && _hasRange) {
      return _round2(
        _paymentsInView(inv).fold<double>(0, (s, p) => s + p.amount),
      );
    }
    return inv.paidAmount;
  }

  double _round2(double n) => double.parse(n.toStringAsFixed(2));

  List<String> get _projectNames {
    final names = _allPosted
        .map((e) => e.projectName.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  List<({String key, String name})> get _contractorOptions {
    final names = <String, String>{};
    for (final inv in _allPosted) {
      if (_projectFilter != null &&
          inv.projectName.trim() != _projectFilter) {
        continue;
      }
      names.putIfAbsent(_contractorKey(inv), () => inv.contractorName);
    }
    final list = names.entries
        .map((e) => (key: e.key, name: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  String get _contractorFilterLabel {
    if (_contractorKeys.isEmpty) return 'كل المقاولين';
    final names = _contractorOptions
        .where((o) => _contractorKeys.contains(o.key))
        .map((o) => o.name)
        .toList();
    if (names.isEmpty) return 'كل المقاولين';
    if (names.length == 1) return names.first;
    return '${names.length} مقاولين';
  }

  void _rebuildRows() {
    final valid = _contractorOptions.map((e) => e.key).toSet();
    _contractorKeys.removeWhere((k) => !valid.contains(k));
    final posted = _allPosted.where(_invoiceMatches).toList();
    final byKey = <String, List<ContInvoiceModel>>{};
    for (final inv in posted) {
      byKey.putIfAbsent(_contractorKey(inv), () => []).add(inv);
    }
    final rows = byKey.values.map((invoices) {
      final first = invoices.first;
      var due = 0.0;
      var paid = 0.0;
      var remaining = 0.0;
      for (final inv in invoices) {
        due += inv.amountDue;
        paid += _paidForInvoice(inv);
        remaining += inv.remainingAmount;
      }
      return _ContractorAccountRow(
        contractorId: first.contractorId,
        contractorName: first.contractorName,
        due: _round2(due),
        paid: _round2(paid),
        remaining: _round2(remaining),
        invoices: invoices,
      );
    }).toList()
      ..sort((a, b) => b.remaining.compareTo(a.remaining));
    setState(() => _rows = rows);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_from ?? now) : (_to ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _rebuildRows();
  }

  Future<void> _pickProject() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('المشروع'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                RadioListTile<String>(
                  title: const Text('كل المشروعات'),
                  value: '',
                  groupValue: _projectFilter ?? '',
                  onChanged: (v) => Navigator.pop(ctx, v ?? ''),
                ),
                ..._projectNames.map(
                  (n) => RadioListTile<String>(
                    title: Text(n),
                    value: n,
                    groupValue: _projectFilter ?? '',
                    onChanged: (v) => Navigator.pop(ctx, v ?? n),
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
          ],
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _projectFilter = selected.isEmpty ? null : selected;
    });
    _rebuildRows();
  }

  Future<void> _pickContractors() async {
    final options = _contractorOptions;
    final draft = Set<String>.from(_contractorKeys);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: const Text('المقاول'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: options.isEmpty
                      ? const Text('لا يوجد مقاولون في العرض الحالي')
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            CheckboxListTile(
                              title: const Text('كل المقاولين'),
                              value: draft.isEmpty,
                              onChanged: (_) => setLocal(draft.clear),
                            ),
                            ...options.map(
                              (o) => CheckboxListTile(
                                title: Text(o.name),
                                value: draft.contains(o.key),
                                onChanged: (v) {
                                  setLocal(() {
                                    if (v == true) {
                                      draft.add(o.key);
                                    } else {
                                      draft.remove(o.key);
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
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('تم'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (ok != true) return;
    setState(() {
      _contractorKeys
        ..clear()
        ..addAll(draft);
    });
    _rebuildRows();
  }

  Widget _pickerField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(Icons.arrow_drop_down),
        ).copyWith(labelText: label),
        child: Text(value, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }

  Future<pw.ThemeData> _pdfTheme() async {
    final fontBase = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    return pw.ThemeData.withFont(base: fontBase, bold: fontBold);
  }

  Future<pw.ImageProvider?> _pdfLogo() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<void> _printSummary() async {
    if (_rows.isEmpty || _printing) return;
    setState(() => _printing = true);
    try {
      final totalDue = _rows.fold<double>(0, (s, r) => s + r.due);
      final totalPaid = _rows.fold<double>(0, (s, r) => s + r.paid);
      final totalRemaining = _rows.fold<double>(0, (s, r) => s + r.remaining);
      final theme = await _pdfTheme();
      final logo = await _pdfLogo();
      final doc = pw.Document(theme: theme);
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (ctx) => [
            if (logo != null)
              pw.Center(
                child: pw.Container(
                  height: 48,
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              ),
            pw.Text(
              'حسابات المقاولين — ملخص',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
            ),
            pw.Text(_rangeLabel, textAlign: pw.TextAlign.right),
            pw.SizedBox(height: 6),
            pw.Text(_filterHint, textAlign: pw.TextAlign.right),
            pw.SizedBox(height: 8),
            pw.Text(
              'مستحق: ${_moneyFmt.format(totalDue)}   '
              '$_paidLabel: ${_moneyFmt.format(totalPaid)}   '
              'باقي: ${_moneyFmt.format(totalRemaining)}',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfCell('المقاول', header: true),
                    _pdfCell('مستحق', header: true),
                    _pdfCell(_paidLabel, header: true),
                    _pdfCell('باقي', header: true),
                  ],
                ),
                ..._rows.map(
                  (r) => pw.TableRow(
                    children: [
                      _pdfCell(r.contractorName),
                      _pdfCell(_moneyFmt.format(r.due)),
                      _pdfCell(_moneyFmt.format(r.paid)),
                      _pdfCell(_moneyFmt.format(r.remaining)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'حسابات_المقاولين_ملخص.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الطباعة: $e')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printDetailed({_ContractorAccountRow? only}) async {
    final rows = only == null ? _rows : [only];
    if (rows.isEmpty || _printing) return;
    setState(() => _printing = true);
    try {
      final theme = await _pdfTheme();
      final logo = await _pdfLogo();
      final doc = pw.Document(theme: theme);
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (ctx) {
            final widgets = <pw.Widget>[
              if (logo != null)
                pw.Center(
                  child: pw.Container(
                    height: 48,
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                ),
              pw.Text(
                only == null
                    ? 'كشف تفصيلي — حسابات المقاولين'
                    : 'كشف تفصيلي — ${only.contractorName}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
              pw.Text(_rangeLabel, textAlign: pw.TextAlign.right),
              pw.SizedBox(height: 4),
              pw.Text(_filterHint, textAlign: pw.TextAlign.right),
              pw.SizedBox(height: 12),
            ];
            for (var i = 0; i < rows.length; i++) {
              widgets.addAll(_pdfContractorSection(rows[i]));
              if (i < rows.length - 1) {
                widgets.add(pw.SizedBox(height: 16));
                widgets.add(pw.Divider());
                widgets.add(pw.SizedBox(height: 12));
              }
            }
            return widgets;
          },
        ),
      );
      final name = only == null
          ? 'كشف_حسابات_المقاولين.pdf'
          : 'كشف_${only.contractorName}.pdf';
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الطباعة: $e')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  List<pw.Widget> _pdfContractorSection(_ContractorAccountRow row) {
    final invoices = [...row.invoices]..sort((a, b) {
      final ad = a.statementDate ?? DateTime(1970);
      final bd = b.statementDate ?? DateTime(1970);
      return ad.compareTo(bd);
    });
    return [
      pw.Text(
        row.contractorName,
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.right,
      ),
      pw.Text(
        'مستحق: ${_moneyFmt.format(row.due)}   '
        '$_paidLabel: ${_moneyFmt.format(row.paid)}   '
        'باقي: ${_moneyFmt.format(row.remaining)}',
        textAlign: pw.TextAlign.right,
      ),
      pw.SizedBox(height: 8),
      ...invoices.expand(_pdfInvoiceBlock),
    ];
  }

  List<pw.Widget> _pdfInvoiceBlock(ContInvoiceModel inv) {
    final dateLabel = inv.statementDate == null
        ? '—'
        : _dateFmt.format(inv.statementDate!);
    final payments = _paymentsInView(inv);
    return [
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey600),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
              _pdfCell('المشروع / التاريخ', header: true),
              _pdfCell('الحالة', header: true),
              _pdfCell('مستحق', header: true),
              _pdfCell(_paidLabel, header: true),
              _pdfCell('باقي', header: true),
            ],
          ),
          pw.TableRow(
            children: [
              _pdfCell('${inv.projectName}\n$dateLabel'),
              _pdfCell(inv.statusLabelAr),
              _pdfCell(_moneyFmt.format(inv.amountDue)),
              _pdfCell(_moneyFmt.format(_paidForInvoice(inv))),
              _pdfCell(_moneyFmt.format(inv.remainingAmount)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 4),
      if (payments.isEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            'لا توجد دفعات في العرض الحالي',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        )
      else
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey500),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _pdfCell('تاريخ الدفعة', header: true),
                  _pdfCell('المبلغ', header: true),
                  _pdfCell('ملاحظة', header: true),
                  _pdfCell('مرفقات', header: true),
                ],
              ),
              ...payments.map((p) {
                final files = p.attachments
                    .map((a) => a.fileName)
                    .where((n) => n.trim().isNotEmpty)
                    .join('، ');
                return pw.TableRow(
                  children: [
                    _pdfCell(
                      p.createdAt == null
                          ? '—'
                          : _dateFmt.format(p.createdAt!.toLocal()),
                    ),
                    _pdfCell(_moneyFmt.format(p.amount)),
                    _pdfCell(p.note.trim().isEmpty ? '—' : p.note),
                    _pdfCell(
                      files.isNotEmpty
                          ? files
                          : (p.fileName.trim().isEmpty ? '—' : p.fileName),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
    ];
  }

  pw.Widget _pdfCell(String text, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: header ? 10 : 9,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _openInvoice(ContInvoiceModel inv) async {
    if (inv.id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContInvoicesWorkScreen(
          currentUser: widget.currentUser,
          contractor: ContractorModel(
            id: inv.contractorId ?? 0,
            name: inv.contractorName,
          ),
          project: ProjectModel(
            id: inv.projectId ?? 0,
            name: inv.projectName,
          ),
          existing: inv,
        ),
      ),
    );
    await _load();
  }

  _ContractorAccountRow? _rowFor(_ContractorAccountRow sample) {
    for (final r in _rows) {
      if (sample.contractorId != null && r.contractorId == sample.contractorId) {
        return r;
      }
      if (r.contractorName.trim().toLowerCase() ==
          sample.contractorName.trim().toLowerCase()) {
        return r;
      }
    }
    return null;
  }

  void _openContractor(_ContractorAccountRow row) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ContractorAccountDetailScreen(
          row: row,
          currentUser: widget.currentUser,
          moneyFmt: _moneyFmt,
          dateFmt: _dateFmt,
          rangeLabel: _rangeLabel,
          paidLabel: _paidLabel,
          paymentsFor: _paymentsInView,
          paidFor: _paidForInvoice,
          onOpenInvoice: _openInvoice,
          onPrint: () => _printDetailed(only: _rowFor(row) ?? row),
          reloadRow: () async {
            await _load();
            return _rowFor(row);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDue = _rows.fold<double>(0, (s, r) => s + r.due);
    final totalPaid = _rows.fold<double>(0, (s, r) => s + r.paid);
    final totalRemaining = _rows.fold<double>(0, (s, r) => s + r.remaining);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(contractorAccountsHomeLabel),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'طباعة',
              enabled: !_loading && !_printing && _rows.isNotEmpty,
              icon: const Icon(Icons.print_outlined),
              onSelected: (v) {
                if (v == 'summary') {
                  _printSummary();
                } else if (v == 'detail') {
                  _printDetailed();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'summary',
                  child: Text('ملخص المقاولين'),
                ),
                PopupMenuItem(
                  value: 'detail',
                  child: Text('كشف تفصيلي لكل مقاول'),
                ),
              ],
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _pickerField(
                          label: 'المشروع',
                          value: _projectFilter ?? 'كل المشروعات',
                          onTap: _pickProject,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _pickerField(
                          label: 'المقاول',
                          value: _contractorFilterLabel,
                          onTap: _pickContractors,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ChoiceChip(
                              label: const Text('تاريخ المستخلص'),
                              selected:
                                  _dateKind == _DateFilterKind.statement,
                              onSelected: (_) {
                                setState(
                                  () => _dateKind = _DateFilterKind.statement,
                                );
                                _rebuildRows();
                              },
                            ),
                            ChoiceChip(
                              label: const Text('تاريخ الدفعة'),
                              selected: _dateKind == _DateFilterKind.payment,
                              onSelected: (_) {
                                setState(
                                  () => _dateKind = _DateFilterKind.payment,
                                );
                                _rebuildRows();
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _filterHint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(isFrom: true),
                                child: Text(
                                  _from == null
                                      ? 'من تاريخ'
                                      : 'من ${_dateFmt.format(_from!)}',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(isFrom: false),
                                child: Text(
                                  _to == null
                                      ? 'إلى تاريخ'
                                      : 'إلى ${_dateFmt.format(_to!)}',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'مسح الفترة',
                              onPressed: !_hasRange
                                  ? null
                                  : () {
                                      setState(() {
                                        _from = null;
                                        _to = null;
                                      });
                                      _rebuildRows();
                                    },
                              icon: const Icon(Icons.clear),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _sum('إجمالي المستحق', totalDue, bold: true),
                              _sum('إجمالي $_paidLabel', totalPaid),
                              _sum(
                                'إجمالي الباقي على الشركة',
                                totalRemaining,
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _rows.isEmpty
                            ? Center(
                                child: Text(
                                  _hasRange &&
                                          _dateKind == _DateFilterKind.payment
                                      ? 'لا توجد دفعات في الفترة'
                                      : _hasRange
                                          ? 'لا توجد مستخلصات في الفترة'
                                          : 'لا توجد مستحقات معتمدة بعد',
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _rows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final row = _rows[i];
                                  return Card(
                                    child: ListTile(
                                      title: Text(
                                        row.contractorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'مستحق: ${_moneyFmt.format(row.due)}\n'
                                        '$_paidLabel: ${_moneyFmt.format(row.paid)}  |  باقي: ${_moneyFmt.format(row.remaining)}',
                                      ),
                                      isThreeLine: true,
                                      onTap: () => _openContractor(row),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _sum(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _moneyFmt.format(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractorAccountDetailScreen extends StatefulWidget {
  final _ContractorAccountRow row;
  final UserModel currentUser;
  final NumberFormat moneyFmt;
  final DateFormat dateFmt;
  final String rangeLabel;
  final String paidLabel;
  final List<ContInvoicePaymentModel> Function(ContInvoiceModel inv)
      paymentsFor;
  final double Function(ContInvoiceModel inv) paidFor;
  final Future<void> Function(ContInvoiceModel inv) onOpenInvoice;
  final Future<void> Function() onPrint;
  final Future<_ContractorAccountRow?> Function() reloadRow;

  const _ContractorAccountDetailScreen({
    required this.row,
    required this.currentUser,
    required this.moneyFmt,
    required this.dateFmt,
    required this.rangeLabel,
    required this.paidLabel,
    required this.paymentsFor,
    required this.paidFor,
    required this.onOpenInvoice,
    required this.onPrint,
    required this.reloadRow,
  });

  @override
  State<_ContractorAccountDetailScreen> createState() =>
      _ContractorAccountDetailScreenState();
}

class _ContractorAccountDetailScreenState
    extends State<_ContractorAccountDetailScreen> {
  bool _printing = false;
  bool _paying = false;
  bool _exportingInvoice = false;
  late _ContractorAccountRow _row;

  @override
  void initState() {
    super.initState();
    _row = widget.row;
  }

  Future<void> _refreshRow() async {
    final updated = await widget.reloadRow();
    if (updated != null && mounted) setState(() => _row = updated);
  }

  Future<void> _print() async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      await widget.onPrint();
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _exportInvoice(ContInvoiceModel inv) async {
    if (!canPrintContInvoiceStatement(inv.status) || _exportingInvoice) return;
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    setState(() => _exportingInvoice = true);
    try {
      var detail = inv;
      if (detail.lines.isEmpty && detail.id != null) {
        detail = await storage.getContInvoiceDetail(
          detail.id!,
          widget.currentUser.id,
        );
      }
      await printContInvoiceStatementPdf(detail);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تصدير المستخلص: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingInvoice = false);
    }
  }

  Future<void> _payInvoice(ContInvoiceModel inv) async {
    if (_paying || !canRecordContInvoicePayment(widget.currentUser, inv)) {
      return;
    }
    final remaining = inv.remainingAmount;
    final dateLabel = inv.statementDate == null
        ? ''
        : widget.dateFmt.format(inv.statementDate!);
    final draft = await showContInvoicePaymentDialog(
      context: context,
      remaining: remaining,
      moneyFmt: widget.moneyFmt,
      invoiceLabel: '${inv.projectName}${dateLabel.isEmpty ? '' : ' — $dateLabel'}',
    );
    if (draft == null || inv.id == null) return;
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    setState(() => _paying = true);
    try {
      await storage.markContInvoicePaid(
        id: inv.id!,
        userId: widget.currentUser.id,
        amount: draft.amount,
        comment: draft.comment,
        attachments: draft.attachments,
      );
      await _refreshRow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الدفعة على هذا المستخلص')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الدفعة: $e')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(row.contractorName),
          actions: [
            IconButton(
              tooltip: 'طباعة الكشف التفصيلي',
              onPressed: _printing ? null : _print,
              icon: const Icon(Icons.print_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.rangeLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.rangeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _line('مستحق', row.due, widget.moneyFmt, bold: true),
                    _line(widget.paidLabel, row.paid, widget.moneyFmt),
                    _line('باقي', row.remaining, widget.moneyFmt, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'المستخلصات والدفعات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'كل مستخلص يتصرف لوحده. أي صرف جزئي أو كلي يلزم مستند الاستلام.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...row.invoices.map((inv) {
              final dateLabel = inv.statementDate == null
                  ? '—'
                  : widget.dateFmt.format(inv.statementDate!);
              final payments = widget.paymentsFor(inv);
              final canPay = canRecordContInvoicePayment(
                widget.currentUser,
                inv,
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        title: Text(inv.projectName),
                        subtitle: Text(
                          'تاريخ المستخلص: $dateLabel  |  ${inv.statusLabelAr}\n'
                          'مستحق هذا المستخلص: ${widget.moneyFmt.format(inv.amountDue)}\n'
                          '${widget.paidLabel}: ${widget.moneyFmt.format(widget.paidFor(inv))}  |  '
                          'باقي هذا المستخلص: ${widget.moneyFmt.format(inv.remainingAmount)}',
                        ),
                        isThreeLine: true,
                        onTap: () async {
                          await widget.onOpenInvoice(inv);
                          await _refreshRow();
                        },
                      ),
                      if (canPrintContInvoiceStatement(inv.status) || canPay)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (canPrintContInvoiceStatement(inv.status))
                                OutlinedButton.icon(
                                  onPressed: _exportingInvoice
                                      ? null
                                      : () => _exportInvoice(inv),
                                  icon: const Icon(
                                    Icons.picture_as_pdf_outlined,
                                  ),
                                  label: const Text('تصدير المستخلص PDF'),
                                ),
                              if (canPay)
                                FilledButton.icon(
                                  onPressed:
                                      _paying ? null : () => _payInvoice(inv),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text(
                                    'تسجيل دفعة على هذا المستخلص',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text('لا توجد دفعات في العرض الحالي'),
                        )
                      else
                        ...payments.map((p) {
                          final files = p.attachments
                              .map((a) => a.fileName)
                              .where((n) => n.trim().isNotEmpty)
                              .join('، ');
                          final when = p.createdAt == null
                              ? '—'
                              : widget.dateFmt.format(p.createdAt!.toLocal());
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text(
                              'دفعة $when: ${widget.moneyFmt.format(p.amount)}'
                              '${p.note.trim().isEmpty ? '' : ' — ${p.note}'}'
                              '${files.isEmpty ? '' : ' — $files'}',
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, double value, NumberFormat fmt, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500),
            ),
          ),
          Text(
            fmt.format(value),
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
