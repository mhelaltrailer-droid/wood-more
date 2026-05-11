import 'dart:async';

import 'package:flutter/material.dart';

import '../models/location_material_model.dart';
import '../models/user_model.dart';
import '../models/withdrawal_request_model.dart';
import '../services/storage_service.dart';

/// طلبات سحب الخامات — موافقة / رفض (مدير المشروعات أو مدير التشغيل).
class ManagerWithdrawalRequestsScreen extends StatefulWidget {
  final UserModel currentUser;

  const ManagerWithdrawalRequestsScreen({super.key, required this.currentUser});

  @override
  State<ManagerWithdrawalRequestsScreen> createState() =>
      _ManagerWithdrawalRequestsScreenState();
}

class _ManagerWithdrawalRequestsScreenState
    extends State<ManagerWithdrawalRequestsScreen> {
  final _db = getStorage();
  List<WithdrawalRequestModel> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refreshSilently());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _db.listPendingWithdrawalActionsForManager(
        userId: widget.currentUser.id,
        role: widget.currentUser.role,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final list = await _db.listPendingWithdrawalActionsForManager(
        userId: widget.currentUser.id,
        role: widget.currentUser.role,
      );
      if (!mounted) return;
      setState(() => _items = list);
    } catch (_) {}
  }

  Future<void> _respond(WithdrawalRequestModel r, bool approve) async {
    String? reason;
    if (!approve) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('سبب الرفض (إلزامي)'),
          content: TextField(
            controller: c,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'اكتب السبب',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      reason = c.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('السبب إلزامي')),
        );
        return;
      }
    }
    try {
      await _db.respondWithdrawalRequest(
        requestId: r.id,
        managerUserId: widget.currentUser.id,
        approve: approve,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'تم تسجيل الموافقة' : 'تم تسجيل الرفض'),
          backgroundColor: approve ? Colors.green : Colors.orange,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _phaseAr(String phase) => LocationMaterialModel.phaseLabel(phase);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات سحب خامات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('لا توجد طلبات تنتظر قرارك حالياً')),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final r = _items[i];
        final proj = r.projectName ?? 'مشروع #${r.projectId}';
        final waitingOther = widget.currentUser.role == 'site_engineer_manager'
            ? (r.semStatus == WithdrawalRequestModel.statusPending &&
                r.omStatus == WithdrawalRequestModel.statusApproved)
            : (r.omStatus == WithdrawalRequestModel.statusPending &&
                r.semStatus == WithdrawalRequestModel.statusApproved);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  proj,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text('الموقع: ${r.locationPathLabel}'),
                Text('المرحلة: ${_phaseAr(r.phase)}'),
                Text('المهندس: ${r.engineerUserName}'),
                Text('رقم الطلب: ${r.id}'),
                if (waitingOther) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.currentUser.role == 'site_engineer_manager'
                        ? 'وافق مدير التشغيل — بانتظار موافقتكم لإكمال الاعتماد.'
                        : 'وافق ${UserModel.siteEngineerManagerRoleLabel} — بانتظار موافقتكم لإكمال الاعتماد.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                        ),
                        onPressed: () => _respond(r, true),
                        child: const Text('موافقة'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _respond(r, false),
                        child: const Text('رفض'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
