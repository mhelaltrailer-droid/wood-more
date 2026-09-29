import '../core/role_labels.dart';
import 'expense_statement_model.dart';

/// تصنيف حدث سجل العهد والمصروفات (يُستخدم للفلترة).
enum CustodyLogCategory { balance, expense }

/// مرحلة حدث بيان الصرف في السجل (إرفاق / اعتماد / رفض).
enum CustodyExpensePhase { submitted, approved, rejected }

/// حدث واحد في سجل حركات العهد والمصروفات — للعرض فقط.
///
/// يُبنى من مصدرين: حركات جدول [engineer_custody] وبيانات الصرف
/// (إرفاق معلّق + اعتماد/رفض كأحداث منفصلة).
class CustodyExpenseLogEntry {
  /// مفتاح فريد عبر المصدرين معاً (لأن المعرفات تتكرر بين الجدولين).
  final String key;
  final CustodyLogCategory category;

  /// معرّف الصف في المصدر: engineer_custody أو expense_statements.
  final int? sourceRecordId;

  /// add_balance أو withdraw_balance لحركات الأرصدة، وفارغ لبيانات الصرف.
  final String movementType;
  final DateTime occurredAt;
  final int? actorUserId;
  final String actorName;
  final String actorRole;

  /// صاحب الرصيد / مقدّم بيان الصرف.
  final int? targetUserId;
  final String targetName;
  final double amount;
  final String description;
  final String? projectName;
  final String? imagePath;

  /// pending / approved / rejected لبيانات الصرف.
  final String? status;
  final String? rejectionReason;
  final String? respondedByName;

  /// مرحلة حدث الصرف في السجل (null لحركات الرصيد).
  final CustodyExpensePhase? expensePhase;

  const CustodyExpenseLogEntry({
    required this.key,
    required this.category,
    this.sourceRecordId,
    this.movementType = '',
    required this.occurredAt,
    this.actorUserId,
    required this.actorName,
    this.actorRole = '',
    this.targetUserId,
    this.targetName = '',
    required this.amount,
    this.description = '',
    this.projectName,
    this.imagePath,
    this.status,
    this.rejectionReason,
    this.respondedByName,
    this.expensePhase,
  });

  bool get isBalance => category == CustodyLogCategory.balance;
  bool get isAddBalance => movementType == 'add_balance';
  bool get isRejected =>
      expensePhase == CustodyExpensePhase.rejected ||
      status == ExpenseStatementModel.statusRejected;
  bool get isPendingExpense =>
      expensePhase == CustodyExpensePhase.submitted &&
      status == ExpenseStatementModel.statusPending;
  bool get isApprovedExpense => expensePhase == CustodyExpensePhase.approved;

  /// المبلغ بصيغة مختصرة: بدون كسور عندما يكون رقماً صحيحاً.
  String get amountLabel {
    final rounded = amount.roundToDouble();
    final text = amount == rounded
        ? rounded.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$text جنيه';
  }

  String get amountInParens {
    final rounded = amount.roundToDouble();
    final text = amount == rounded
        ? rounded.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '($text)';
  }

  /// «قام المحاسب أحمد علي …» — يسقط الدور إن كان غير معروف.
  String get _actorLabel {
    final roleLabel = arabicRoleLabel(actorRole);
    final name = actorName.trim();
    if (roleLabel.isEmpty) return name.isEmpty ? 'مستخدم غير معروف' : name;
    if (name.isEmpty) return roleLabel;
    return '$roleLabel $name';
  }

  /// نص الحدث كما يظهر في السجل.
  String get sentence {
    if (isBalance) {
      final target = targetName.trim().isEmpty ? 'مستخدم محذوف' : targetName;
      return isAddBalance
          ? 'قام $_actorLabel بإضافة رصيد $amountLabel للمستخدم $target'
          : 'قام $_actorLabel بسحب رصيد $amountLabel من المستخدم $target';
    }

    final user = targetName.trim().isEmpty
        ? (actorName.trim().isEmpty ? 'مستخدم غير معروف' : actorName.trim())
        : targetName.trim();

    switch (expensePhase) {
      case CustodyExpensePhase.submitted:
        if (status == ExpenseStatementModel.statusPending) {
          return 'المستخدم "$user" أرفق بيان صرف بقيمة $amountInParens ولم يتم اعتماده';
        }
        return 'المستخدم "$user" أرفق بيان صرف بقيمة $amountInParens';
      case CustodyExpensePhase.approved:
        return 'قام Projects Manager باعتماد بيان الصرف للمستخدم $user بقيمة $amountInParens';
      case CustodyExpensePhase.rejected:
        return 'قام Projects Manager برفض بيان الصرف للمستخدم $user بقيمة $amountInParens';
      case null:
        return 'قام $_actorLabel بإضافة بيان صرف بقيمة $amountLabel';
    }
  }

  /// سطر ثانوي لحالة بيان الصرف (اختياري).
  String? get decisionNote {
    if (isBalance) return null;
    if (expensePhase == CustodyExpensePhase.submitted &&
        status == ExpenseStatementModel.statusPending) {
      return 'بانتظار الاعتماد';
    }
    if (expensePhase == CustodyExpensePhase.rejected) {
      final reason = rejectionReason?.trim();
      if (reason != null && reason.isNotEmpty) return 'سبب الرفض: $reason';
    }
    return null;
  }

  bool matchesUser(int userId) =>
      actorUserId == userId || targetUserId == userId;
}
