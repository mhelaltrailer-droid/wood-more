import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

/// واجهة المالية: تظهر لمدير مهندسين المواقع ومسؤول التطبيق فقط
/// عرض الرصيد، إضافة عهدة، وتقرير مصروفات لكل مهندس
class FinanceScreen extends StatefulWidget {
  final UserModel currentUser;

  const FinanceScreen({super.key, required this.currentUser});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final _db = getStorage();
  List<UserModel> _engineers = [];
  Map<int, double> _balances = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final engineers = await _db.getSiteEngineers();
    final balances = <int, double>{};
    for (final e in engineers) {
      balances[e.id] = await _db.getEngineerBalance(e.id);
    }
    if (!mounted) return;
    setState(() {
      _engineers = engineers;
      _balances = balances;
      _loading = false;
    });
  }

  Future<void> _showAddCustody() async {
    UserModel? selected;
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إضافة عهدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<UserModel>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'المهندس'),
                  items: _engineers.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                  onChanged: (v) => setDialog(() => selected = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountC,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteC,
                  decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (selected == null) return;
                final amount = double.tryParse(amountC.text.replaceAll(RegExp(r'[^\d.]'), ''));
                if (amount == null || amount <= 0) return;
                Navigator.pop(ctx);
                try {
                  await _db.addCustody(selected!.id, amount, noteC.text.trim());
                  _load();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة العهدة'), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEngineerReport(UserModel engineer) async {
    setState(() => _loading = true);
    final dateTo = DateTime.now();
    final dateFrom = DateTime(dateTo.year - 1, dateTo.month, dateTo.day);
    final reports = await _db.getDailyReports(dateFrom: dateFrom, dateTo: dateTo, userId: engineer.id);
    if (!mounted) return;
    setState(() => _loading = false);
    final lines = <_ExpenseLine>[];
    for (final r in reports) {
      for (final e in r.expenses) {
        final amt = double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        if (e.description.trim().isEmpty && amt == 0) continue;
        lines.add(_ExpenseLine(
          date: r.reportDate,
          description: e.description.trim().isEmpty ? '—' : e.description,
          amount: amt,
        ));
      }
    }
    lines.sort((a, b) => b.date.compareTo(a.date));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقرير مصروفات: ${engineer.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('الرصيد الحالي: ${_balances[engineer.id] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('بيان الصرف وقيمة المبلغ المنصرف:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (lines.isEmpty)
                  const Text('لا توجد مصروفات مسجلة', style: TextStyle(color: Colors.grey))
                else
                  ...lines.map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 95, child: Text('${l.date.year}-${l.date.month.toString().padLeft(2, '0')}-${l.date.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12))),
                            Expanded(child: Text(l.description, maxLines: 2, overflow: TextOverflow.ellipsis)),
                            Text('${l.amount}', style: const TextStyle(fontWeight: FontWeight.w500), textDirection: TextDirection.ltr),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _engineers.length,
              itemBuilder: (context, i) {
                final e = _engineers[i];
                final balance = _balances[e.id] ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('الرصيد الحالي: $balance', textDirection: TextDirection.ltr),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showEngineerReport(e),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCustody,
        icon: const Icon(Icons.add),
        label: const Text('إضافة عهدة'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
    );
  }
}

class _ExpenseLine {
  final DateTime date;
  final String description;
  final double amount;
  _ExpenseLine({required this.date, required this.description, required this.amount});
}
