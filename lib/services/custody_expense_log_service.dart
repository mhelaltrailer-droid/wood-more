import 'package:shared_preferences/shared_preferences.dart';

import '../models/custody_expense_log_entry.dart';
import '../models/expense_statement_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

/// نتيجة تحميل سجل العهد والمصروفات: الأحداث مرتبة زمنياً + المستخدمون للفلترة.
class CustodyExpenseLog {
  final List<CustodyExpenseLogEntry> entries;
  final List<UserModel> users;

  const CustodyExpenseLog({required this.entries, required this.users});
}

/// يبني سجل الحركات بدمج حركات الأرصدة مع بيانات الصرف.
///
/// لكل بيان صرف: حدث عند الإرفاق + حدث منفصل عند الاعتماد/الرفض إن وُجد.
/// الحركات المسجّلة قبل إضافة أعمدة المنفّذ تُتجاهل لأنه يتعذر معرفة من نفّذها.
Future<CustodyExpenseLog> loadCustodyExpenseLog() async {
  final db = getStorage();
  final users = List<UserModel>.from(await db.getUsers() as List);
  final custody = List<Map<String, dynamic>>.from(
    await db.getCustodyRecords() as List,
  );
  // كل الحالات: معلّق + معتمد + مرفوض (سجل الحركات فقط).
  final statements = List<ExpenseStatementModel>.from(
    await db.getExpenseStatements() as List,
  );

  final usersById = {for (final u in users) u.id: u};
  final entries = <CustodyExpenseLogEntry>[];

  for (final row in custody) {
    final movementType = (row['movement_type'] ?? '').toString();
    if (movementType != 'add_balance' && movementType != 'withdraw_balance') {
      continue;
    }
    final actorUserId = _asInt(row['actor_user_id']);
    if (actorUserId == null) continue;

    final actor = usersById[actorUserId];
    final targetUserId = _asInt(row['user_id']);
    final target = targetUserId == null ? null : usersById[targetUserId];
    final occurredAt = DateTime.tryParse((row['created_at'] ?? '').toString());
    if (occurredAt == null) continue;

    entries.add(
      CustodyExpenseLogEntry(
        key: 'balance_${row['id']}',
        category: CustodyLogCategory.balance,
        movementType: movementType,
        occurredAt: occurredAt,
        actorUserId: actorUserId,
        actorName: _firstNonEmpty([
          (row['actor_user_name'] ?? '').toString(),
          actor?.name ?? '',
        ]),
        actorRole: _firstNonEmpty([
          (row['actor_role'] ?? '').toString(),
          actor?.role ?? '',
        ]),
        targetUserId: targetUserId,
        targetName: target?.name ?? '',
        amount: _asDouble(row['amount']),
      ),
    );
  }

  for (final s in statements) {
    final target = usersById[s.balanceUserId];
    final submitterName = _firstNonEmpty([
      s.submitterUserName,
      usersById[s.submitterUserId]?.name ?? '',
    ]);
    final targetName = _firstNonEmpty([
      target?.name ?? '',
      submitterName,
    ]);

    // 1) حدث الإرفاق (معلّق أو تاريخ إرفاق سابق).
    entries.add(
      CustodyExpenseLogEntry(
        key: 'expense_${s.id}_submitted',
        category: CustodyLogCategory.expense,
        occurredAt: s.createdAt,
        actorUserId: s.submitterUserId,
        actorName: submitterName,
        actorRole: _firstNonEmpty([
          s.submitterRole,
          usersById[s.submitterUserId]?.role ?? '',
        ]),
        targetUserId: s.balanceUserId,
        targetName: targetName,
        amount: s.amount,
        description: s.description,
        projectName: s.projectName,
        imagePath: s.imagePath,
        status: s.isPending
            ? ExpenseStatementModel.statusPending
            : s.status,
        expensePhase: CustodyExpensePhase.submitted,
      ),
    );

    // 2) حدث الاعتماد / الرفض منفصل.
    if (s.isApproved || s.isRejected) {
      final decidedAt = s.respondedAt ?? s.createdAt;
      entries.add(
        CustodyExpenseLogEntry(
          key: 'expense_${s.id}_decision',
          category: CustodyLogCategory.expense,
          occurredAt: decidedAt,
          actorUserId: s.respondedByUserId,
          actorName: 'Projects Manager',
          actorRole: 'projects_manager',
          targetUserId: s.balanceUserId,
          targetName: targetName,
          amount: s.amount,
          description: s.description,
          projectName: s.projectName,
          imagePath: s.imagePath,
          status: s.status,
          rejectionReason: s.rejectionReason,
          respondedByName: 'Projects Manager',
          expensePhase: s.isApproved
              ? CustodyExpensePhase.approved
              : CustodyExpensePhase.rejected,
        ),
      );
    }
  }

  entries.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return CustodyExpenseLog(entries: entries, users: users);
}

/// تتبّع آخر اطّلاع على السجل لكل مستخدم (محلياً على الجهاز).
class CustodyExpenseLogSeen {
  static String _key(int userId) => 'custody_expense_log_last_seen_$userId';

  /// آخر وقت اطّلع فيه المستخدم على السجل. عند أول استخدام يُسجَّل الوقت الحالي
  /// كخط أساس حتى لا تظهر كل الأحداث القديمة كأنها جديدة.
  static Future<DateTime> lastSeenOrBaseline(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(userId));
    final parsed = stored == null ? null : DateTime.tryParse(stored);
    if (parsed != null) return parsed;
    final now = DateTime.now();
    await prefs.setString(_key(userId), now.toIso8601String());
    return now;
  }

  static Future<void> markSeenNow(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), DateTime.now().toIso8601String());
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
}

String _firstNonEmpty(List<String> candidates) {
  for (final c in candidates) {
    if (c.trim().isNotEmpty) return c.trim();
  }
  return '';
}
