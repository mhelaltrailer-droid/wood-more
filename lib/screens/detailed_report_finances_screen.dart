import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/detailed_report_model.dart';
import '../models/daily_report_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

const int _kMaxExpenseItems = 4;

/// التقرير المفصل - الماليات: بنود صرف تُضاف تباعاً (حتى 4) وخصم الرصيد كما سابقاً.
class DetailedReportFinancesScreen extends StatefulWidget {
  final UserModel user;
  final DetailedReportModel report;

  const DetailedReportFinancesScreen({super.key, required this.user, required this.report});

  @override
  State<DetailedReportFinancesScreen> createState() => _DetailedReportFinancesScreenState();
}

class _DetailedReportFinancesScreenState extends State<DetailedReportFinancesScreen> {
  final _db = getStorage();
  bool _saving = false;
  late List<ExpenseItem> _expenses;

  static bool _expenseHasContent(ExpenseItem e) {
    final a = double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    return e.description.trim().isNotEmpty || a != 0 || (e.imagePath != null && e.imagePath!.trim().isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.report.expenses.where(_expenseHasContent).take(_kMaxExpenseItems).toList();
    if (existing.isEmpty) {
      _expenses = [ExpenseItem()];
    } else {
      _expenses = existing
          .map((e) => ExpenseItem(description: e.description, amount: e.amount, imagePath: e.imagePath))
          .toList();
    }
  }

  List<ExpenseItem> _collectForSave() {
    return _expenses.where(_expenseHasContent).toList();
  }

  Future<void> _save() async {
    final toSave = _collectForSave();
    if (toSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أضف بند صرف واحداً على الأقل (بيان أو مبلغ أو مرفق)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final existingId = widget.report.id;
      if (existingId != null) {
        await _db.patchDetailedReportExpenses(
          reportId: existingId,
          userId: widget.report.userId,
          expenses: toSave,
        );
      } else {
        final reportWithExpenses = DetailedReportModel(
          userId: widget.report.userId,
          userName: widget.report.userName,
          reportDatetime: widget.report.reportDatetime,
          projectId: widget.report.projectId,
          projectName: widget.report.projectName,
          supervisorId: widget.report.supervisorId,
          createdAt: widget.report.createdAt,
          summary: widget.report.summary,
          lines: widget.report.lines,
          expenses: toSave,
          attachments: widget.report.attachments,
        );
        await _db.addDetailedReport(reportWithExpenses);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingId != null ? 'تم حفظ التقرير المالي بنجاح' : 'تم حفظ التقرير المفصل بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      await saveLastRoute('home');
      if (!mounted) return;
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

  void _addRow() {
    if (_expenses.length >= _kMaxExpenseItems) return;
    setState(() => _expenses.add(ExpenseItem()));
  }

  void _removeRow(int index) {
    if (_expenses.length <= 1) return;
    setState(() => _expenses.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير المفصل - الماليات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'أدخل بند الصرف ثم أضف المزيد عند الحاجة (حتى $_kMaxExpenseItems بنود). بيان المبلغ وإرفاق صورة اختياري لكل بند.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(_expenses.length, (i) {
            return _ExpenseRow(
              index: i + 1,
              item: _expenses[i],
              canRemove: _expenses.length > 1,
              onRemove: () => _removeRow(i),
              onChanged: () => setState(() {}),
            );
          }),
          if (_expenses.length < _kMaxExpenseItems) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: const Text('إضافة بند صرف'),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF1B5E20),
            ),
            child: _saving
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('حفظ التقرير المالي'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final int index;
  final ExpenseItem item;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ExpenseRow({
    required this.index,
    required this.item,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  static String _mimeFromExtension(String? path) {
    final ext = path?.split('.').last.toLowerCase() ?? '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pickImage(BuildContext context, VoidCallback onChanged) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) return;
      final mime = _mimeFromExtension(file.name);
      item.imagePath = 'data:$mime;base64,${base64Encode(bytes)}';
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرفاق صورة: ${file.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('بند الصرف $index', style: const TextStyle(fontWeight: FontWeight.bold))),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onRemove,
                    tooltip: 'حذف البند',
                  ),
              ],
            ),
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library, size: 20),
              label: Text(item.imagePath != null && item.imagePath!.isNotEmpty ? 'تم إرفاق صورة' : 'إرفاق صورة (إن وجد)'),
              onPressed: () => _pickImage(context, onChanged),
            ),
            if (item.imagePath != null && item.imagePath!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.imagePath!.startsWith('data:') || item.imagePath!.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imagePath!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.image, size: 64),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      item.imagePath = null;
                      onChanged();
                    },
                    tooltip: 'إزالة الصورة',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
