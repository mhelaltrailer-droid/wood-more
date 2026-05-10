/// خامة مخصصة لموقع فرعي (هيكلة المخازن) — تظهر لمهندس الموقع للسحب
class LocationMaterialModel {
  static const String phaseFirstFix = 'first_fix';
  static const String phaseSecondFix = 'second_fix';
  static const List<String> phases = [phaseFirstFix, phaseSecondFix];

  static String phaseLabel(String phase) {
    switch (phase) {
      case phaseSecondFix:
        return 'Second-fix';
      case phaseFirstFix:
      default:
        return 'First-fix';
    }
  }

  final int id;
  final int locationId;
  final String phase;
  final String materialName;
  final String quantity;
  final String unit;

  const LocationMaterialModel({
    required this.id,
    required this.locationId,
    this.phase = phaseFirstFix,
    required this.materialName,
    required this.quantity,
    this.unit = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'location_id': locationId,
        'phase': phase,
        'material_name': materialName,
        'quantity': quantity,
        'unit': unit,
      };

  factory LocationMaterialModel.fromMap(Map<String, dynamic> m) {
    return LocationMaterialModel(
      id: _int(m['id']),
      locationId: _int(m['location_id'] ?? m['locationId']),
      phase: _normalizePhase((m['phase'] ?? m['phase_name'] ?? '').toString()),
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

  static String _normalizePhase(String v) {
    final x = v.trim().toLowerCase();
    if (x == phaseSecondFix) return phaseSecondFix;
    return phaseFirstFix;
  }
}
