/// سجل سحب الخامات من موقع فرعي (مرة واحدة فقط لكل موقع)
class LocationWithdrawalModel {
  final int id;
  final int locationId;
  final int userId;
  final String userName;
  final DateTime createdAt;
  final String? disbursementPermitImagesJson;
  final String? deliveryPermitImagesJson;

  const LocationWithdrawalModel({
    required this.id,
    required this.locationId,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.disbursementPermitImagesJson,
    this.deliveryPermitImagesJson,
  });

  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  factory LocationWithdrawalModel.fromMap(Map<String, dynamic> m) {
    final createdAtStr = m['created_at'] ?? m['createdAt'] ?? '';
    DateTime dt = DateTime.now();
    if (createdAtStr.toString().isNotEmpty) {
      dt = DateTime.tryParse(createdAtStr.toString()) ?? dt;
    }
    return LocationWithdrawalModel(
      id: _int(m['id']),
      locationId: _int(m['location_id'] ?? m['locationId']),
      userId: _int(m['user_id'] ?? m['userId']),
      userName: (m['user_name'] ?? m['userName'] ?? '') as String,
      createdAt: dt,
      disbursementPermitImagesJson: m['disbursement_permit_images_json'] ?? m['disbursementPermitImagesJson'] as String?,
      deliveryPermitImagesJson: m['delivery_permit_images_json'] ?? m['deliveryPermitImagesJson'] as String?,
    );
  }
}
