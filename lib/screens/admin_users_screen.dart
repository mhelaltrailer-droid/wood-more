import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final UserModel admin;

  const AdminUsersScreen({super.key, required this.admin});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _db = getStorage();
  List<UserModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.getUsers();
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  Future<void> _showForm([UserModel? item]) async {
    final nameC = TextEditingController(text: item?.name ?? '');
    final emailC = TextEditingController(text: item?.email ?? '');
    final passwordC = TextEditingController();
    String role = item?.role ?? 'site_engineer';
    bool obscurePassword = true;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(item == null ? 'إضافة مستخدم' : 'تعديل مستخدم'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'الاسم'), textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                TextField(controller: emailC, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordC,
                  obscureText: obscurePassword,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة السر',
                    hintText: item == null ? 'الافتراضية: 0000' : 'اتركها فارغة للإبقاء على الحالية',
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialog(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(value: 'site_engineer', child: Text('مهندس موقع')),
                    DropdownMenuItem(value: 'site_engineer_manager', child: Text('مدير مهندسين')),
                    DropdownMenuItem(value: 'app_admin', child: Text('مسؤول التطبيق')),
                  ],
                  onChanged: (v) => setDialog(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final name = nameC.text.trim();
                final email = emailC.text.trim();
                final password = passwordC.text;
                if (name.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاسم والبريد مطلوبان')));
                  return;
                }
                if (item == null && password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل كلمة السر للمستخدم الجديد')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  if (item == null) {
                    await _db.addUser(name, email, password.isEmpty ? '0000' : password, role);
                  } else {
                    await _db.updateUser(item.id, name, email, role, password.isEmpty ? null : password);
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
      ),
    );
  }

  Future<void> _delete(UserModel u) async {
    if (u.id == widget.admin.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن حذف حسابك')));
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('تأكيد'), content: Text('حذف "${u.name}"؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))]));
    if (ok != true || !mounted) return;
    try {
      await _db.deleteUser(u.id);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  String _roleLabel(String r) {
    if (r == 'site_engineer') return 'مهندس موقع';
    if (r == 'site_engineer_manager') return 'مدير مهندسين';
    if (r == 'app_admin') return 'مسؤول التطبيق';
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين'), backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
      body: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _list.length,
        itemBuilder: (context, i) {
          final u = _list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(u.name),
              subtitle: Text('${u.email} — ${_roleLabel(u.role)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(u)),
                if (u.id != widget.admin.id) IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(u)),
              ]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: const Color(0xFF1B5E20)),
    );
  }
}
