import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// الخطوة 3: الماليات (4 صفوف) + زر الحفظ
class DailyReportStep3Screen extends StatefulWidget {
  final UserModel user;
  final DailyReportData report;

  const DailyReportStep3Screen({super.key, required this.user, required this.report});

  @override
  State<DailyReportStep3Screen> createState() => _DailyReportStep3ScreenState();
}

class _DailyReportStep3ScreenState extends State<DailyReportStep3Screen> {
  final _db = getStorage();
  bool _saving = false;

  void _save() async {
    setState(() => _saving = true);
    try {
      await _db.addDailyReport(widget.report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ التقرير اليومي بنجاح'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.user)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير اليومي - الماليات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'بيان الصرف وقيمة المبلغ (4 بنود)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(4, (i) => _ExpenseRow(
                index: i + 1,
                item: widget.report.expenses[i],
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF1B5E20),
            ),
            child: _saving
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('حفظ التقرير'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final int index;
  final ExpenseItem item;
  final VoidCallback onChanged;

  const _ExpenseRow({required this.index, required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('بيان الصرف رقم $index', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.description,
              decoration: const InputDecoration(
                labelText: 'البيان',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                item.description = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: item.amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'قيمة المبلغ المنصرف',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                item.amount = v;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
