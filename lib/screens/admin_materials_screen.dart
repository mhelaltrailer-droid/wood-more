import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/material_name_compare.dart';

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
  String _searchQuery = '';

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

  Future<bool> _confirmSimilarMaterials(
    BuildContext ctx,
    String newName,
    List<String> similarNames,
  ) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('تأكيد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'يوجد خامة بأسم مشابه — هل الخامة الجديدة مختلفة؟ هل تريد إضافتها أيضاً؟',
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Text('الاسم الجديد: $newName', textDirection: TextDirection.ltr),
              const SizedBox(height: 8),
              const Text('خامات مشابهة موجودة:', textDirection: TextDirection.rtl),
              const SizedBox(height: 4),
              ...similarNames.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $n', textDirection: TextDirection.ltr),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('نعم، أضف')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _saveMaterial({
    required int? id,
    required String name,
  }) async {
    try {
      if (id == null) {
        await _db.addMaterial(name);
      } else {
        await _db.updateMaterial(id, name);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(id == null ? 'تم إضافة الخامة' : 'تم تعديل الخامة'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

              final duplicate = findDuplicateMaterialName(name, _list, excludeId: id);
              if (duplicate != null) {
                await showDialog<void>(
                  context: ctx,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('تنبيه'),
                    content: Text(
                      'يوجد خامة موجودة بالفعل بأسم ($duplicate)',
                      textDirection: TextDirection.rtl,
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('حسناً')),
                    ],
                  ),
                );
                return;
              }

              final similar = findSimilarMaterialNames(name, _list, excludeId: id);
              if (similar.isNotEmpty) {
                final proceed = await _confirmSimilarMaterials(ctx, name, similar);
                if (!proceed) return;
              }

              Navigator.pop(ctx);
              await _saveMaterial(id: id, name: name);
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

  List<Map<String, dynamic>> get _filteredList {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _list;
    return _list
        .where((m) => ((m['name'] as String?) ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _filteredList;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الخامات'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث في الخامات',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    textDirection: TextDirection.ltr,
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('لا توجد خامات مطابقة للبحث'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final m = visible[i];
                            final name = m['name'] as String? ?? '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(name, textDirection: TextDirection.ltr),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(m)),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(m)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
