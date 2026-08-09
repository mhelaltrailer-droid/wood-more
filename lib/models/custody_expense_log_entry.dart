import '../core/role_labels.dart';
import 'expense_statement_model.dart';

/// تصنيف حدث سجل العهد والمصروفات (يُستخدم للفلترة).
enum CustodyLogCategory { balance, expense }

/// حدث واحد في سجل حركات العهد والمصروفات — للعرض فقط.
///
/// يُبنى من مصدرين: حركات جدول [engineer_custody] وبيانات الصرف التي تم البت
/// فيها. لا يقابله جدول في قاعدة البيانات.
class CustodyExpenseLogEntry {
  /// مفتاح فريد عبر المصدرين معاً (لأن المعرفات تتكرر بين الجدولين).
  final String key;
  final CustodyLogCategory category;

  /// add_balance أو withdraw_balance لحركات الأرصدة، وفارغ لبيانات الصرف.
  final String movementType;
  final DateTime occurredAt;
  final int? actorUserId;
  final String actorName;
  final String actorRole;

  /// صاحب الرصيد المتأثر بالحركة.
  final int? targetUserId;
  final String targetName;
  final double amount;
  final String description;
  final String? projectName;
  final String? imagePath;

  /// approved أو rejected لبيانات الصرف فقط.
  final String? status;
  final String? rejectionReason;
  final String? respondedByName;

  const CustodyExpenseLogEntry({
    required this.key,
    required this.category,
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
  });

  bool get isBalance => category == CustodyLogCategory.balance;
  bool get isAddBalance => movementType == 'add_balance';
  bool get isRejected => status == ExpenseStatementModel.statusRejected;

  /// المبلغ بصيغة مختصرة: بدون كسور عندما يكون رقماً صحيحاً.
  String get amountLabel {
    final rounded = amount.roundToDouble();
    final text = amount == rounded
        ? rounded.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '$text جنيه';
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
    return 'قام $_actorLabel بإضافة بيان صرف بقيمة $amountLabel';
  }

  /// سطر ثانوي يوضح مَن اعتمد أو رفض بيان الصرف.
  String? get decisionNote {
    if (isBalance) return null;
    final by = respondedByName?.trim();
    if (by == null || by.isEmpty) return null;
    return isRejected ? 'تم الرفض بواسطة $by' : 'تم الاعتماد بواسطة $by';
  }

  bool matchesUser(int userId) =>
      actorUserId == userId || targetUserId == userId;
}
