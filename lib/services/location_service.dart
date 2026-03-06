import 'package:geolocator/geolocator.dart';

/// خدمة الحصول على الموقع الجغرافي
class LocationService {
  /// طلب إذن الموقع. يعيد true إذا مُنح الإذن، false إذا رُفض أو مُنع نهائياً.
  static Future<bool> requestPermissionIfNeeded() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// يتحقق من أن النص يمثل إحداثيات صالحة (خط عرض، خط طول) وليس رسالة خطأ
  static bool looksLikeCoordinates(String location) {
    final parts = location.split(',').map((s) => s.trim()).toList();
    if (parts.length != 2) return false;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    return lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  static Future<String> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'خدمة الموقع غير مفعلة';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return 'تم رفض إذن الموقع';
      }
      if (permission == LocationPermission.denied) {
        return 'لم يتم منح إذن الموقع';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      return 'تعذر الحصول على الموقع: $e';
    }
  }
}
