import 'dart:async';

import 'package:flutter/material.dart';

import '../models/location_material_model.dart';
import '../models/pending_postpone_fine_action_model.dart';
import '../models/user_model.dart';
import '../models/withdrawal_request_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

/// طلبات سحب الخامات — موافقة / رفض (مدير المشروعات أو مدير العمليات).
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
  List<PendingPostponeFineActionModel> _postponeItems = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  bool get _isSem =>
      widget.currentUser.role == 'site_engineer_manager';

  Future<List<PendingPostponeFineActionModel>> _fetchPostponeItemsIfSem() async {
    final db = _db;
    if (!_isSem || db is! ApiStorageService) return [];
    return db.listPendingSemPostponeFineActions(
      userId: widget.currentUser.id,
    );
  }

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
      final wrFuture = _db.listPendingWithdrawalActionsForManager(
            userId: widget.currentUser.id,
            role: widget.currentUser.role,
          )
          as Future<List<WithdrawalRequestModel>>;
      final items = await wrFuture;
      final postponeItems = await _fetchPostponeItemsIfSem();
      if (!mounted) return;
      setState(() {
        _items = items;
        _postponeItems = postponeItems;
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
      final wrFuture = _db.listPendingWithdrawalActionsForManager(
            userId: widget.currentUser.id,
            role: widget.currentUser.role,
          )
          as Future<List<WithdrawalRequestModel>>;
      final items = await wrFuture;
      final postponeItems = await _fetchPostponeItemsIfSem();
      if (!mounted) return;
      setState(() {
        _items = items;
        _postponeItems = postponeItems;
      });
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

  String _formatPlanDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '—';
    final d = DateTime.tryParse(t);
    if (d == null) return raw;
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _resolvePostponeFine(PendingPostponeFineActionModel p) async {
    final db = _db;
    if (db is! ApiStorageService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يتطلب هذا الإجراء اتصالاً بالخادم (وضع API)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final ApiStorageService api = db;
    final engTarget = p.engineerFineTarget.trim();
    if (engTarget == 'owner' || engTarget == 'contractor') {
      final amountController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            'غرامة على ${PendingPostponeFineActionModel.fineTargetLabelAr(engTarget)}',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'اقتراح المهندس: ${PendingPostponeFineActionModel.fineTargetLabelAr(engTarget)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'قيمة الغرامة *',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      final amt = amountController.text.trim();
      amountController.dispose();
      if (ok != true || !mounted) return;
      if (amt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('قيمة الغرامة إلزامية')),
        );
        return;
      }
      try {
        await api.resolveSemPostponeFineResolution(
          executedPlanId: p.id,
          managerUserId: widget.currentUser.id,
          fineTarget: engTarget,
          fineAmount: amt,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل قرار الغرامة'),
            backgroundColor: Colors.green,
          ),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    final reasonController = TextEditingController();
    final ok2 = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('عدم استدعاء غرامة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اقتراح المهندس: لا تستدعي غرامة. يرجى توثيق السبب.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'السبب *',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok2 != true || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السبب إلزامي')),
      );
      return;
    }
    try {
      await api.resolveSemPostponeFineResolution(
        executedPlanId: p.id,
        managerUserId: widget.currentUser.id,
        fineTarget: 'none',
        noFineReason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل قرار بعدم الغرامة'),
          backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSem
              ? 'سحب خامات وتأجيل خطط'
              : 'طلبات سحب خامات',
        ),
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
    if (_items.isEmpty && _postponeItems.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              _isSem
                  ? 'لا توجد طلبات سحب خامات ولا تأجيل خطط تنتظر قراركم حالياً'
                  : 'لا توجد طلبات تنتظر قرارك حالياً',
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_postponeItems.isNotEmpty) ...[
          Text(
            'تأجيل خطط — بانتظار قرار الغرامة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFBF360C),
                ),
          ),
          const SizedBox(height: 10),
          ..._postponeItems.map(_postponeCard),
          if (_items.isNotEmpty) const SizedBox(height: 20),
        ],
        if (_items.isNotEmpty) ...[
          if (_postponeItems.isNotEmpty)
            Text(
              'طلبات سحب خامات',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          if (_postponeItems.isNotEmpty) const SizedBox(height: 10),
          ..._items.map(_withdrawalCard),
        ],
      ],
    );
  }

  Widget _postponeCard(PendingPostponeFineActionModel p) {
    final proj = p.projectName ?? 'مشروع #${p.projectId ?? '—'}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy, color: Colors.orange.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تأجيل خطة عمل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(proj, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('المهندس: ${p.userName}'),
            Text('تاريخ الخطة: ${_formatPlanDate(p.planDate)}'),
            Text('سبب التأجيل: ${p.postponeReasonDisplay}'),
            if (p.postponeReopenDate != null &&
                p.postponeReopenDate!.trim().isNotEmpty)
              Text('إعادة الفتح: ${_formatPlanDate(p.postponeReopenDate!)}'),
            Text(
              'توقيع غرامة (المهندس): '
              '${PendingPostponeFineActionModel.fineTargetLabelAr(p.engineerFineTarget)}',
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
              ),
              onPressed: () => _resolvePostponeFine(p),
              child: const Text('قرار الغرامة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _withdrawalCard(WithdrawalRequestModel r) {
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
                    ? 'وافق مدير العمليات — بانتظار موافقتكم لإكمال الاعتماد.'
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
  }
}
