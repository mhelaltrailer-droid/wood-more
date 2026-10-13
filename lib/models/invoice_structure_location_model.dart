double? _invNumOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s.replaceAll(',', ''));
}

int? _invInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

/// عقدة في شجرة هيكلة المستخلصات (مستقلة عن هيكلة المشروعات).
class InvoiceStructureLocationModel {
  final int id;
  final int projectId;
  final int? parentId;
  final String name;
  final String type; // 'folder' | 'work_site'
  final int displayOrder;
  final double? totalMeters;
  final double? meterPrice;
  final double? unitValue;

  const InvoiceStructureLocationModel({
    required this.id,
    required this.projectId,
    this.parentId,
    required this.name,
    required this.type,
    this.displayOrder = 0,
    this.totalMeters,
    this.meterPrice,
    this.unitValue,
  });

  bool get isFolder => type == 'folder';
  bool get isWorkSite => type == 'work_site';

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'parent_id': parentId,
        'name': name,
        'type': type,
        'display_order': displayOrder,
        'total_meters': totalMeters,
        'meter_price': meterPrice,
        'unit_value': unitValue,
      };

  factory InvoiceStructureLocationModel.fromMap(Map<String, dynamic> m) {
    return InvoiceStructureLocationModel(
      id: _invInt(m['id']) ?? 0,
      projectId: _invInt(m['project_id'] ?? m['projectId']) ?? 0,
      parentId: _invInt(m['parent_id'] ?? m['parentId']),
      name: (m['name'] ?? '').toString(),
      type: (m['type'] ?? 'folder').toString(),
      displayOrder:
          _invInt(m['display_order'] ?? m['displayOrder']) ?? 0,
      totalMeters: _invNumOrNull(m['total_meters'] ?? m['totalMeters']),
      meterPrice: _invNumOrNull(m['meter_price'] ?? m['meterPrice']),
      unitValue: _invNumOrNull(m['unit_value'] ?? m['unitValue']),
    );
  }
}

class InvoiceStructureProjectState {
  final int projectId;
  final String? measureType;
  final List<InvoiceStructureLocationModel> locations;

  const InvoiceStructureProjectState({
    required this.projectId,
    this.measureType,
    this.locations = const [],
  });

  bool get hasMeasureType =>
      measureType == 'flooring' || measureType == 'wpc';

  bool get isFlooring => measureType == 'flooring';
  bool get isWpc => measureType == 'wpc';

  factory InvoiceStructureProjectState.fromMap(Map<String, dynamic> m) {
    final locsRaw = m['locations'];
    final locs = locsRaw is List
        ? locsRaw
            .map(
              (e) => InvoiceStructureLocationModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <InvoiceStructureLocationModel>[];
    return InvoiceStructureProjectState(
      projectId: _invInt(m['project_id'] ?? m['projectId']) ?? 0,
      measureType: m['measure_type']?.toString() ?? m['measureType']?.toString(),
      locations: locs,
    );
  }
}
