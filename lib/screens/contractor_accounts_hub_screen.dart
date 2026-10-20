import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/cont_invoices_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/contractor_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import 'cont_invoices_work_screen.dart';

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
  String? _error;
  List<_ContractorAccountRow> _rows = const [];

  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_isApi) throw Exception('يتطلب الاتصال بالخادم');
      final list = await _api.getContInvoices(widget.currentUser.id);
      final posted = list.where(_isPosted).toList();
      final byKey = <String, List<ContInvoiceModel>>{};
      for (final inv in posted) {
        final key = inv.contractorId != null
            ? 'id:${inv.contractorId}'
            : 'name:${inv.contractorName.trim().toLowerCase()}';
        byKey.putIfAbsent(key, () => []).add(inv);
      }
      final rows = byKey.values.map((invoices) {
        final first = invoices.first;
        var due = 0.0;
        var paid = 0.0;
        for (final inv in invoices) {
          due += inv.amountDue;
          paid += inv.paidAmount;
        }
        due = double.parse(due.toStringAsFixed(2));
        paid = double.parse(paid.toStringAsFixed(2));
        return _ContractorAccountRow(
          contractorId: first.contractorId,
          contractorName: first.contractorName,
          due: due,
          paid: paid,
          remaining: double.parse((due - paid).toStringAsFixed(2)),
          invoices: invoices,
        );
      }).toList()
        ..sort((a, b) => b.remaining.compareTo(a.remaining));
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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

  void _openContractor(_ContractorAccountRow row) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ContractorAccountDetailScreen(
          row: row,
          moneyFmt: _moneyFmt,
          dateFmt: _dateFmt,
          onOpenInvoice: _openInvoice,
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
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _sum('إجمالي المستحق', totalDue, bold: true),
                              _sum('إجمالي المصروف', totalPaid),
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
                            ? const Center(child: Text('لا توجد مستحقات معتمدة بعد'))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                                        'مصروف: ${_moneyFmt.format(row.paid)}  |  باقي: ${_moneyFmt.format(row.remaining)}',
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

class _ContractorAccountDetailScreen extends StatelessWidget {
  final _ContractorAccountRow row;
  final NumberFormat moneyFmt;
  final DateFormat dateFmt;
  final Future<void> Function(ContInvoiceModel inv) onOpenInvoice;

  const _ContractorAccountDetailScreen({
    required this.row,
    required this.moneyFmt,
    required this.dateFmt,
    required this.onOpenInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(row.contractorName)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _line('مستحق', row.due, moneyFmt, bold: true),
                    _line('مصروف', row.paid, moneyFmt),
                    _line('باقي', row.remaining, moneyFmt, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'المستخلصات المعتمدة',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...row.invoices.map((inv) {
              final dateLabel = inv.statementDate == null
                  ? '—'
                  : dateFmt.format(inv.statementDate!);
              return Card(
                child: ListTile(
                  title: Text(inv.projectName),
                  subtitle: Text(
                    'تاريخ: $dateLabel  |  ${inv.statusLabelAr}\n'
                    'مستحق: ${moneyFmt.format(inv.amountDue)}  |  '
                    'مصروف: ${moneyFmt.format(inv.paidAmount)}  |  '
                    'باقي: ${moneyFmt.format(inv.remainingAmount)}',
                  ),
                  isThreeLine: true,
                  onTap: () => onOpenInvoice(inv),
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
