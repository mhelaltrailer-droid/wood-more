import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import '../services/route_persistence.dart';
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
            'بيان الصرف وقيمة المبلغ وإرفاق صورة إن وجد (4 بنود)',
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

  static String _mimeFromExtension(String? path) {
    final ext = path?.split('.').last.toLowerCase() ?? '';
    switch (ext) {
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      default: return 'image/jpeg';
    }
  }

  Future<void> _pickImage(BuildContext context, VoidCallback onChanged) async {
    try {
      final result = await FilePicker.platform.pickFiles(
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
                        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 64),
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
