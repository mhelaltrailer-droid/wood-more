import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/cont_invoices_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../models/contractor_model.dart';
import '../models/project_model.dart';
import 'cont_invoices_pending_unlinked_screen.dart';
import 'cont_invoices_select_screen.dart';
import 'cont_invoices_work_screen.dart';

class ContInvoicesHubScreen extends StatefulWidget {
  final UserModel currentUser;

  const ContInvoicesHubScreen({super.key, required this.currentUser});

  @override
  State<ContInvoicesHubScreen> createState() => _ContInvoicesHubScreenState();
}

class _ContInvoicesHubScreenState extends State<ContInvoicesHubScreen> {
  final _storage = getStorage();
  final _moneyFmt = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  String? _error;
  List<ContInvoiceModel> _items = const [];
  bool _mineOnly = false;

  bool get _canCreate =>
      isContInvoicesQsEmail(widget.currentUser.email) ||
      widget.currentUser.isPrimaryAppAdmin;

  bool get _canDelete => widget.currentUser.isPrimaryAppAdmin;

  List<ContInvoiceModel> get _visibleItems {
    if (!_mineOnly) return _items;
    final uid = widget.currentUser.id;
    return _items.where((item) {
      if (item.currentAssigneeUserId == uid) return true;
      final email = widget.currentUser.email;
      switch (item.status) {
        case contStatusDraft:
          return isContInvoicesQsEmail(email);
        case contStatusPendingPrice:
          return isContInvoicesAhAminEmail(email);
        case contStatusPendingPm:
          return isContInvoicesPmEmail(email);
        case contStatusPendingOm:
          return isContInvoicesOmEmail(email);
        case contStatusApproved:
          return isContInvoicesAhAminEmail(email);
        default:
          return false;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_storage is! ApiStorageService) {
        throw Exception('Cont-Invoices يتطلب الاتصال بالخادم');
      }
      final list = await _storage.getContInvoices(widget.currentUser.id);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _openForm({ContInvoiceModel? existing}) async {
    final ContInvoiceModel? result;
    if (existing == null) {
      result = await Navigator.of(context).push<ContInvoiceModel>(
        MaterialPageRoute(
          builder: (_) => ContInvoicesSelectScreen(
            currentUser: widget.currentUser,
          ),
        ),
      );
    } else {
      final contractor = ContractorModel(
        id: existing.contractorId ?? 0,
        name: existing.contractorName,
      );
      final project = ProjectModel(
        id: existing.projectId ?? 0,
        name: existing.projectName,
      );
      result = await Navigator.of(context).push<ContInvoiceModel>(
        MaterialPageRoute(
          builder: (_) => ContInvoicesWorkScreen(
            currentUser: widget.currentUser,
            contractor: contractor,
            project: project,
            existing: existing,
          ),
        ),
      );
    }
    if (result != null) {
      await _load();
    }
  }

  Future<void> _delete(ContInvoiceModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المستخلص؟'),
          content: Text(
            'حذف مستخلص «${item.contractorName}» — ${item.projectName}؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || item.id == null) return;
    try {
      await (_storage as ApiStorageService).deleteContInvoice(
        id: item.id!,
        userId: widget.currentUser.id,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحذف: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(contInvoicesHomeLabel),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: _canCreate
            ? FloatingActionButton.extended(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('مستخلص جديد'),
              )
            : null,
        body: Column(
          children: [
            if (widget.currentUser.isAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContInvoicesPendingUnlinkedScreen(
                                currentUser: widget.currentUser,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.link_off),
                        label: const Text('خصومات معلّقة غير مربوطة'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_canCreate)
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('مستخلص جديد'),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilterChip(
                label: const Text('المطلوب مني فقط'),
                selected: _mineOnly,
                onSelected: _loading
                    ? null
                    : (v) => setState(() => _mineOnly = v),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _load,
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _visibleItems.isEmpty
                          ? Center(
                              child: Text(
                                _items.isEmpty
                                    ? 'لا توجد مستخلصات بعد.'
                                    : 'لا توجد مستخلصات في هذا الفلتر.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  _canCreate ? 88 : 16,
                                ),
                                itemCount: _visibleItems.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final item = _visibleItems[i];
                                  final dateLabel = item.statementDate == null
                                      ? '—'
                                      : _dateFmt.format(item.statementDate!);
                                  final statusLabel = item.statusLabelAr.isNotEmpty
                                      ? item.statusLabelAr
                                      : contInvoiceStatusLabelAr(item.status);
                                  final assignee = item.currentAssigneeUserName
                                          .trim()
                                          .isNotEmpty
                                      ? '\nالمكلف: ${item.currentAssigneeUserName}'
                                      : '';
                                  return Card(
                                    child: ListTile(
                                      title: Text(
                                        '${item.contractorName} — ${item.projectName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'تاريخ: $dateLabel  |  إجمالي: ${_moneyFmt.format(item.totalAmount)}\n'
                                        'مستحق: ${_moneyFmt.format(item.amountDue)}  |  الحالة: $statusLabel$assignee',
                                      ),
                                      isThreeLine: true,
                                      onTap: () =>
                                          _openForm(existing: item),
                                      trailing: _canDelete
                                          ? IconButton(
                                              tooltip: 'حذف',
                                              onPressed: () => _delete(item),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
