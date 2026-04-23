/// سحب خامات ضمن فترة (للتقرير المجمع): موقع + مهندس + تاريخ + قائمة الخامات من سجل المخزن
class WithdrawalMaterialLine {
  final String materialName;
  final String quantity;
  final String unit;

  const WithdrawalMaterialLine({
    required this.materialName,
    required this.quantity,
    required this.unit,
  });

  factory WithdrawalMaterialLine.fromMap(Map<String, dynamic> m) {
    return WithdrawalMaterialLine(
      materialName: (m['material_name'] ?? m['materialName'] ?? '').toString(),
      quantity: (m['quantity'] ?? '').toString(),
      unit: (m['unit'] ?? '').toString(),
    );
  }
}

class LocationWithdrawalForPeriodModel {
  final int locationId;
  final int userId;
  final String userName;
  final DateTime createdAt;
  final int projectId;
  final List<WithdrawalMaterialLine> materials;

  const LocationWithdrawalForPeriodModel({
    required this.locationId,
    required this.userId,
    required this.userName,
    required this.createdAt,
    required this.projectId,
    this.materials = const [],
  });

  factory LocationWithdrawalForPeriodModel.fromMap(Map<String, dynamic> m) {
    final createdStr = (m['created_at'] ?? m['createdAt'] ?? '').toString();
    final dt = DateTime.tryParse(createdStr) ?? DateTime.now();
    final matList = m['materials'] as List<dynamic>?;
    final mats = matList == null
        ? <WithdrawalMaterialLine>[]
        : matList
            .map((e) => WithdrawalMaterialLine.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
    int p(dynamic v) => v is int ? v : int.parse(v.toString());
    return LocationWithdrawalForPeriodModel(
      locationId: p(m['location_id'] ?? m['locationId']),
      userId: p(m['user_id'] ?? m['userId']),
      userName: (m['user_name'] ?? m['userName'] ?? '').toString(),
      createdAt: dt,
      projectId: p(m['project_id'] ?? m['projectId']),
      materials: mats,
    );
  }
}
