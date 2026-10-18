import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/contractor_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

/// شاشة مؤقتة (Admin): خصومات معلّقة غير مربوطة بمقاول.
class ContInvoicesPendingUnlinkedScreen extends StatefulWidget {
  final UserModel currentUser;

  const ContInvoicesPendingUnlinkedScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ContInvoicesPendingUnlinkedScreen> createState() =>
      _ContInvoicesPendingUnlinkedScreenState();
}

class _ContInvoicesPendingUnlinkedScreenState
    extends State<ContInvoicesPendingUnlinkedScreen> {
  final _storage = getStorage();
  final _moneyFmt = NumberFormat('#,##0.00', 'en_US');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  List<ContractorModel> _contractors = const [];

  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;

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
      if (!_isApi) {
        throw Exception('يتطلب الاتصال بالخادم');
      }
      final results = await Future.wait([
        _api.getContInvoicePendingUnlinked(widget.currentUser.id),
        _api.getContractors(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Map<String, dynamic>>;
        _contractors = results[1] as List<ContractorModel>;
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

  Future<void> _assign(Map<String, dynamic> item) async {
    ContractorModel? picked;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('ربط بمقاول'),
          content: DropdownButtonFormField<ContractorModel>(
            value: picked,
            decoration: const InputDecoration(
              labelText: 'المقاول',
              border: OutlineInputBorder(),
            ),
            items: _contractors
                .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                .toList(),
            onChanged: (v) => setLocal(() => picked = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (picked == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('ربط'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || picked == null) return;
    final idRaw = item['id'];
    final id = idRaw is int
        ? idRaw
        : int.tryParse(idRaw?.toString() ?? '');
    if (id == null) return;
    try {
      await _api.assignContInvoicePendingUnlinked(
        id: id,
        userId: widget.currentUser.id,
        contractorId: picked!.id,
        contractorName: picked!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم الربط بـ ${picked!.name}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الربط: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('خصومات معلّقة غير مربوطة'),
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
                        child: Text('لا توجد خصومات معلّقة غير مربوطة'),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            final amount = (item['amount'] is num)
                                ? (item['amount'] as num).toDouble()
                                : 0.0;
                            final srcName =
                                (item['source_project_name'] ?? '').toString();
                            final fromName = (item['beneficiary_contractor_name'] ??
                                    '')
                                .toString();
                            final desc = (item['description'] ?? '').toString();
                            final dateRaw = item['source_statement_date'];
                            String dateLabel = '—';
                            if (dateRaw != null &&
                                dateRaw.toString().isNotEmpty) {
                              final d = DateTime.tryParse(dateRaw.toString());
                              if (d != null) dateLabel = _dateFmt.format(d);
                            }
                            return Card(
                              child: ListTile(
                                title: Text(
                                  _moneyFmt.format(amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                subtitle: Text(
                                  [
                                    if (desc.isNotEmpty) desc,
                                    if (fromName.isNotEmpty)
                                      'من مقاول: $fromName',
                                    if (srcName.isNotEmpty)
                                      'مشروع المصدر: $srcName',
                                    'تاريخ المصدر: $dateLabel',
                                  ].join('\n'),
                                ),
                                isThreeLine: true,
                                trailing: FilledButton.tonal(
                                  onPressed: () => _assign(item),
                                  child: const Text('ربط'),
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
