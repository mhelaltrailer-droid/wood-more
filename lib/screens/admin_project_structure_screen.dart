import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/project_location_model.dart';
import '../services/storage_service.dart';

/// شاشة هيكل مواقع المشروع: شجرة قابلة للطي (موقع فرعي folder / موقع عمل work_site)
class AdminProjectStructureScreen extends StatefulWidget {
  final UserModel admin;

  const AdminProjectStructureScreen({super.key, required this.admin});

  @override
  State<AdminProjectStructureScreen> createState() => _AdminProjectStructureScreenState();
}

class _AdminProjectStructureScreenState extends State<AdminProjectStructureScreen> {
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

  Future<void> _addNode({int? parentId, required String type}) async {
    if (_selectedProject == null) return;
    final nameC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'folder' ? 'إضافة موقع فرعي' : 'إضافة موقع عمل'),
        content: TextField(
          controller: nameC,
          decoration: InputDecoration(labelText: type == 'folder' ? 'اسم الموقع الفرعي' : 'اسم موقع العمل'),
          textDirection: TextDirection.ltr,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.addProjectLocation(projectId: _selectedProject!.id, parentId: parentId, name: nameC.text.trim(), type: type);
      _loadLocations();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإضافة'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editNode(ProjectLocationModel node) async {
    final nameC = TextEditingController(text: node.name);
    final orderC = TextEditingController(text: '${node.displayOrder}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الاسم والترتيب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'الاسم'),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: orderC,
              decoration: const InputDecoration(labelText: 'ترتيب العرض (رقم)'),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final order = int.tryParse(orderC.text.trim()) ?? node.displayOrder;
    try {
      await _db.updateProjectLocation(node.id, name: nameC.text.trim(), displayOrder: order);
      _loadLocations();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم التعديل'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteNode(ProjectLocationModel node) async {
    final children = _childrenOf(node.id);
    final hasChildren = children.isNotEmpty;
    final msg = hasChildren
        ? 'حذف "${node.name}"؟ سيتم حذف جميع المواقع الفرعية والمواقع التابعة تحته.'
        : 'حذف "${node.name}"؟';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _db.deleteProjectLocation(node.id);
      _loadLocations();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildTree(int? parentId, int depth) {
    final children = _childrenOf(parentId);
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((node) {
        if (node.isFolder) {
          final isExpanded = _expandedIds.contains(node.id);
          final subChildren = _childrenOf(node.id);
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
                          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20), tooltip: 'إضافة موقع فرعي', onPressed: () => _addNode(parentId: node.id, type: 'folder')),
                          IconButton(icon: const Icon(Icons.place, size: 20), tooltip: 'إضافة موقع عمل', onPressed: () => _addNode(parentId: node.id, type: 'work_site')),
                          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editNode(node)),
                          IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteNode(node)),
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
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editNode(node)),
                IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _deleteNode(node)),
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
        title: const Text('هيكل مواقع المشروع'),
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
                _flatList = [];
                _expandedIds.clear();
              });
              _loadLocations();
            },
          ),
          const SizedBox(height: 16),
          if (_selectedProject != null) ...[
            FilledButton.icon(
              icon: const Icon(Icons.folder),
              label: const Text('إضافة موقع فرعي'),
              onPressed: () => _addNode(parentId: null, type: 'folder'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_flatList.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد مواقع. أضف موقعاً فرعياً من الزر أعلاه، ثم من داخل الموقع الفرعي يمكنك إضافة مواقع عمل.'))))
            else
              _buildTree(null, 0),
          ],
        ],
      ),
    );
  }
}
