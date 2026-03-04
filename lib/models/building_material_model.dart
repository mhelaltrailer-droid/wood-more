/// تشوينات مبنى: الخامة، الطول، عدد القطعة، إجمالي الطول، إجمالي المساحة، صورة
class BuildingMaterialModel {
  final int id;
  final int buildingId;
  final String materialName;
  final String length;
  final String piecesCount;
  final String totalLength;
  final String totalArea;
  final String? imagePath;

  const BuildingMaterialModel({
    required this.id,
    required this.buildingId,
    required this.materialName,
    this.length = '',
    this.piecesCount = '',
    this.totalLength = '',
    this.totalArea = '',
    this.imagePath,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'building_id': buildingId,
        'material_name': materialName,
        'length': length,
        'pieces_count': piecesCount,
        'total_length': totalLength,
        'total_area': totalArea,
        'image_path': imagePath,
      };

  factory BuildingMaterialModel.fromMap(Map<String, dynamic> m) => BuildingMaterialModel(
        id: m['id'] as int,
        buildingId: m['building_id'] as int,
        materialName: m['material_name'] as String? ?? '',
        length: m['length'] as String? ?? '',
        piecesCount: m['pieces_count'] as String? ?? '',
        totalLength: m['total_length'] as String? ?? '',
        totalArea: m['total_area'] as String? ?? '',
        imagePath: m['image_path'] as String?,
      );
}
