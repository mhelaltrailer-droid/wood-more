import 'package:hive_flutter/hive_flutter.dart';

class LocalCacheService {
  LocalCacheService._();

  static const String _boxName = 'app_cache_box';
  static final LocalCacheService instance = LocalCacheService._();

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  Future<void> setMap(
    String key,
    Map<String, dynamic> value, {
    Duration? ttl,
  }) async {
    final now = DateTime.now();
    final payload = <String, dynamic>{
      'value': value,
      'savedAt': now.toIso8601String(),
      'expiresAt': ttl == null ? null : now.add(ttl).toIso8601String(),
    };
    await _box.put(key, payload);
  }

  Map<String, dynamic>? getMap(String key) {
    final raw = _box.get(key);
    if (raw is! Map) return null;
    final payload = Map<String, dynamic>.from(raw as Map);
    final expiresAtRaw = payload['expiresAt']?.toString();
    if (expiresAtRaw != null && expiresAtRaw.isNotEmpty) {
      final expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        _box.delete(key);
        return null;
      }
    }
    final value = payload['value'];
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value as Map);
  }
}
