import 'dart:convert';

/// بيانات التقرير اليومي (يمر بين الخطوات الثلاث)
class DailyReportData {
  final String userName;
  final int userId;
  int? projectId;
  String? projectName;
  final DateTime reportDate;
  String workPlace;
  String workReport;
  String executedToday;
  String supervisorName;
  String contractorName;
  String workersCount;
  String tomorrowPlan;
  String? documentPath;
  List<String> imagePaths;
  String notes;
  List<MaterialItem> materials;
  List<ExpenseItem> expenses;

  DailyReportData({
    required this.userName,
    required this.userId,
    this.projectId,
    this.projectName,
    required this.reportDate,
    this.workPlace = '',
    this.workReport = '',
    this.executedToday = '',
    this.supervisorName = '',
    this.contractorName = '',
    this.workersCount = '',
    this.tomorrowPlan = '',
    this.documentPath,
    List<String>? imagePaths,
    this.notes = '',
    List<MaterialItem>? materials,
    List<ExpenseItem>? expenses,
  })  : imagePaths = imagePaths ?? [],
        materials = materials ?? List.generate(5, (_) => MaterialItem()),
        expenses = expenses ?? List.generate(4, (_) => ExpenseItem());

  Map<String, dynamic> toJson() => {
        'user_name': userName,
        'user_id': userId,
        'project_id': projectId,
        'project_name': projectName,
        'report_date': reportDate.toIso8601String(),
        'work_place': workPlace,
        'work_report': workReport,
        'executed_today': executedToday,
        'supervisor_name': supervisorName,
        'contractor_name': contractorName,
        'workers_count': workersCount,
        'tomorrow_plan': tomorrowPlan,
        'document_path': documentPath,
        'image_paths': imagePaths,
        'notes': notes,
        'materials': materials.map((m) => m.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
      };

  factory DailyReportData.fromJson(Map<String, dynamic> map) {
    return DailyReportData(
      userName: map['user_name'] as String,
      userId: map['user_id'] as int,
      projectId: map['project_id'] as int?,
      projectName: map['project_name'] as String?,
      reportDate: DateTime.parse(map['report_date'] as String),
      workPlace: map['work_place'] as String? ?? '',
      workReport: map['work_report'] as String? ?? '',
      executedToday: map['executed_today'] as String? ?? '',
      supervisorName: map['supervisor_name'] as String? ?? '',
      contractorName: map['contractor_name'] as String? ?? '',
      workersCount: map['workers_count'] as String? ?? '',
      tomorrowPlan: map['tomorrow_plan'] as String? ?? '',
      documentPath: map['document_path'] as String?,
      imagePaths: List<String>.from(map['image_paths'] as List? ?? []),
      notes: map['notes'] as String? ?? '',
      materials: (map['materials'] as List?)
              ?.map((m) => MaterialItem.fromJson(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          List.generate(5, (_) => MaterialItem()),
      expenses: (map['expenses'] as List?)
              ?.map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          List.generate(4, (_) => ExpenseItem()),
    );
  }

  /// من صف جدول daily_reports في SQLite
  factory DailyReportData.fromDbMap(Map<String, dynamic> row) {
    final materialsJson = row['materials_json'] as String? ?? '[]';
    final expensesJson = row['expenses_json'] as String? ?? '[]';
    return DailyReportData(
      userName: row['user_name'] as String,
      userId: row['user_id'] as int,
      projectId: row['project_id'] as int?,
      projectName: row['project_name'] as String?,
      reportDate: DateTime.parse(row['report_datetime'] as String),
      workPlace: row['work_place'] as String? ?? '',
      workReport: row['work_report'] as String? ?? '',
      executedToday: row['executed_today'] as String? ?? '',
      supervisorName: row['supervisor_name'] as String? ?? '',
      contractorName: row['contractor_name'] as String? ?? '',
      workersCount: row['workers_count'] as String? ?? '',
      tomorrowPlan: row['tomorrow_plan'] as String? ?? '',
      documentPath: row['document_path'] as String?,
      imagePaths: List<String>.from(jsonDecode(row['images_json'] as String? ?? '[]') as List),
      notes: row['notes'] as String? ?? '',
      materials: (jsonDecode(materialsJson) as List)
          .map((m) => MaterialItem.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
      expenses: (jsonDecode(expensesJson) as List)
          .map((e) => ExpenseItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class MaterialItem {
  String materialName;
  String quantity;
  String unit;

  MaterialItem({this.materialName = '', this.quantity = '', this.unit = ''});

  Map<String, dynamic> toJson() => {
        'material': materialName,
        'quantity': quantity,
        'unit': unit,
      };

  factory MaterialItem.fromJson(Map<String, dynamic> map) => MaterialItem(
        materialName: map['material'] as String? ?? '',
        quantity: map['quantity'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
      );
}

class ExpenseItem {
  String description;
  String amount;
  String? imagePath;

  ExpenseItem({this.description = '', this.amount = '', this.imagePath});

  Map<String, dynamic> toJson() => {
        'description': description,
        'amount': amount,
        'image_path': imagePath,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> map) => ExpenseItem(
        description: map['description'] as String? ?? '',
        amount: map['amount'] as String? ?? '',
        imagePath: map['image_path'] as String?,
      );
}

/// وحدات القياس للخامات
const List<String> materialUnits = [
  'متر',
  'متر مربع',
  'متر مكعب',
  'كيلو جرام',
  'متر طولي',
  'عود',
];
