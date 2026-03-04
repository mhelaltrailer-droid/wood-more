import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/zone_model.dart';
import '../models/building_model.dart';
import '../models/building_material_model.dart';
import '../models/building_cutlist_model.dart';
import '../models/unit_model.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// واجهة المشروعات لمهندس الموقع: مشروع → منطقة → مبنى → (التشوينات / النماذج / القطعيات)
class EngineerProjectsScreen extends StatefulWidget {
  final UserModel user;

  const EngineerProjectsScreen({super.key, required this.user});

  @override
  State<EngineerProjectsScreen> createState() => _EngineerProjectsScreenState();
}

class _EngineerProjectsScreenState extends State<EngineerProjectsScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  List<ZoneModel> _zones = [];
  List<BuildingModel> _buildings = [];
  List<BuildingMaterialModel> _materials = [];
  List<BuildingCutlistModel> _cutlists = [];
  List<UnitModel> _units = [];

  ProjectModel? _selectedProject;
  ZoneModel? _selectedZone;
  BuildingModel? _selectedBuilding;
  UnitModel? _selectedUnit;

  String _choice = ''; // 'storage' | 'units' | 'cutlist'
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

  Future<void> _loadZones() async {
    if (_selectedProject == null) {
      setState(() { _zones = []; _selectedZone = null; _buildings = []; _selectedBuilding = null; _choice = ''; });
      return;
    }
    final list = await _db.getZones(_selectedProject!.id);
    if (!mounted) return;
    setState(() { _zones = list; _selectedZone = _zones.isNotEmpty ? _zones.first : null; });
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    if (_selectedZone == null) {
      setState(() { _buildings = []; _selectedBuilding = null; _choice = ''; });
      return;
    }
    final list = await _db.getBuildings(_selectedZone!.id);
    if (!mounted) return;
    setState(() { _buildings = list; _selectedBuilding = _buildings.isNotEmpty ? _buildings.first : null; _choice = ''; });
    if (_selectedBuilding != null) _onBuildingChanged();
  }

  Future<void> _onBuildingChanged() async {
    setState(() => _choice = '');
    if (_selectedBuilding == null) return;
    setState(() => _loading = true);
    try {
      final materials = await _db.getBuildingMaterials(_selectedBuilding!.id);
      final cutlists = await _db.getBuildingCutlists(_selectedBuilding!.id);
      final units = await _db.getUnits(_selectedBuilding!.id);
      if (!mounted) return;
      setState(() {
        _materials = materials;
        _cutlists = cutlists;
        _units = units;
        _selectedUnit = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildImageSource(String path) {
    if (path.startsWith('http') || path.startsWith('data:')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
      );
    }
    return const Icon(Icons.image, size: 48);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المشروعات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.user)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<ProjectModel?>(
              value: _selectedProject,
              decoration: const InputDecoration(labelText: 'المشروع', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')),
                ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedProject = v;
                  _zones = [];
                  _selectedZone = null;
                  _buildings = [];
                  _selectedBuilding = null;
                  _choice = '';
                });
                _loadZones();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ZoneModel?>(
              value: _selectedZone,
              decoration: const InputDecoration(labelText: 'المنطقة', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('— اختر المنطقة —')),
                ..._zones.map((z) => DropdownMenuItem(value: z, child: Text(z.name))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedZone = v;
                  _buildings = [];
                  _selectedBuilding = null;
                  _choice = '';
                });
                _loadBuildings();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BuildingModel?>(
              value: _selectedBuilding,
              decoration: const InputDecoration(labelText: 'المبنى', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('— اختر المبنى —')),
                ..._buildings.map((b) => DropdownMenuItem(value: b, child: Text(b.name))),
              ],
              onChanged: (v) {
                setState(() => _selectedBuilding = v);
                _onBuildingChanged();
              },
            ),
            if (_selectedBuilding != null) ...[
              const SizedBox(height: 24),
              Card(
                color: const Color(0xFF1B5E20).withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'المبنى: ${_selectedBuilding!.name}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'البيانات المعروضة أدناه مسجلة من لوحة تحكم مسؤول التطبيق (إدارة التشوينات، القطعيات، الوحدات).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              const Text('اختر ما تريد عرضه:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _choiceCard(
                      title: 'التشوينات',
                      icon: Icons.inventory_2,
                      onTap: () => setState(() => _choice = 'storage'),
                      selected: _choice == 'storage',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _choiceCard(
                      title: 'النماذج',
                      icon: Icons.door_front_door,
                      onTap: () => setState(() => _choice = 'units'),
                      selected: _choice == 'units',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _choiceCard(
                      title: 'القطعيات',
                      icon: Icons.photo_library,
                      onTap: () => setState(() => _choice = 'cutlist'),
                      selected: _choice == 'cutlist',
                    ),
                  ),
                ],
              ),
            ],
            if (_choice.isNotEmpty && _selectedBuilding != null) ...[
              const SizedBox(height: 20),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_choice == 'storage') ...[
                Text('تشوينات المبنى "${_selectedBuilding!.name}" (من إدارة التشوينات)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('الخامة • الطول • عدد القطعة • إجمالي الطول • إجمالي المساحة • الصور المرفقة', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                if (_materials.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد تشوينات مسجلة لهذا المبنى من لوحة التحكم.')))
                else
                  ..._materials.map((m) {
                    final parts = <String>[];
                    if (m.length.isNotEmpty) parts.add('الطول: ${m.length}');
                    if (m.piecesCount.isNotEmpty) parts.add('عدد القطعة: ${m.piecesCount}');
                    if (m.totalLength.isNotEmpty) parts.add('إجمالي الطول: ${m.totalLength}');
                    if (m.totalArea.isNotEmpty) parts.add('إجمالي المساحة: ${m.totalArea}');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: (m.imagePath != null && m.imagePath!.isNotEmpty && (m.imagePath!.startsWith('http') || m.imagePath!.startsWith('data:')))
                            ? Image.network(m.imagePath!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2))
                            : const Icon(Icons.inventory_2),
                        title: Text(m.materialName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(parts.isEmpty ? '—' : parts.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          if (m.imagePath != null && m.imagePath!.isNotEmpty) _showFullImage(m.imagePath!, m.materialName);
                        },
                      ),
                    );
                  }),
              ] else if (_choice == 'cutlist') ...[
                Text('صور قطعيات المبنى "${_selectedBuilding!.name}" (من إدارة القطعيات)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_cutlists.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد صور قطعيات مسجلة لهذا المبنى من لوحة التحكم.')))
                else
                  ..._cutlists.map((c) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: (c.imagePath.startsWith('http') || c.imagePath.startsWith('data:'))
                              ? Image.network(c.imagePath, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
                              : const Icon(Icons.image),
                          title: const Text('صورة قطعيات (مسجلة من مسؤول التطبيق)'),
                          onTap: () => _showFullImage(c.imagePath, 'قطعيات - ${_selectedBuilding!.name}'),
                        ),
                      )),
              ] else if (_choice == 'units') ...[
                Text('نماذج المبنى "${_selectedBuilding!.name}" (من إدارة الوحدات)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('اختر النموذج (مثل TH1-M01، TH1-M02) لعرض صورته.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                if (_units.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد نماذج (وحدات) مسجلة لهذا المبنى من لوحة التحكم.')))
                else ...[
                  DropdownButtonFormField<UnitModel?>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(labelText: 'اختر النموذج (اسم الوحدة)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— اختر النموذج —')),
                      ..._units.map((u) => DropdownMenuItem(value: u, child: Text('${u.name}'))),
                    ],
                    onChanged: (v) => setState(() => _selectedUnit = v),
                  ),
                  if (_selectedUnit != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.door_front_door, color: Color(0xFF1B5E20)),
                            const SizedBox(width: 8),
                            Text('المبنى: ${_selectedBuilding!.name} — النموذج: ${_selectedUnit!.name}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_selectedUnit != null && _selectedUnit!.imagePath != null && _selectedUnit!.imagePath!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('صورة النموذج:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showFullImage(_selectedUnit!.imagePath!, '${_selectedBuilding!.name} - ${_selectedUnit!.name}'),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: _buildImageSource(_selectedUnit!.imagePath!),
                        ),
                      ),
                    ),
                  ] else if (_selectedUnit != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('لا توجد صورة مرفقة لهذا النموذج (${_selectedUnit!.name})', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _choiceCard({required String title, required IconData icon, required VoidCallback onTap, required bool selected}) {
    return Material(
      color: selected ? const Color(0xFF1B5E20).withOpacity(0.15) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: selected ? const Color(0xFF1B5E20) : Colors.grey.shade700),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? const Color(0xFF1B5E20) : Colors.black87), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(String path, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: InteractiveViewer(
                    child: path.startsWith('http') || path.startsWith('data:')
                        ? Image.network(path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80))
                        : const Icon(Icons.image, size: 80),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
