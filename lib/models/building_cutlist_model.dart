/// صورة قطعيات لمبنى (يطلع عليها مهندس الموقع)
class BuildingCutlistModel {
  final int id;
  final int buildingId;
  final String imagePath; // مسار أو base64 للصورة

  const BuildingCutlistModel({
    required this.id,
    required this.buildingId,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'building_id': buildingId,
        'image_path': imagePath,
      };

  factory BuildingCutlistModel.fromMap(Map<String, dynamic> m) => BuildingCutlistModel(
        id: m['id'] as int,
        buildingId: m['building_id'] as int,
        imagePath: m['image_path'] as String,
      );
}
