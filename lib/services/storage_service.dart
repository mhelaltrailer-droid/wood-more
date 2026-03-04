import 'package:flutter/foundation.dart' show kIsWeb;
import 'database_service.dart';
import 'web_storage_service.dart';

/// إرجاع خدمة التخزين المناسبة - ويب أو موبايل
dynamic getStorage() {
  if (kIsWeb) {
    return WebStorageService();
  }
  return DatabaseService();
}
