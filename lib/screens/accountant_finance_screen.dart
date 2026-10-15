import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/expense_statement_model.dart';
import '../models/user_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

/// واجهة الأرصدة / المصروفات: الاطلاع على أرصدة المستخدمين، إضافة/سحب رصيد، وإنشاء تقرير بكل الحركات
class AccountantFinanceScreen extends StatefulWidget {
  final UserModel currentUser;

  const AccountantFinanceScreen({super.key, required this.currentUser});

  @override
  State<AccountantFinanceScreen> createState() => _AccountantFinanceScreenState();
}

class _AccountantFinanceScreenState extends State<AccountantFinanceScreen> {
  final _db = getStorage();
  List<UserModel> _users = [];
  Map<int, double> _balances = {};
  bool _loading = true;

  /// أثناء إضافة/سحب/ضبط رصيد — مؤشر خفيف على بطاقة المستخدم فقط.
  int? _busyUserId;

  /// منفّذو الإضافة/السحب المسموح ظهور حركاتهم في التقرير.
  static const _reportActorEmails = {
    'ah-amin',
    'abdelrhmanellaithy828@gmail.com',
  };
  static const _aminEmail = 'ah-amin';

  /// مستخدمون لا يظهرون في قائمة أرصدة المستخدمين (بالبريد).
  static const _hiddenFromBalancesEmails = {
    'shalaby', // Eng/ M.shalaby
    'dc', // DC
    'mahatowab@gmail.com', // Eng/Maha
    'shams', // Operation Manager
    'mouhamedhelal.cor@gmail.com', // Manager-Tester
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
      // عرض المستخدمين ما عدا مسؤول التطبيق والمستثنَين من قائمة الأرصدة
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// إضافة رصيد لمستخدم. المحاسب فقط يمكنه إضافة رصيد ذاتي. وإلا: خصم من رصيد المنفّذ وإضافة للمستخدم.
  Future<void> _addBalance(UserModel user) async {
    final isSelf = user.id == widget.currentUser.id;
    if (isSelf && !widget.currentUser.isAccountant) return;
    // مدير المشروعات لا يضيف رصيداً لحساب المحاسب (السحب مسموح).
    if (!widget.currentUser.isAccountant &&
        user.isAccountant &&
        widget.currentUser.hasSiteEngineerManagerPrivileges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن لمدير المشروعات إضافة رصيد لحساب المحاسب'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amountC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSelf ? 'إضافة رصيد ذاتي (للمحاسب)' : 'إضافة رصيد - ${user.name}'),
        content: TextField(
          controller: amountC,
          decoration: const InputDecoration(labelText: 'المبلغ'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amountC.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    if (_busyUserId != null) return;
    setState(() => _busyUserId = user.id);
    try {
      if (isSelf) {
        // إضافة رصيد ذاتي للمحاسب فقط (بدون خصم من أي أحد)
        final current = _balances[user.id] ?? 0;
        final after = current + amount;
        await _db.setEngineerBalance(user.id, after);
        await _db.addBalanceMovement(
          user.id,
          amount,
          'إضافة رصيد ذاتي',
          'add_balance',
          actorUserId: widget.currentUser.id,
          actorUserName: widget.currentUser.name,
          actorRole: widget.currentUser.role,
          balanceAfter: after,
        );
        if (!mounted) return;
        setState(() {
          _balances[user.id] = after;
          _busyUserId = null;
        });
      } else {
        final actorBalance = _balances[widget.currentUser.id] ?? 0;
        if (actorBalance < amount) {
          if (mounted) {
            setState(() => _busyUserId = null);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('رصيدك الحالي ${actorBalance.toStringAsFixed(2)} أقل من المبلغ المطلوب'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        final currentUser = _balances[user.id] ?? 0;
        final after = currentUser + amount;
        final actorAfter = actorBalance - amount;
        await _db.setEngineerBalance(user.id, after);
        await _db.setEngineerBalance(widget.currentUser.id, actorAfter);
        await _db.addBalanceMovement(
          user.id,
          amount,
          'إضافة رصيد',
          'add_balance',
          actorUserId: widget.currentUser.id,
          actorUserName: widget.currentUser.name,
          actorRole: widget.currentUser.role,
          balanceAfter: after,
        );
        if (!mounted) return;
        setState(() {
          _balances[user.id] = after;
          _balances[widget.currentUser.id] = actorAfter;
          _busyUserId = null;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة الرصيد'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyUserId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// سحب رصيد من مستخدم: يُضاف المبلغ إلى رصيد المنفّذ ويُخصم من رصيد المستخدم.
  Future<void> _withdrawBalance(UserModel user) async {
    final amountC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سحب رصيد - ${user.name}'),
        content: TextField(
          controller: amountC,
          decoration: const InputDecoration(labelText: 'المبلغ'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('سحب'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amount = double.tryParse(amountC.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    if (_busyUserId != null) return;
    setState(() => _busyUserId = user.id);
    try {
      final currentUser = _balances[user.id] ?? 0;
      if (currentUser < amount) {
        if (mounted) {
          setState(() => _busyUserId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('رصيد ${user.name} غير كافٍ (${currentUser.toStringAsFixed(2)})'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      final actorBalance = _balances[widget.currentUser.id] ?? 0;
      final after = currentUser - amount;
      final actorAfter = actorBalance + amount;
      await _db.setEngineerBalance(user.id, after);
      await _db.setEngineerBalance(widget.currentUser.id, actorAfter);
      await _db.addBalanceMovement(
        user.id,
        amount,
        'سحب رصيد',
        'withdraw_balance',
        actorUserId: widget.currentUser.id,
        actorUserName: widget.currentUser.name,
        actorRole: widget.currentUser.role,
        balanceAfter: after,
      );
      if (!mounted) return;
      setState(() {
        _balances[user.id] = after;
        _balances[widget.currentUser.id] = actorAfter;
        _busyUserId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم سحب الرصيد'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busyUserId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isAminUser(UserModel u) =>
      u.email.trim().toLowerCase() == _aminEmail;

  bool _isAllowedReportActor({
    required int? actorUserId,
    required Map<int, String> emailById,
  }) {
    if (actorUserId == null) return false;
    final email = emailById[actorUserId];
    return email != null && _reportActorEmails.contains(email);
  }

  double? _parseBalanceAfter(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  Future<void> _showCreateReport() async {
    DateTime dateFrom = DateTime.now().subtract(const Duration(days: 30));
    DateTime dateTo = DateTime.now();
    // null = الكل
    UserModel? selectedEngineer;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('تقرير الحركات المالية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('المهندس', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedEngineer?.id,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ..._users.map(
                          (u) => DropdownMenuItem<int?>(
                            value: u.id,
                            child: Text(u.name),
                          ),
                        ),
                      ],
                      onChanged: (id) {
                        setDialog(() {
                          if (id == null) {
                            selectedEngineer = null;
                            return;
                          }
                          UserModel? found;
                          for (final u in _users) {
                            if (u.id == id) {
                              found = u;
                              break;
                            }
                          }
                          selectedEngineer = found;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('من تاريخ', style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('yyyy/MM/dd', 'ar').format(dateFrom)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: dateFrom,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setDialog(() => dateFrom = d);
                  },
                ),
                const SizedBox(height: 8),
                const Text('إلى تاريخ', style: TextStyle(fontWeight: FontWeight.bold)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('yyyy/MM/dd', 'ar').format(dateTo)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: dateTo,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setDialog(() => dateTo = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('عرض التقرير')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final from = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toEnd = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
    final filterAll = selectedEngineer == null;
    final filterAmin =
        selectedEngineer != null && _isAminUser(selectedEngineer!);

    final allUsers = List<UserModel>.from(await _db.getUsers() as List);
    final emailById = {
      for (final u in allUsers) u.id: u.email.trim().toLowerCase(),
    };
    final nameById = {for (final u in allUsers) u.id: u.name};

    final custodyRecords = await _db.getCustodyRecords(userId: null);
    final combined = <Map<String, dynamic>>[];

    for (final e in custodyRecords) {
      final movementType = (e['movement_type'] as String?) ?? 'custody';
      if (movementType != 'add_balance' && movementType != 'withdraw_balance') {
        continue;
      }
      final createdRaw = e['created_at'] as String?;
      if (createdRaw == null) continue;
      final dt = DateTime.tryParse(createdRaw);
      if (dt == null || dt.isBefore(from) || dt.isAfter(toEnd)) continue;

      final actorId = e['actor_user_id'] is int
          ? e['actor_user_id'] as int
          : int.tryParse('${e['actor_user_id'] ?? ''}');
      if (!_isAllowedReportActor(actorUserId: actorId, emailById: emailById)) {
        continue;
      }

      final targetId = e['user_id'] is int
          ? e['user_id'] as int
          : int.tryParse('${e['user_id'] ?? ''}');
      if (targetId == null) continue;

      if (filterAmin) {
        // ah-amin: كل ما نفّذه كمنفّذ (حتى على مهندسين آخرين)
        if (actorId != selectedEngineer!.id) continue;
      } else if (!filterAll) {
        // مهندس معيّن: حركات تخص رصيده فقط
        if (targetId != selectedEngineer!.id) continue;
      }

      final note = (e['note'] as String?)?.trim().isNotEmpty == true
          ? (e['note'] as String).trim()
          : '—';
      // إضافة ذاتية: المنفّذ = المستهدف + add_balance (أو نص البيان المعروف)
      final isSelfAdd = movementType == 'add_balance' &&
          ((actorId != null && actorId == targetId) ||
              note == 'إضافة رصيد ذاتي');

      combined.add({
        'type': movementType,
        'created_at': createdRaw,
        'user_id': targetId,
        'user_name': nameById[targetId],
        'note': note,
        'amount': (e['amount'] as num).toDouble(),
        'balance_after': _parseBalanceAfter(e['balance_after']),
        'is_self_add': isSelfAdd,
      });
    }

    // بيانات الصرف المعتمدة — لا تُدرج عند اختيار ah-amin (لا يدخل بيانات صرف)
    if (!filterAmin) {
      final statements = await _db.getExpenseStatements(
        statuses: [ExpenseStatementModel.statusApproved],
      );
      for (final s in statements) {
        if (!s.isApproved) continue;
        final created = s.createdAt;
        if (created.isBefore(from) || created.isAfter(toEnd)) continue;
        if (!filterAll && s.balanceUserId != selectedEngineer!.id) continue;

        // ترتيب زمني حسب لحظة الاعتماد (وقت الخصم)، مع الإبقاء على فلترة created_at
        final sortAt = s.respondedAt ?? s.createdAt;
        combined.add({
          'type': 'expense',
          'created_at': sortAt.toIso8601String(),
          'user_id': s.balanceUserId,
          'user_name': nameById[s.balanceUserId] ?? s.submitterUserName,
          'note': s.description.trim().isEmpty ? '—' : s.description,
          'amount': s.amount,
          'balance_after': s.balanceAfter,
        });
      }
    }

    combined.sort(
      (a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String),
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AccountantFinanceReportScreen(
          dateFrom: dateFrom,
          dateTo: dateTo,
          movements: combined,
        ),
      ),
    );
  }

  String get _helpText {
    if (widget.currentUser.canSetUserBalancesDirectly) {
      return 'المسؤول الأساسي يمكنه ضبط رصيد أي مستخدم يدوياً (تعيين القيمة مباشرة). هذا الضبط لا يُسجَّل في سجل حركات العهد/المصروفات.';
    }
    if (widget.currentUser.isAccountant) {
      return 'المحاسب يمكنه إضافة رصيد لنفسه، أو إضافة/سحب رصيد من باقي المستخدمين (الإضافة تخصم من رصيده، والسحب يضاف لرصيده). لا يسمح له بسحب رصيد من نفسه.';
    }
    return 'يمكنك إضافة/سحب رصيد للمستخدمين (الإضافة تخصم من رصيدك، والسحب يضاف لرصيدك). لا يمكن تعديل رصيدك من هنا.';
  }

  String? _selfBadgeLabel(UserModel user) {
    if (user.id != widget.currentUser.id) return null;
    if (widget.currentUser.isAccountant) return 'المحاسب';
    if (widget.currentUser.hasSiteEngineerManagerPrivileges) {
      return UserModel.siteEngineerManagerRoleLabel;
    }
    return null;
  }

  /// ضبط رصيد مباشر للمسؤول الأساسي — بدون تسجيل حركة في سجل الحركات.
  Future<void> _setBalanceDirect(UserModel user) async {
    if (!widget.currentUser.canSetUserBalancesDirectly) return;
    final current = _balances[user.id] ?? 0;
    final amountC = TextEditingController(
      text: current == current.roundToDouble()
          ? current.toStringAsFixed(0)
          : current.toStringAsFixed(2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ضبط رصيد - ${user.name}'),
        content: TextField(
          controller: amountC,
          decoration: const InputDecoration(
            labelText: 'قيمة الرصيد',
            helperText: 'أدخل الرصيد النهائي المطلوب (يمكن أن يكون سالباً)',
          ),
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final raw = amountC.text.trim().replaceAll(',', '');
    final value = double.tryParse(raw);
    if (value == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل قيمة صحيحة')),
        );
      }
      return;
    }
    if (_busyUserId != null) return;
    setState(() => _busyUserId = user.id);
    try {
      // تعيين مباشر فقط — بدون addBalanceMovement حتى لا تظهر في سجل الحركات.
      await _db.setEngineerBalance(user.id, value);
      if (!mounted) return;
      setState(() {
        _balances[user.id] = value;
        _busyUserId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ضبط رصيد ${user.name} إلى ${value.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busyUserId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPrimaryBalanceEditor = widget.currentUser.canSetUserBalancesDirectly;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isPrimaryBalanceEditor ? 'الأرصدة' : 'الأرصدة / المصروفات',
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
          await saveLastRoute('home');
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser)));
        },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('أرصدة المستخدمين', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _helpText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                ..._users.map((u) {
                  final balance = _balances[u.id] ?? 0;
                  final isSelf = u.id == widget.currentUser.id;
                  final selfBadge = _selfBadgeLabel(u);
                  final showSetBalance = isPrimaryBalanceEditor;
                  final showAdd = !isPrimaryBalanceEditor &&
                      (!isSelf || widget.currentUser.isAccountant) &&
                      !(widget.currentUser.hasSiteEngineerManagerPrivileges &&
                          u.isAccountant);
                  final showWithdraw = !isPrimaryBalanceEditor && !isSelf;
                  final isBusy = _busyUserId == u.id;
                  final actionsEnabled = _busyUserId == null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (selfBadge != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1B5E20).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(selfBadge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text('الرصيد الحالي: ${balance.toStringAsFixed(2)}',  style: TextStyle(color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              if (isBusy)
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showSetBalance)
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit, size: 20),
                                        label: const Text('ضبط رصيد'),
                                        onPressed: actionsEnabled
                                            ? () => _setBalanceDirect(u)
                                            : null,
                                      ),
                                    if (showAdd)
                                      TextButton.icon(
                                        icon: const Icon(Icons.add, size: 20),
                                        label: const Text('إضافة رصيد'),
                                        onPressed: actionsEnabled
                                            ? () => _addBalance(u)
                                            : null,
                                      ),
                                    if (showWithdraw) ...[
                                      if (showAdd) const SizedBox(width: 8),
                                      TextButton.icon(
                                        icon: const Icon(Icons.remove, size: 20),
                                        label: const Text('سحب رصيد'),
                                        onPressed: actionsEnabled
                                            ? () => _withdrawBalance(u)
                                            : null,
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (!isPrimaryBalanceEditor) ...[
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _showCreateReport,
                    icon: const Icon(Icons.summarize),
                    label: const Text('إنشاء تقرير'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _AccountantFinanceReportScreen extends StatelessWidget {
  final DateTime dateFrom;
  final DateTime dateTo;
  final List<Map<String, dynamic>> movements;

  const _AccountantFinanceReportScreen({
    required this.dateFrom,
    required this.dateTo,
    required this.movements,
  });

  String _userName(Map<String, dynamic> e) {
    final fromMap = e['user_name'] as String?;
    if (fromMap != null && fromMap.trim().isNotEmpty) return fromMap;
    return '—';
  }

  String _typeLabel(Map<String, dynamic> e) {
    final t = e['type'] as String?;
    if (t == 'expense') return 'بيان صرف';
    if (t == 'add_balance') return 'إضافة رصيد';
    if (t == 'withdraw_balance') return 'سحب رصيد';
    return '—';
  }

  /// الاجمالي يستثني الإضافة الذاتية (تظهر في الجدول فقط لتجنّب العدّ المزدوج).
  bool _countsTowardTotal(Map<String, dynamic> e) {
    if (e['is_self_add'] == true) return false;
    final note = (e['note'] as String?)?.trim() ?? '';
    if (note == 'إضافة رصيد ذاتي') return false;
    return true;
  }

  double get _totalAmount => movements.fold<double>(
        0,
        (sum, e) {
          if (!_countsTowardTotal(e)) return sum;
          return sum + ((e['amount'] as num?)?.toDouble() ?? 0);
        },
      );

  // عمود «الرصيد بعد» مخفي مؤقتاً — التخزين في الخلفية ما زال يعمل.

  Future<void> _exportPdf(BuildContext context) async {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final totalLabel = _totalAmount.toStringAsFixed(2);
    final fontBase = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();
    final theme = pw.ThemeData.withFont(base: fontBase, bold: fontBold);
    pw.ImageProvider? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}
    final logo = logoImage;
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        build: (ctx) => [
          if (logo != null)
            pw.Center(
              child: pw.Container(
                height: 48,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              color: pdf.PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: pdf.PdfColors.green800),
            ),
            child: pw.Center(
              child: pw.Text(
                'تقرير الحركات المالية (إضافة/سحب + صرف معتمد)',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: pdf.PdfColors.green900,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'من ${dateFormat.format(dateFrom)} إلى ${dateFormat.format(dateTo)}',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 10),
          // pw.Table يرسم LTR (يسار→يمين)، لذلك نعكس ترتيب العناصر
          // ليظهر بصرياً يمين→يسار: التاريخ | الاسم | البيان | المبلغ | الحركة
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(0.85),
              2: const pw.FlexColumnWidth(1.8),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(0.95),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey300),
                children: [
                  _cell('الحركة', true),
                  _cell('المبلغ', true),
                  _cell('البيان', true),
                  _cell('الاسم', true),
                  _cell('التاريخ', true),
                ],
              ),
              ...movements.map((e) {
                final dt = DateTime.parse(e['created_at'] as String);
                return pw.TableRow(
                  children: [
                    _cell(_typeLabel(e), false),
                    _cell((e['amount'] as num).toStringAsFixed(2), false),
                    _cell(e['note'] as String? ?? '—', false),
                    _cell(_userName(e), false),
                    _cell(dateFormat.format(dt), false),
                  ],
                );
              }),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey200),
                children: [
                  _cell('', true),
                  _cell(totalLabel, true),
                  _cell('الاجمالي', true),
                  _cell('', true),
                  _cell('', true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'تقرير_مالي_${dateFormat.format(dateFrom)}_${dateFormat.format(dateTo)}.pdf',
    );
  }

  static pw.Widget _cell(String text, bool isHeader) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? pdf.PdfColors.green900 : pdf.PdfColors.black,
        ),
      ),
    );
  }

  Widget _screenHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _screenCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd', 'ar');
    final totalLabel = _totalAmount.toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير الحركات المالية'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Text(
              'من ${dateFormat.format(dateFrom)} إلى ${dateFormat.format(dateTo)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          if (movements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد حركات في المدة المحددة'),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.sizeOf(context).width - 32,
                ),
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade400),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: const {
                    0: FlexColumnWidth(1.1),
                    1: FlexColumnWidth(1.3),
                    2: FlexColumnWidth(2.0),
                    3: FlexColumnWidth(1.0),
                    4: FlexColumnWidth(1.2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade300),
                      children: [
                        _screenHeaderCell('التاريخ'),
                        _screenHeaderCell('الاسم'),
                        _screenHeaderCell('البيان'),
                        _screenHeaderCell('المبلغ'),
                        _screenHeaderCell('الحركة'),
                      ],
                    ),
                    ...movements.map((e) {
                      final dt = DateTime.parse(e['created_at'] as String);
                      return TableRow(
                        children: [
                          _screenCell(dateFormat.format(dt)),
                          _screenCell(_userName(e)),
                          _screenCell(e['note'] as String? ?? '—'),
                          _screenCell(
                            (e['amount'] as num).toStringAsFixed(2),
                            bold: true,
                          ),
                          _screenCell(_typeLabel(e)),
                        ],
                      );
                    }),
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: [
                        _screenCell(''),
                        _screenCell(''),
                        _screenCell('الاجمالي', bold: true),
                        _screenCell(totalLabel, bold: true),
                        _screenCell(''),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (movements.isNotEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export PDF'),
              onPressed: () => _exportPdf(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
