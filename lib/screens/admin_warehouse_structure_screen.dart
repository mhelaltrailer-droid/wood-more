import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/project_location_model.dart';
import '../services/storage_service.dart';
import 'admin_location_materials_screen.dart';

/// هيكلة المخازن: نفس هيكل المشروع (project_locations)، مع إمكانية تعيين خامات وكميات لكل مكان فرعي
class AdminWarehouseStructureScreen extends StatefulWidget {
  final UserModel admin;

  const AdminWarehouseStructureScreen({super.key, required this.admin});

  @override
  State<AdminWarehouseStructureScreen> createState() => _AdminWarehouseStructureScreenState();
}

class _AdminWarehouseStructureScreenState extends State<AdminWarehouseStructureScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  List<ProjectLocationModel> _flatList = [];
  bool _loading = false;
  final Set<int> _expandedIds = {};

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

  Future<void> _loadLocations() async {
    if (_selectedProject == null) {
      setState(() => _flatList = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await _db.getProjectLocations(_selectedProject!.id);
      if (!mounted) return;
      setState(() {
        _flatList = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _flatList = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل المواقع: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<ProjectLocationModel> _childrenOf(int? parentId) {
    return _flatList.where((e) => e.parentId == parentId).toList()
      ..sort((a, b) => a.displayOrder != b.displayOrder ? a.displayOrder.compareTo(b.displayOrder) : a.id.compareTo(b.id));
  }

  void _openLocationMaterials(ProjectLocationModel node) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminLocationMaterialsScreen(
          admin: widget.admin,
          locationId: node.id,
          locationName: node.name,
        ),
      ),
    );
  }

  Widget _buildTree(int? parentId, int depth) {
    final children = _childrenOf(parentId);
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((node) {
        if (node.isFolder) {
          final isExpanded = _expandedIds.contains(node.id);
          return Padding(
            padding: EdgeInsets.only(left: (depth * 20.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() {
                      if (isExpanded) _expandedIds.remove(node.id);
                      else _expandedIds.add(node.id);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 28, color: const Color(0xFF1B5E20)),
                          Icon(Icons.folder, color: Colors.amber[700], size: 24),
                          const SizedBox(width: 8),
                          Expanded(child: Text(node.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                          IconButton(
                            icon: const Icon(Icons.inventory_2, size: 20),
                            tooltip: 'خامات هذا المكان',
                            onPressed: () => _openLocationMaterials(node),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isExpanded) _buildTree(node.id, depth + 1),
              ],
            ),
          );
        } else {
          return Padding(
            padding: EdgeInsets.only(left: (depth * 20.0)),
            child: Row(
              children: [
                const SizedBox(width: 36),
                Icon(Icons.place, color: Colors.green[700], size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(node.name, style: TextStyle(color: Colors.grey[800]))),
                IconButton(
                  icon: const Icon(Icons.inventory_2, size: 20),
                  tooltip: 'خامات هذا المكان',
                  onPressed: () => _openLocationMaterials(node),
                ),
              ],
            ),
          );
        }
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('هيكلة المخازن'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('اسم المخزن = اسم المشروع. أضف أماكن فرعية من شاشة "هيكل مواقع المشروع"، ثم حدد الخامات والكميات لكل مكان هنا.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectModel?>(
            value: _selectedProject,
            decoration: const InputDecoration(labelText: 'المشروع / المخزن', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('— اختر المشروع —')),
              ..._projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
            ],
            onChanged: (v) {
              setState(() {
                _selectedProject = v;
                _flatList = [];
                _expandedIds.clear();
              });
              _loadLocations();
            },
          ),
          const SizedBox(height: 16),
          if (_selectedProject != null) ...[
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_flatList.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'لا توجد مواقع. أضف مواقع من "هيكل مواقع المشروع" أولاً، ثم ارجع هنا لتعيين الخامات لكل مكان.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              _buildTree(null, 0),
          ],
        ],
      ),
    );
  }
}
