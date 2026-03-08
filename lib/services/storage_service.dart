import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'web_storage_service.dart';
import 'api_storage_service.dart';

dynamic _storageInstance;

/// Load API base URL from config. On web: from config.json (same origin). On mobile/desktop: from assets/config.json.
Future<String?> _loadApiBaseUrl() async {
  if (kIsWeb) {
    try {
      final uri = Uri.base.resolve('config.json');
      final r = await http.get(uri);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final url = j['apiBaseUrl'] as String?;
        return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
      }
    } catch (_) {}
    return null;
  }
  try {
    final s = await rootBundle.loadString('assets/config.json');
    final j = jsonDecode(s) as Map<String, dynamic>;
    final url = j['apiBaseUrl'] as String?;
    return (url != null && url.trim().isNotEmpty) ? url.trim() : null;
  } catch (_) {}
  return null;
}

/// Initialize storage. If apiBaseUrl is set in config (web: config.json, mobile/desktop: assets/config.json), uses backend API. Otherwise: web → browser storage, mobile/desktop → local SQLite.
Future<void> initStorage() async {
  if (_storageInstance != null) return;
  final apiBaseUrl = await _loadApiBaseUrl();
  if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
    _storageInstance = ApiStorageService(apiBaseUrl);
    return;
  }
  if (kIsWeb) {
    _storageInstance = WebStorageService();
    return;
  }
  _storageInstance = DatabaseService();
}

/// Return the storage service. Must call [initStorage] first (e.g. from main).
dynamic getStorage() {
  assert(_storageInstance != null, 'Call initStorage() before getStorage()');
  return _storageInstance!;
}
