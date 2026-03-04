/// وحدة داخل مبنى (مثال: Th1-M01، Th2-M02)
class UnitModel {
  final int id;
  final int buildingId;
  final String name;   // اسم الوحدة مثل Th1-M01
  final String model;   // النموذج مثل M01, M02
  final String? imagePath; // مسار أو base64 للصورة

  const UnitModel({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.model,
    this.imagePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'building_id': buildingId,
        'name': name,
        'model': model,
        'image_path': imagePath,
      };

  factory UnitModel.fromMap(Map<String, dynamic> m) => UnitModel(
        id: m['id'] as int,
        buildingId: m['building_id'] as int,
        name: m['name'] as String,
        model: m['model'] as String,
        imagePath: m['image_path'] as String?,
      );
}
