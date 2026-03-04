import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/supervisor_model.dart';
import '../services/storage_service.dart';

class AdminSupervisorsScreen extends StatefulWidget {
  final UserModel admin;

  const AdminSupervisorsScreen({super.key, required this.admin});

  @override
  State<AdminSupervisorsScreen> createState() => _AdminSupervisorsScreenState();
}

class _AdminSupervisorsScreenState extends State<AdminSupervisorsScreen> {
  final _db = getStorage();
  List<SupervisorModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getSupervisors();
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm([SupervisorModel? item]) async {
    final nameC = TextEditingController(text: item?.name ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'إضافة مشرف' : 'تعديل مشرف'),
        content: TextField(controller: nameC, decoration: const InputDecoration(labelText: 'الاسم'), textDirection: TextDirection.ltr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final name = nameC.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (item == null) await _db.addSupervisor(name);
                else await _db.updateSupervisor(item.id, name);
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

  Future<void> _delete(SupervisorModel s) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: Text('حذف ${s.name}؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteSupervisor(s.id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المشرفين'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final s = _list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(s.name),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(s)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(s)),
              ]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
