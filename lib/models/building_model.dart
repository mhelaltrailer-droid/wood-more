/// مبنى ضمن منطقة
class BuildingModel {
  final int id;
  final int zoneId;
  final String name;
  final String? storageInfo;
  final String? modelDetails;
  final String? cutList;

  const BuildingModel({
    required this.id,
    required this.zoneId,
    required this.name,
    this.storageInfo,
    this.modelDetails,
    this.cutList,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'zone_id': zoneId,
        'name': name,
        'storage_info': storageInfo,
        'model_details': modelDetails,
        'cut_list': cutList,
      };

  factory BuildingModel.fromMap(Map<String, dynamic> m) => BuildingModel(
        id: m['id'] as int,
        zoneId: m['zone_id'] as int,
        name: m['name'] as String,
        storageInfo: m['storage_info'] as String?,
        modelDetails: m['model_details'] as String?,
        cutList: m['cut_list'] as String?,
      );
}
