import 'package:intl/intl.dart';

/// بيان صرف عهدة (بند واحد) — بانتظار الاعتماد / معتمد / مرفوض
class ExpenseStatementModel {
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  /// البريد المصرح له باعتماد/رفض بيانات الصرف.
  static const String approverEmail = 'abdelrhmanellaithy828@gmail.com';

  final int id;
  final int submitterUserId;
  final String submitterUserName;
  final String submitterRole;
  final int balanceUserId;
  final int? projectId;
  final String? projectName;
  final String description;
  final double amount;
  final String? imagePath;
  final String status;
  final String? rejectionReason;
  final int? respondedByUserId;
  final String? respondedByUserName;
  final DateTime? respondedAt;
  final DateTime createdAt;

  /// يوم الصرف الفعلي (تاريخ فقط، بدون وقت).
  final DateTime expenseDate;
  final String source;

  /// رصيد المهندس بعد الاعتماد/الخصم — null للحركات القديمة قبل إضافة العمود.
  final double? balanceAfter;

  const ExpenseStatementModel({
    required this.id,
    required this.submitterUserId,
    required this.submitterUserName,
    required this.submitterRole,
    required this.balanceUserId,
    this.projectId,
    this.projectName,
    required this.description,
    required this.amount,
    this.imagePath,
    required this.status,
    this.rejectionReason,
    this.respondedByUserId,
    this.respondedByUserName,
    this.respondedAt,
    required this.createdAt,
    required this.expenseDate,
    this.source = 'engineer',
    this.balanceAfter,
  });

  bool get isPending => status == statusPending;
  bool get isApproved => status == statusApproved;
  bool get isRejected => status == statusRejected;

  DateTime get expenseDateOnly =>
      DateTime(expenseDate.year, expenseDate.month, expenseDate.day);

  DateTime get createdDateOnly {
    final c = createdAt.toLocal();
    return DateTime(c.year, c.month, c.day);
  }

  /// هل يوم الصرف يختلف عن يوم إدخال البيان في النظام.
  bool get expenseDateDiffersFromCreated =>
      expenseDateOnly != createdDateOnly;

  String get statusLabelAr {
    switch (status) {
      case statusApproved:
        return 'معتمد';
      case statusRejected:
        return 'تم الرفض';
      default:
        return 'بانتظار الاعتماد';
    }
  }

  /// نص عرض التواريخ: سطر واحد إن تطابقا، وسطران إن اختلفا.
  String datesLabelAr({DateFormat? dayFormat}) {
    final fmt = dayFormat ?? DateFormat('yyyy/MM/dd', 'ar');
    final spent = fmt.format(expenseDateOnly);
    if (!expenseDateDiffersFromCreated) {
      return 'تم الصرف والإدخال يوم: $spent';
    }
    final entered = fmt.format(createdDateOnly);
    return 'تم الصرف يوم: $spent\nتم الإدخال يوم: $entered';
  }

  static DateTime _dateOnlyFromCreated(DateTime created) {
    final c = created.toLocal();
    return DateTime(c.year, c.month, c.day);
  }

  static DateTime _parseExpenseDate(dynamic raw, DateTime createdAt) {
    final fallback = _dateOnlyFromCreated(createdAt);
    if (raw == null) return fallback;
    final s = raw.toString().trim();
    if (s.isEmpty) return fallback;
    final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (ymd != null) {
      return DateTime(
        int.parse(ymd.group(1)!),
        int.parse(ymd.group(2)!),
        int.parse(ymd.group(3)!),
      );
    }
    final parsed = DateTime.tryParse(s);
    if (parsed == null) return fallback;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  factory ExpenseStatementModel.fromMap(Map<String, dynamic> map) {
    int? pInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    double pDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }

    DateTime? pDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final createdAt = pDate(map['created_at'] ?? map['createdAt']) ?? DateTime.now();
    final expenseDate = _parseExpenseDate(
      map['expense_date'] ?? map['expenseDate'],
      createdAt,
    );

    return ExpenseStatementModel(
      id: pInt(map['id']) ?? 0,
      submitterUserId: pInt(map['submitter_user_id'] ?? map['submitterUserId']) ?? 0,
      submitterUserName:
          (map['submitter_user_name'] ?? map['submitterUserName'] ?? '').toString(),
      submitterRole: (map['submitter_role'] ?? map['submitterRole'] ?? '').toString(),
      balanceUserId: pInt(map['balance_user_id'] ?? map['balanceUserId']) ?? 0,
      projectId: pInt(map['project_id'] ?? map['projectId']),
      projectName: map['project_name']?.toString() ?? map['projectName']?.toString(),
      description: (map['description'] ?? '').toString(),
      amount: pDouble(map['amount']),
      imagePath: map['image_path']?.toString() ?? map['imagePath']?.toString(),
      status: (map['status'] ?? statusPending).toString(),
      rejectionReason:
          map['rejection_reason']?.toString() ?? map['rejectionReason']?.toString(),
      respondedByUserId: pInt(map['responded_by_user_id'] ?? map['respondedByUserId']),
      respondedByUserName: map['responded_by_user_name']?.toString() ??
          map['respondedByUserName']?.toString(),
      respondedAt: pDate(map['responded_at'] ?? map['respondedAt']),
      createdAt: createdAt,
      expenseDate: expenseDate,
      source: (map['source'] ?? 'engineer').toString(),
      balanceAfter: () {
        final raw = map['balance_after'] ?? map['balanceAfter'];
        if (raw == null) return null;
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw.toString());
      }(),
    );
  }
}
