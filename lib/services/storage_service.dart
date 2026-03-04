import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'database_service.dart';
import 'web_storage_service.dart';
import 'api_storage_service.dart';

dynamic _storageInstance;

/// Initialize storage. On web, fetches config.json and uses API if apiBaseUrl is set.
Future<void> initStorage() async {
  if (_storageInstance != null) return;
  if (kIsWeb) {
    try {
      final uri = Uri.base.resolve('config.json');
      final r = await http.get(uri);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final apiBaseUrl = j['apiBaseUrl'] as String?;
        if (apiBaseUrl != null && apiBaseUrl.isNotEmpty) {
          _storageInstance = ApiStorageService(apiBaseUrl);
          return;
        }
      }
    } catch (_) {}
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
