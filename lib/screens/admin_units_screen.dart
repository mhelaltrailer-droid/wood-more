import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/zone_model.dart';
import '../models/building_model.dart';
import '../models/unit_model.dart';
import '../services/storage_service.dart';

class AdminUnitsScreen extends StatefulWidget {
  final UserModel admin;
  const AdminUnitsScreen({super.key, required this.admin});

  @override
  State<AdminUnitsScreen> createState() => _AdminUnitsScreenState();
}

class _AdminUnitsScreenState extends State<AdminUnitsScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  List<ZoneModel> _zones = [];
  List<BuildingModel> _buildings = [];
  ProjectModel? _selectedProject;
  ZoneModel? _selectedZone;
  BuildingModel? _selectedBuilding;
  List<UnitModel> _list = [];
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
      setState(() {
        _zones = [];
        _selectedZone = null;
        _buildings = [];
        _selectedBuilding = null;
        _list = [];
      });
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
      setState(() {
        _buildings = [];
        _selectedBuilding = null;
        _list = [];
      });
      return;
    }
    final list = await _db.getBuildings(_selectedZone!.id);
    if (!mounted) return;
    setState(() {
      _buildings = list;
      _selectedBuilding = _buildings.isNotEmpty ? _buildings.first : null;
    });
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    if (_selectedBuilding == null) {
      setState(() => _list = []);
      return;
    }
    setState(() => _loading = true);
    final list = await _db.getUnits(_selectedBuilding!.id);
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  static String _mimeFromExtension(String? path) {
    final ext = path?.split('.').last.toLowerCase() ?? '';
    switch (ext) {
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      default: return 'image/jpeg';
    }
  }

  Future<void> _showForm([UnitModel? item]) async {
    if (_selectedBuilding == null) return;
    final nameC = TextEditingController(text: item?.name ?? '');
    final modelC = TextEditingController(text: item?.model ?? '');
    final imageC = TextEditingController(text: item?.imagePath ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(item == null ? 'إضافة وحدة' : 'تعديل وحدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم الوحدة (مثال: Th1-M01)'), textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                TextField(controller: modelC, decoration: const InputDecoration(labelText: 'النموذج (M01, M02...)'), textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                TextField(controller: imageC, decoration: const InputDecoration(labelText: 'مسار الصورة أو رابط (اختياري)'), maxLines: 2, textDirection: TextDirection.ltr),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('اختيار صورة من الجهاز'),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true, allowMultiple: false);
                    if (result == null || result.files.isEmpty) return;
                    final file = result.files.single;
                    final bytes = file.bytes;
                    if (bytes == null) return;
                    final mime = _mimeFromExtension(file.name);
                    imageC.text = 'data:$mime;base64,${base64Encode(bytes)}';
                    setDialog(() {});
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('تم اختيار: ${file.name}')));
                  },
                ),
              ],
            ),
          ),
          actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              final model = modelC.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (item == null) {
                  await _db.addUnit(UnitModel(id: 0, buildingId: _selectedBuilding!.id, name: name, model: model.isNotEmpty ? model : name, imagePath: imageC.text.trim().isEmpty ? null : imageC.text.trim()));
                } else {
                  await _db.updateUnit(UnitModel(id: item.id, buildingId: item.buildingId, name: name, model: model.isNotEmpty ? model : name, imagePath: imageC.text.trim().isEmpty ? null : imageC.text.trim()));
                }
                _loadUnits();
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

  Future<void> _delete(UnitModel u) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: Text('حذف ${u.name}؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteUnit(u.id);
      _loadUnits();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الوحدات'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ProjectModel?>(
              value: _selectedProject,
              decoration: const InputDecoration(labelText: 'المشروع'),
              items: [const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')), ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name)))],
              onChanged: (v) {
                setState(() {
                  _selectedProject = v;
                  _zones = [];
                  _selectedZone = null;
                  _buildings = [];
                  _selectedBuilding = null;
                  _list = [];
                });
                _loadZones();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ZoneModel?>(value: _selectedZone, decoration: const InputDecoration(labelText: 'المنطقة'), items: [const DropdownMenuItem(value: null, child: Text('— اختر المنطقة —')), ..._zones.map((z) => DropdownMenuItem(value: z, child: Text(z.name)))], onChanged: (v) { setState(() { _selectedZone = v; _buildings = []; _selectedBuilding = null; _list = []; }); _loadBuildings(); }),
            const SizedBox(height: 12),
            DropdownButtonFormField<BuildingModel?>(value: _selectedBuilding, decoration: const InputDecoration(labelText: 'المبنى'), items: [const DropdownMenuItem(value: null, child: Text('— اختر المبنى —')), ..._buildings.map((b) => DropdownMenuItem(value: b, child: Text(b.name)))], onChanged: (v) { setState(() => _selectedBuilding = v); _loadUnits(); }),
            const SizedBox(height: 20),
            if (_selectedBuilding != null) ...[
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              if (!_loading) ..._list.map((u) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(u.name),
                  subtitle: Text('Model: ${u.model}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(u)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(u)),
                  ]),
                ),
              )),
            ],
          ],
        ),
      ),
      floatingActionButton: _selectedBuilding == null ? null : FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
