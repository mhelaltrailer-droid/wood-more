/// خامة مخصصة لموقع فرعي (هيكلة المخازن) — تظهر لمهندس الموقع للسحب
class LocationMaterialModel {
  final int id;
  final int locationId;
  final String materialName;
  final String quantity;
  final String unit;

  const LocationMaterialModel({
    required this.id,
    required this.locationId,
    required this.materialName,
    required this.quantity,
    this.unit = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'material_name': materialName,
        'quantity': quantity,
        'unit': unit,
      };

  factory LocationMaterialModel.fromMap(Map<String, dynamic> m) {
    return LocationMaterialModel(
      id: _int(m['id']),
      locationId: _int(m['location_id'] ?? m['locationId']),
      materialName: (m['material_name'] ?? m['materialName'] ?? '') as String,
      quantity: (m['quantity'] ?? '') as String,
      unit: (m['unit'] ?? '') as String,
    );
  }

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
