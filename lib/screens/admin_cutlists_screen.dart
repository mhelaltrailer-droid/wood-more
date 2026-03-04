import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/zone_model.dart';
import '../models/building_model.dart';
import '../models/building_cutlist_model.dart';
import '../services/storage_service.dart';

/// إدارة القطعيات: يمكن إضافة أكثر من صورة لكل مبنى (يطلع عليها مهندس الموقع لاحقاً)
class AdminCutlistsScreen extends StatefulWidget {
  final UserModel admin;

  const AdminCutlistsScreen({super.key, required this.admin});

  @override
  State<AdminCutlistsScreen> createState() => _AdminCutlistsScreenState();
}

class _AdminCutlistsScreenState extends State<AdminCutlistsScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  List<ZoneModel> _zones = [];
  List<BuildingModel> _buildings = [];
  ProjectModel? _selectedProject;
  ZoneModel? _selectedZone;
  BuildingModel? _selectedBuilding;
  List<BuildingCutlistModel> _list = [];
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
    if (_selectedProject == null) { setState(() { _zones = []; _selectedZone = null; _buildings = []; _selectedBuilding = null; _list = []; }); return; }
    final list = await _db.getZones(_selectedProject!.id);
    if (!mounted) return;
    setState(() { _zones = list; _selectedZone = _zones.isNotEmpty ? _zones.first : null; });
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    if (_selectedZone == null) { setState(() { _buildings = []; _selectedBuilding = null; _list = []; }); return; }
    final list = await _db.getBuildings(_selectedZone!.id);
    if (!mounted) return;
    setState(() { _buildings = list; _selectedBuilding = _buildings.isNotEmpty ? _buildings.first : null; });
    _loadList();
  }

  Future<void> _loadList() async {
    if (_selectedBuilding == null) { setState(() => _list = []); return; }
    setState(() => _loading = true);
    final list = await _db.getBuildingCutlists(_selectedBuilding!.id);
    if (!mounted) return;
    setState(() { _list = list; _loading = false; });
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

  Future<void> _showAddForm() async {
    if (_selectedBuilding == null) return;
    final imageC = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إضافة صورة قطعيات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: imageC, decoration: const InputDecoration(labelText: 'مسار الصورة أو رابط (أو اختر من الجهاز)'), maxLines: 2, textDirection: TextDirection.ltr),
              const SizedBox(height: 12),
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final path = imageC.text.trim();
                if (path.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _db.addBuildingCutlist(BuildingCutlistModel(id: 0, buildingId: _selectedBuilding!.id, imagePath: path));
                  _loadList();
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

  Future<void> _delete(BuildingCutlistModel c) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: const Text('حذف صورة القطعيات؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteBuildingCutlist(c.id);
      _loadList();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة القطعيات'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ProjectModel?>(value: _selectedProject, decoration: const InputDecoration(labelText: 'المشروع'), items: [const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')), ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name)))], onChanged: (v) { setState(() { _selectedProject = v; _zones = []; _selectedZone = null; _buildings = []; _selectedBuilding = null; _list = []; }); _loadZones(); }),
            const SizedBox(height: 12),
            DropdownButtonFormField<ZoneModel?>(value: _selectedZone, decoration: const InputDecoration(labelText: 'المنطقة'), items: [const DropdownMenuItem(value: null, child: Text('— اختر المنطقة —')), ..._zones.map((z) => DropdownMenuItem(value: z, child: Text(z.name)))], onChanged: (v) { setState(() { _selectedZone = v; _buildings = []; _selectedBuilding = null; _list = []; }); _loadBuildings(); }),
            const SizedBox(height: 12),
            DropdownButtonFormField<BuildingModel?>(value: _selectedBuilding, decoration: const InputDecoration(labelText: 'المبنى'), items: [const DropdownMenuItem(value: null, child: Text('— اختر المبنى —')), ..._buildings.map((b) => DropdownMenuItem(value: b, child: Text(b.name)))], onChanged: (v) { setState(() => _selectedBuilding = v); _loadList(); }),
            const SizedBox(height: 8),
            Text('يمكن إضافة أكثر من صورة للقطعيات بالضغط على زر +', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            if (_selectedBuilding != null) ...[
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else ..._list.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: (c.imagePath.startsWith('http') || c.imagePath.startsWith('data:')) ? Image.network(c.imagePath, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)) : const Icon(Icons.image),
                  title: const Text('صورة قطعيات'),
                  subtitle: Text(c.imagePath.length > 50 ? '${c.imagePath.substring(0, 50)}...' : c.imagePath, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(c)),
                ),
              )),
            ],
          ],
        ),
      ),
      floatingActionButton: _selectedBuilding == null ? null : FloatingActionButton(onPressed: _showAddForm, child: const Icon(Icons.add_photo_alternate), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
