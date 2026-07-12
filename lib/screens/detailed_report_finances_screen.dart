import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/detailed_report_model.dart';
import '../models/daily_report_model.dart';
import '../models/project_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

const int _kMaxExpenseItems = 4;

/// العهدة والمصروفات: بنود صرف تُضاف تباعاً (حتى 4).
/// مهندس الموقع يرسل للاعتماد؛ مدير المشروعات يحفظ معتمداً مباشرة.
class DetailedReportFinancesScreen extends StatefulWidget {
  final UserModel user;
  final DetailedReportModel report;
  final bool showProjectSelector;

  /// إن true: المشروع اختياري والحفظ معتمد فوراً مع خصم رصيد المُدخل.
  final bool autoApprove;

  /// إن true: المشروع إجباري عند إظهار منتقي المشروع.
  final bool projectRequired;

  final String submitButtonLabel;

  const DetailedReportFinancesScreen({
    super.key,
    required this.user,
    required this.report,
    this.showProjectSelector = false,
    this.autoApprove = false,
    this.projectRequired = true,
    this.submitButtonLabel = 'ارسال لمدير المشروعات',
  });

  /// فتح مباشر من أيقونة «العهدة/المصروفات» بدون خطة عمل.
  factory DetailedReportFinancesScreen.directEntry({required UserModel user}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DetailedReportFinancesScreen(
      user: user,
      showProjectSelector: true,
      projectRequired: true,
      autoApprove: false,
      submitButtonLabel: 'ارسال لمدير المشروعات',
      report: DetailedReportModel(
        userId: user.id,
        userName: user.name,
        reportDatetime: today,
      ),
    );
  }

  /// إدخال مباشر من مدير المشروعات — معتمد فوراً وخصم من رصيده.
  factory DetailedReportFinancesScreen.managerDirectEntry({required UserModel user}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DetailedReportFinancesScreen(
      user: user,
      showProjectSelector: true,
      projectRequired: false,
      autoApprove: true,
      submitButtonLabel: 'تأكيد/حفظ',
      report: DetailedReportModel(
        userId: user.id,
        userName: user.name,
        reportDatetime: today,
      ),
    );
  }

  @override
  State<DetailedReportFinancesScreen> createState() => _DetailedReportFinancesScreenState();
}

class _DetailedReportFinancesScreenState extends State<DetailedReportFinancesScreen> {
  final _db = getStorage();
  bool _saving = false;
  bool _loadingProjects = true;
  bool _loadingBalance = true;
  late List<ExpenseItem> _expenses;
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  double _balance = 0;

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
    _loadBalance();
    if (widget.showProjectSelector) {
      _loadProjects();
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _db.getEngineerBalance(widget.user.id);
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _loadingBalance = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _db.getProjects();
      ProjectModel? selected;
      final reportProjectId = widget.report.projectId;
      if (reportProjectId != null) {
        for (final p in projects) {
          if (p.id == reportProjectId) {
            selected = p;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _selectedProject = selected;
        _loadingProjects = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  List<ExpenseItem> _collectForSave() {
    return _expenses.where(_expenseHasContent).toList();
  }

  Future<void> _save() async {
    if (widget.showProjectSelector &&
        widget.projectRequired &&
        _selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المشروع'), backgroundColor: Colors.orange),
      );
      return;
    }
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
      final projectId = widget.showProjectSelector
          ? _selectedProject?.id
          : widget.report.projectId;
      final projectName = widget.showProjectSelector
          ? _selectedProject?.name
          : widget.report.projectName;

      await _db.createExpenseStatements(
        userId: widget.user.id,
        projectId: projectId,
        projectName: projectName,
        expenses: toSave,
        autoApprove: widget.autoApprove,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.autoApprove
                ? 'تم حفظ بيان الصرف وخصم الرصيد'
                : 'تم إرسال بيان الصرف لمدير المشروعات',
          ),
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
    final projectLabel = widget.projectRequired ? 'اسم المشروع *' : 'اسم المشروع (اختياري)';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.autoApprove ? 'ادخال بيان صرف' : 'العهدة و المصروفات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.showProjectSelector)
            Align(
              alignment: Alignment.centerLeft,
              child: _loadingBalance
                  ? const Text('جاري تحميل الرصيد...')
                  : Text(
                      '${widget.user.name} (رصيدك الحالي : ${_balance.toStringAsFixed(2)})',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
            ),
          if (widget.showProjectSelector) const SizedBox(height: 16),
          if (widget.showProjectSelector) ...[
            if (_loadingProjects)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (_projects.isEmpty)
              const Text('لا توجد مشاريع متاحة', style: TextStyle(color: Colors.red))
            else
              DropdownButtonFormField<ProjectModel?>(
                value: _selectedProject,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: projectLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  if (!widget.projectRequired)
                    const DropdownMenuItem<ProjectModel?>(
                      value: null,
                      child: Text('— بدون مشروع —'),
                    ),
                  ..._projects.map(
                    (p) => DropdownMenuItem<ProjectModel?>(value: p, child: Text(p.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedProject = v),
              ),
            const SizedBox(height: 16),
          ],
          Text(
            widget.autoApprove
                ? 'أدخل بند الصرف ثم أضف المزيد عند الحاجة (حتى $_kMaxExpenseItems بنود). يُحفظ معتمداً ويُخصم من رصيدك مباشرة.'
                : 'أدخل بند الصرف ثم أضف المزيد عند الحاجة (حتى $_kMaxExpenseItems بنود). لن يُخصم من رصيدك إلا بعد اعتماد مدير المشروعات.',
            style: const TextStyle(fontWeight: FontWeight.bold),
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
                : Text(widget.submitButtonLabel),
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
