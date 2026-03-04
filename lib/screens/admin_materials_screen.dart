import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

class AdminMaterialsScreen extends StatefulWidget {
  final UserModel admin;

  const AdminMaterialsScreen({super.key, required this.admin});

  @override
  State<AdminMaterialsScreen> createState() => _AdminMaterialsScreenState();
}

class _AdminMaterialsScreenState extends State<AdminMaterialsScreen> {
  final _db = getStorage();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getMaterialsWithIds();
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm([Map<String, dynamic>? item]) async {
    final id = item != null ? item['id'] as int? : null;
    final nameC = TextEditingController(text: item != null ? item['name'] as String? ?? '' : '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(id == null ? 'إضافة خامة' : 'تعديل خامة'),
        content: TextField(controller: nameC, decoration: const InputDecoration(labelText: 'اسم الخامة'), maxLines: 2, textDirection: TextDirection.ltr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (id == null) {
                  await _db.addMaterial(name);
                } else {
                  await _db.updateMaterial(id, name);
                }
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

  Future<void> _delete(Map<String, dynamic> m) async {
    final id = m['id'] as int;
    final name = m['name'] as String;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: Text('حذف "$name"؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteMaterial(id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الخامات'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final m = _list[i];
          final name = m['name'] as String? ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(m)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(m)),
              ]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
