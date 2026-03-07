/// سجل حركة رصيد خامة في مخزن مشروع (إضافة / تعديل / سحب من تقرير)
class ProjectStockLedgerModel {
  final int id;
  final int projectId;
  final String materialName;
  final String unit;
  /// موجب = إضافة، سالب = سحب
  final double quantityDelta;
  /// add | edit | deduct_report
  final String type;
  final DateTime createdAt;
  final int? userId;
  final String userName;

  const ProjectStockLedgerModel({
    required this.id,
    required this.projectId,
    required this.materialName,
    required this.unit,
    required this.quantityDelta,
    required this.type,
    required this.createdAt,
    this.userId,
    required this.userName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'material_name': materialName,
        'unit': unit,
        'quantity_delta': quantityDelta,
        'type': type,
        'created_at': createdAt.toIso8601String(),
        'user_id': userId,
        'user_name': userName,
      };

  factory ProjectStockLedgerModel.fromMap(Map<String, dynamic> m) =>
      ProjectStockLedgerModel(
        id: m['id'] as int,
        projectId: m['project_id'] as int,
        materialName: m['material_name'] as String,
        unit: m['unit'] as String,
        quantityDelta: (m['quantity_delta'] as num).toDouble(),
        type: m['type'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        userId: m['user_id'] as int?,
        userName: m['user_name'] as String? ?? '',
      );
}
