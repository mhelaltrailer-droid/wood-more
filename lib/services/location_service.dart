import 'package:geolocator/geolocator.dart';

/// خدمة الحصول على الموقع الجغرافي
class LocationService {
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
