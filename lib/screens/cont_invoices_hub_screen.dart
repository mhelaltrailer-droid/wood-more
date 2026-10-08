import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/cont_invoices_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import 'cont_invoices_form_screen.dart';

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
      final list = await (_storage as ApiStorageService)
          .getContInvoices(widget.currentUser.id);
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
    final result = await Navigator.of(context).push<ContInvoiceModel>(
      MaterialPageRoute(
        builder: (_) => ContInvoicesFormScreen(
          currentUser: widget.currentUser,
          existing: existing,
        ),
      ),
    );
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('مستخلص جديد'),
        ),
        body: _loading
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
                : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد مستخلصات بعد.\nاضغط «مستخلص جديد» للبدء.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            final dateLabel = item.statementDate == null
                                ? '—'
                                : _dateFmt.format(item.statementDate!);
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
                                  'مستحق: ${_moneyFmt.format(item.amountDue)}  |  حالة: ${item.status}',
                                ),
                                isThreeLine: true,
                                onTap: () => _openForm(existing: item),
                                trailing: IconButton(
                                  tooltip: 'حذف',
                                  onPressed: () => _delete(item),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
