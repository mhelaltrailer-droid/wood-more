import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/zone_model.dart';
import '../models/building_model.dart';
import '../services/storage_service.dart';

class AdminBuildingsScreen extends StatefulWidget {
  final UserModel admin;

  const AdminBuildingsScreen({super.key, required this.admin});

  @override
  State<AdminBuildingsScreen> createState() => _AdminBuildingsScreenState();
}

class _AdminBuildingsScreenState extends State<AdminBuildingsScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  List<ZoneModel> _zones = [];
  ProjectModel? _selectedProject;
  ZoneModel? _selectedZone;
  List<BuildingModel> _list = [];
  bool _loading = true;

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

  Future<void> _loadZones() async {
    if (_selectedProject == null) {
      setState(() => _zones = []);
      return;
    }
    final list = await _db.getZones(_selectedProject!.id);
    if (!mounted) return;
    setState(() {
      _zones = list;
      _selectedZone = _zones.isNotEmpty ? _zones.first : null;
    });
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    if (_selectedZone == null) {
      setState(() => _list = []);
      return;
    }
    setState(() => _loading = true);
    final list = await _db.getBuildings(_selectedZone!.id);
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm([BuildingModel? item]) async {
    if (_selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر مشروعاً ومنطقة أولاً')));
      return;
    }
    final nameC = TextEditingController(text: item?.name ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة مبنى' : 'تعديل مبنى'),
        content: TextField(
          controller: nameC,
          decoration: const InputDecoration(labelText: 'اسم المبنى *'),
          textDirection: TextDirection.ltr,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (item == null) {
                  await _db.addBuilding(BuildingModel(id: 0, zoneId: _selectedZone!.id, name: name));
                } else {
                  await _db.updateBuilding(BuildingModel(id: item.id, zoneId: item.zoneId, name: name, storageInfo: item.storageInfo, modelDetails: item.modelDetails, cutList: item.cutList));
                }
                _loadBuildings();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ'), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildingModel b) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: Text('حذف "${b.name}"؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteBuilding(b.id);
      _loadBuildings();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المباني'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ProjectModel?>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'المشروع'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')),
              ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
            ],
            onChanged: (v) {
              setState(() {
                _selectedProject = v;
                _zones = [];
                _selectedZone = null;
                _list = [];
              });
              _loadZones();
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ZoneModel?>(
            value: _selectedZone,
            decoration: const InputDecoration(labelText: 'المنطقة'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— اختر المنطقة —')),
              ..._zones.map((z) => DropdownMenuItem(value: z, child: Text(z.name))),
            ],
            onChanged: (v) {
              setState(() => _selectedZone = v);
              _loadBuildings();
            },
          ),
          const SizedBox(height: 16),
          if (_selectedZone != null) ...[
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else
              ..._list.map((b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(b.name),
                  subtitle: null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(b)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(b)),
                  ]),
                ),
              )),
          ],
        ],
      ),
      floatingActionButton: _selectedZone == null ? null : FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
