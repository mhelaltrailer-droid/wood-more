/// رصيد خامة في مخزن مشروع (اسم المخزن = اسم المشروع)
class ProjectStockModel {
  final int id;
  final int projectId;
  final String materialName;
  final String quantity;
  final String unit;

  const ProjectStockModel({
    required this.id,
    required this.projectId,
    required this.materialName,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'material_name': materialName,
        'quantity': quantity,
        'unit': unit,
      };

  factory ProjectStockModel.fromMap(Map<String, dynamic> m) => ProjectStockModel(
        id: m['id'] as int,
        projectId: m['project_id'] as int,
        materialName: m['material_name'] as String,
        quantity: m['quantity'] as String,
        unit: m['unit'] as String,
      );
}
