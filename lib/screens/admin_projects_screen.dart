import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../services/storage_service.dart';

class AdminProjectsScreen extends StatefulWidget {
  final UserModel admin;

  const AdminProjectsScreen({super.key, required this.admin});

  @override
  State<AdminProjectsScreen> createState() => _AdminProjectsScreenState();
}

class _AdminProjectsScreenState extends State<AdminProjectsScreen> {
  final _db = getStorage();
  List<ProjectModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getProjects();
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm([ProjectModel? item]) async {
    final nameC = TextEditingController(text: item?.name ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة مشروع' : 'تعديل مشروع'),
        content: TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم المشروع'), textDirection: TextDirection.ltr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (item == null) await _db.addProject(name);
                else await _db.updateProject(item.id, name);
                _load();
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

  Future<void> _delete(ProjectModel p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: Text('حذف "${p.name}"؟ سيتم حذف المناطق التابعة أيضاً.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteProject(p.id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المشاريع'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final p = _list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(p.name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(p)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(p)),
              ]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
