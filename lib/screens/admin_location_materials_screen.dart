import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/location_material_model.dart';
import '../models/daily_report_model.dart';
import '../services/storage_service.dart';

/// إدارة خامات مكان فرعي واحد (للهيكلة المخازن)
class AdminLocationMaterialsScreen extends StatefulWidget {
  final UserModel admin;
  final int locationId;
  final String locationName;

  const AdminLocationMaterialsScreen({
    super.key,
    required this.admin,
    required this.locationId,
    required this.locationName,
  });

  @override
  State<AdminLocationMaterialsScreen> createState() => _AdminLocationMaterialsScreenState();
}

class _AdminLocationMaterialsScreenState extends State<AdminLocationMaterialsScreen> {
  final _db = getStorage();
  List<LocationMaterialModel> _list = [];
  List<String> _materials = [];
  bool _loading = true;
  String _selectedPhase = LocationMaterialModel.phaseFirstFix;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final materials = await _db.getMaterials();
    final list = await _db.getLocationMaterials(
      widget.locationId,
      phase: _selectedPhase,
    );
    if (!mounted) return;
    setState(() {
      _materials = materials;
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm([LocationMaterialModel? item]) async {
    String? selectedMaterial = item != null && _materials.contains(item.materialName) ? item.materialName : null;
    final qtyC = TextEditingController(text: item?.quantity ?? '');
    String unit = item?.unit ?? (materialUnits.isNotEmpty ? materialUnits.first : '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(item == null ? 'إضافة خامة للمكان' : 'تعديل الخامة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMaterial,
                  decoration: const InputDecoration(labelText: 'اسم الخامة'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('— اختر الخامة —')),
                    ..._materials.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1))),
                  ],
                  onChanged: (v) => setDialog(() => selectedMaterial = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyC,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                ),
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
              onPressed: () {
                final name = selectedMaterial?.trim() ?? '';
                if (name.isEmpty) return;
                Navigator.pop(ctx, {'name': name, 'quantity': qtyC.text.trim(), 'unit': unit});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;
    final name = result['name']!;
    final qty = result['quantity'] ?? '';
    final unitVal = result['unit'] ?? (materialUnits.isNotEmpty ? materialUnits.first : '');
    try {
      if (item == null) {
        await _db.addLocationMaterial(LocationMaterialModel(
          id: 0,
          locationId: widget.locationId,
          phase: _selectedPhase,
          materialName: name,
          quantity: qty,
          unit: unitVal,
        ));
      } else {
        await _db.updateLocationMaterial(LocationMaterialModel(
          id: item.id,
          locationId: item.locationId,
          phase: _selectedPhase,
          materialName: name,
          quantity: qty,
          unit: unitVal,
        ));
      }
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete(LocationMaterialModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف "${m.materialName}" من هذا المكان؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.deleteLocationMaterial(m.id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('خامات: ${widget.locationName}'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('First-fix'),
                          selected:
                              _selectedPhase ==
                              LocationMaterialModel.phaseFirstFix,
                          onSelected: (_) {
                            setState(
                              () => _selectedPhase =
                                  LocationMaterialModel.phaseFirstFix,
                            );
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Second-fix'),
                          selected:
                              _selectedPhase ==
                              LocationMaterialModel.phaseSecondFix,
                          onSelected: (_) {
                            setState(
                              () => _selectedPhase =
                                  LocationMaterialModel.phaseSecondFix,
                            );
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _list.length,
                    itemBuilder: (context, i) {
                      final m = _list[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            m.materialName,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${m.quantity} ${m.unit}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showForm(m),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _delete(m),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
        backgroundColor: const Color(0xFF1B5E20),
      ),
    );
  }
}
