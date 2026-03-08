import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import 'package:intl/intl.dart';
import '../models/project_stock_model.dart';
import '../models/project_stock_ledger_model.dart';
import '../models/daily_report_model.dart';
import '../services/storage_service.dart';

/// إدارة مخزن كل مشروع (اسم المخزن = اسم المشروع) — أرصدة الخامات
class AdminProjectStoresScreen extends StatefulWidget {
  final UserModel admin;

  const AdminProjectStoresScreen({super.key, required this.admin});

  @override
  State<AdminProjectStoresScreen> createState() => _AdminProjectStoresScreenState();
}

class _AdminProjectStoresScreenState extends State<AdminProjectStoresScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  List<ProjectStockModel> _list = [];
  List<String> _materials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await _db.getProjects();
    final materials = await _db.getMaterials();
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _materials = materials;
    });
  }

  Future<void> _loadStock() async {
    if (_selectedProject == null) {
      setState(() => _list = []);
      return;
    }
    setState(() => _loading = true);
    final list = await _db.getProjectStock(_selectedProject!.id);
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm([ProjectStockModel? item]) async {
    if (_selectedProject == null) return;
    String? selectedMaterial = (item?.materialName != null && item!.materialName.isNotEmpty && _materials.contains(item.materialName))
        ? item.materialName
        : null;
    final qtyC = TextEditingController(text: item?.quantity ?? '');
    String unit = item?.unit ?? (materialUnits.isNotEmpty ? materialUnits.first : '');
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(item == null ? 'إضافة رصيد لمخزن المشروع' : 'تعديل الرصيد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMaterial,
                  decoration: const InputDecoration(labelText: 'اسم الخامة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— اختر الخامة —')),
                    ..._materials.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setDialog(() => selectedMaterial = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: qtyC, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: materialUnits.contains(unit) ? unit : (materialUnits.isNotEmpty ? materialUnits.first : null),
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                  items: materialUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setDialog(() => unit = v ?? unit),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final name = selectedMaterial?.trim() ?? '';
                final qty = qtyC.text.trim();
                if (name.isEmpty) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('اختر الخامة')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final adminName = widget.admin.name;
                  if (item == null) {
                    await _db.addProjectStock(ProjectStockModel(id: 0, projectId: _selectedProject!.id, materialName: name, quantity: qty, unit: unit));
                    final delta = double.tryParse(qty.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                    if (delta != 0) {
                      try {
                        await _db.addProjectStockLedgerEntry(projectId: _selectedProject!.id, materialName: name, unit: unit, quantityDelta: delta, type: 'add', userName: adminName);
                      } catch (_) { /* سجل الحركات قد لا يكون متاحاً في الخادم القديم */ }
                    }
                  } else {
                    final oldQty = double.tryParse(item.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                    final newQty = double.tryParse(qty.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
                    await _db.updateProjectStock(ProjectStockModel(id: item.id, projectId: item.projectId, materialName: name, quantity: qty, unit: unit));
                    final delta = newQty - oldQty;
                    if (delta != 0) {
                      try {
                        await _db.addProjectStockLedgerEntry(projectId: item.projectId, materialName: name, unit: unit, quantityDelta: delta, type: 'edit', userName: adminName);
                      } catch (_) { /* سجل الحركات قد لا يكون متاحاً */ }
                    }
                  }
                  _loadStock();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLedger(ProjectStockModel s) async {
    if (_selectedProject == null) return;
    final list = await _db.getStockLedger(_selectedProject!.id, s.materialName);
    if (!mounted) return;
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final timeFormat = DateFormat('HH:mm', 'ar');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سجل الرصيد: ${s.materialName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: list.isEmpty
              ? const Text('لا توجد حركات مسجلة لهذه الخامة.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(flex: 2, child: Text('التاريخ والوقت', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                        Expanded(child: Text('النوع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                        Expanded(child: Text('الكمية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                        Expanded(flex: 2, child: Text('اسم المستخدم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700))),
                      ],
                    ),
                    const Divider(height: 16),
                    ...list.map((e) {
                      final typeLabel = e.type == 'add' ? 'إضافة' : e.type == 'edit' ? 'تعديل' : 'سحب (تقرير يومي)';
                      final deltaStr = e.quantityDelta >= 0 ? '+${e.quantityDelta}' : '${e.quantityDelta}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text('${dateFormat.format(e.createdAt)} ${timeFormat.format(e.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ),
                            Expanded(child: Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.w500))),
                            Expanded(child: Text(deltaStr, style: TextStyle(color: e.quantityDelta >= 0 ? Colors.green.shade700 : Colors.red.shade700))),
                            Expanded(flex: 2, child: Text(e.userName, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<void> _delete(ProjectStockModel s) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: Text('حذف "${s.materialName}" من المخزن؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteProjectStock(s.id);
      _loadStock();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مخازن المشاريع (الأرصدة)'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اسم المخزن = اسم المشروع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProjectModel?>(
              value: _selectedProject,
              decoration: const InputDecoration(labelText: 'المشروع / المخزن'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')),
                ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
              ],
              onChanged: (v) {
                setState(() => _selectedProject = v);
                _loadStock();
              },
            ),
            const SizedBox(height: 20),
            if (_selectedProject != null) ...[
              Text('أرصدة مخزن: ${_selectedProject!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else ...[
                ..._list.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(s.materialName),
                    subtitle: Text('${s.quantity} ${s.unit}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.history), onPressed: () => _showLedger(s), tooltip: 'عرض السجل'),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(s), tooltip: 'تعديل'),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(s), tooltip: 'حذف'),
                    ]),
                  ),
                )),
              ],
            ],
          ],
        ),
      ),
      floatingActionButton: _selectedProject == null ? null : FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
