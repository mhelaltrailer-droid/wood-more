import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/project_location_model.dart';
import '../models/location_material_model.dart';
import '../models/location_withdrawal_model.dart';
import '../services/storage_service.dart';

/// المخزن (سحب الخامات) — لمسؤول التطبيق: إلغاء السحب واسترجاع المخزن لإعادة السحب أو بعد كميات تكميلية.
class AdminWarehouseWithdrawScreen extends StatefulWidget {
  final UserModel admin;

  const AdminWarehouseWithdrawScreen({super.key, required this.admin});

  @override
  State<AdminWarehouseWithdrawScreen> createState() => _AdminWarehouseWithdrawScreenState();
}

class _AdminWarehouseWithdrawScreenState extends State<AdminWarehouseWithdrawScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  List<ProjectLocationModel> _allLocations = [];
  Map<int, List<LocationMaterialModel>> _materialsByLocation = {};
  Map<int, LocationWithdrawalModel?> _withdrawalByLocation = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final list = await _db.getProjects();
    if (!mounted) return;
    setState(() => _projects = list);
  }

  Future<void> _loadLocationsAndMaterials() async {
    if (_selectedProject == null) {
      setState(() {
        _allLocations = [];
        _materialsByLocation = {};
        _withdrawalByLocation = {};
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final projectId = _selectedProject!.id;
      final results = await Future.wait<dynamic>([
        _db.getProjectLocations(projectId),
        _db.getLocationMaterialsForProject(projectId),
        _db.getLocationWithdrawalsForProject(projectId),
      ]);
      final locations = results[0] as List<ProjectLocationModel>;
      final allMaterials = results[1] as List<LocationMaterialModel>;
      final withdrawals = results[2] as List<LocationWithdrawalModel>;
      final Map<int, List<LocationMaterialModel>> materialsByLoc = {};
      for (final material in allMaterials) {
        materialsByLoc.putIfAbsent(material.locationId, () => []).add(material);
      }
      final Map<int, LocationWithdrawalModel?> withdrawalByLoc = {
        for (final withdrawal in withdrawals)
          withdrawal.locationId: withdrawal,
      };
      if (!mounted) return;
      setState(() {
        _allLocations = locations;
        _materialsByLocation = materialsByLoc;
        _withdrawalByLocation = withdrawalByLoc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحميل: $e'), backgroundColor: Colors.red));
    }
  }

  List<ProjectLocationModel> _locationsWithMaterials() {
    return _allLocations.where((loc) => (_materialsByLocation[loc.id] ?? []).isNotEmpty).toList();
  }

  String _locationPath(ProjectLocationModel loc) {
    final path = <String>[loc.name];
    var current = loc;
    while (current.parentId != null) {
      final parents = _allLocations.where((e) => e.id == current.parentId).toList();
      if (parents.isEmpty) break;
      final parent = parents.first;
      path.insert(0, parent.name);
      current = parent;
    }
    return path.join(' / ');
  }

  Future<void> _confirmCancelWithdraw(ProjectLocationModel loc, LocationWithdrawalModel withdrawal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء السحب؟'),
        content: Text(
          'سيتم حذف عملية السحب المسجلة لـ "${withdrawal.userName}" من قاعدة البيانات، واسترجاع الكميات المخصومة إلى مخزن المشروع، وإزالة حركات السحب من السجل — كأن السحب لم يتم. يمكن بعدها لمهندس الموقع إعادة السحب (بما في ذلك أي كميات تكميلية أضيفت في هيكلة المخزن).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _db.deleteLocationWithdrawal(loc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء السحب واسترجاع المخزن'), backgroundColor: Colors.green),
      );
      await _loadLocationsAndMaterials();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.admin.canManageWarehouseWithdrawalReset) {
      return Scaffold(
        appBar: AppBar(title: const Text('المخزن (سحب الخامات)'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
        body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('هذه الصلاحية غير مفعّلة لهذا الحساب.'))),
      );
    }

    final locationsWithMats = _locationsWithMaterials();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزن (سحب الخامات)'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('صلاحية مسؤول التطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '• إذا زيدت كميات الخامات في «هيكلة المخازن» بعد أن سحب المهندس، تبقى الخامات التكميلية ظاهرة لكن لا يمكن سحبها مرة ثانية حتى تُلغى عملية السحب السابقة من هنا.\n'
                    '• بعد «إلغاء السحب» يعود الوضع كما لو لم يُسحب، فيمكن إعادة السحب بالكميات الحالية.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade900),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('المسؤول: ${widget.admin.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectModel?>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'اسم المشروع', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')),
              ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
            ],
            onChanged: (v) {
              setState(() => _selectedProject = v);
              _loadLocationsAndMaterials();
            },
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_selectedProject != null && locationsWithMats.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('لا توجد أماكن فرعية لها خامات معينة في هذا المشروع.')),
              ),
            )
          else if (_selectedProject != null)
            ...locationsWithMats.map((loc) {
              final materials = _materialsByLocation[loc.id] ?? [];
              final withdrawal = _withdrawalByLocation[loc.id];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_locationPath(loc), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('الخامات المعينة للموقع:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...materials.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(m.materialName, overflow: TextOverflow.ellipsis)),
                                Text('${m.quantity} ${m.unit}', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                              ],
                            ),
                          )),
                      const SizedBox(height: 12),
                      if (withdrawal != null) ...[
                        Text(
                          'تم السحب من طرف "${withdrawal.userName}" في ${withdrawal.createdAt.year}/${withdrawal.createdAt.month.toString().padLeft(2, '0')}/${withdrawal.createdAt.day} ${withdrawal.createdAt.hour.toString().padLeft(2, '0')}:${withdrawal.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.restore),
                          label: const Text('إلغاء السحب واسترجاع المخزن'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade900),
                          onPressed: () => _confirmCancelWithdraw(loc, withdrawal),
                        ),
                      ] else
                        Text('لم يُسحب من هذا الموقع بعد.', style: TextStyle(fontSize: 13, color: Colors.green.shade800)),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
