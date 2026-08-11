import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class OperationManagerBalancesViewScreen extends StatefulWidget {
  final UserModel currentUser;

  const OperationManagerBalancesViewScreen({super.key, required this.currentUser});

  @override
  State<OperationManagerBalancesViewScreen> createState() =>
      _OperationManagerBalancesViewScreenState();
}

class _OperationManagerBalancesViewScreenState
    extends State<OperationManagerBalancesViewScreen> {
  final _db = getStorage();

  List<UserModel> _users = [];
  Map<int, double> _balances = {};
  bool _loading = true;

  static const _hiddenFromBalancesEmails = {
    'shalaby',
    'dc',
    'mahatowab@gmail.com',
    'shams',
    'mouhamedhelal.cor@gmail.com',
  };

  bool _isHiddenFromBalances(UserModel u) {
    if (u.role == 'app_admin') return true;
    return _hiddenFromBalancesEmails.contains(u.email.trim().toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _db.getUsers();
      final visible = list.where((u) => !_isHiddenFromBalances(u)).toList().cast<UserModel>();
      visible.sort((UserModel a, UserModel b) => a.name.compareTo(b.name));
      final balances = <int, double>{};
      for (final u in visible) {
        try {
          balances[u.id] = await _db.getEngineerBalance(u.id);
        } catch (_) {
          balances[u.id] = 0.0;
        }
      }
      if (!mounted) return;
      setState(() {
        _users = visible;
        _balances = balances;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الأرصدة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرصدة'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(currentUser: widget.currentUser),
              ),
            );
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'أرصدة المستخدمين (اطلاع فقط)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هذه الشاشة للعرض فقط ولا تسمح بإضافة أو سحب رصيد.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  ..._users.map((u) {
                    final balance = _balances[u.id] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          u.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('الدور: ${u.roleLabel}'),
                        trailing: Text(
                          balance.toStringAsFixed(2),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
