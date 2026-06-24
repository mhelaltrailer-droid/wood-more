import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import 'auth_storage_backend.dart';

const String _keyAuth = 'wood_more_auth';
const String _keyCurrentUserLegacy = 'wood_more_current_user';
const String _keyLastRouteLegacy = 'wood_more_last_route';

/// On web, auth lives in [sessionStorage] (cleared when the browser session ends).
/// Call once at startup to drop any old localStorage-based sessions.
Future<void> initAuthPersistence() async {
  if (kIsWeb) {
    await _clearLegacyPersistentAuth();
  }
}

Future<void> _clearLegacyPersistentAuth() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyAuth);
  await prefs.remove(_keyCurrentUserLegacy);
  await prefs.remove(_keyLastRouteLegacy);
}

Future<Map<String, dynamic>?> _readAuthBlob() async {
  final json = await readAuthStorageValue(_keyAuth);
  if (json != null && json.isNotEmpty) {
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {}
  }
  return null;
}

Future<void> _writeAuthBlob(Map<String, dynamic> blob) async {
  await writeAuthStorageValue(_keyAuth, jsonEncode(blob));
}

/// Persist the current user (and optionally preserve lastRoute). Use this on login.
Future<void> saveCurrentUser(UserModel user, [String? lastRoute]) async {
  final existing = await _readAuthBlob();
  final currentRoute = lastRoute ?? existing?['lastRoute'] as String? ?? 'home';
  await _writeAuthBlob({
    'user': user.toMap(),
    'lastRoute': currentRoute,
  });
}

/// Restore the current user from storage. Returns null if none or invalid.
Future<UserModel?> getStoredUser() async {
  var blob = await _readAuthBlob();
  if (blob == null && !kIsWeb) {
    final legacyJson = await readAuthStorageValue(_keyCurrentUserLegacy);
    if (legacyJson != null && legacyJson.isNotEmpty) {
      try {
        final map = jsonDecode(legacyJson) as Map<String, dynamic>;
        final id = map['id'];
        final user = UserModel(
          id: id is int ? id : int.parse(id.toString()),
          name: map['name'] as String,
          email: map['email'] as String,
          role: map['role'] as String,
        );
        await saveCurrentUser(user, await getLastRoute());
        await removeAuthStorageValue(_keyCurrentUserLegacy);
        await removeAuthStorageValue(_keyLastRouteLegacy);
        return user;
      } catch (_) {}
    }
    return null;
  }
  if (blob == null) return null;
  final userMap = blob['user'];
  if (userMap == null || userMap is! Map<String, dynamic>) return null;
  try {
    final id = userMap['id'];
    return UserModel(
      id: id is int ? id : int.parse(id.toString()),
      name: userMap['name'] as String,
      email: userMap['email'] as String,
      role: userMap['role'] as String,
    );
  } catch (_) {
    return null;
  }
}

/// Clear the stored user and route (on logout).
Future<void> clearCurrentUser() async {
  await removeAuthStorageValue(_keyAuth);
  await removeAuthStorageValue(_keyCurrentUserLegacy);
  await removeAuthStorageValue(_keyLastRouteLegacy);
  if (kIsWeb) {
    await _clearLegacyPersistentAuth();
  }
}

/// Save the current route so refresh restores the same page. Stored with user in same blob.
Future<void> saveLastRoute(String name) async {
  final existing = await _readAuthBlob();
  if (existing != null && existing['user'] != null) {
    await _writeAuthBlob({
      'user': existing['user'],
      'lastRoute': name,
    });
  } else {
    await writeAuthStorageValue(_keyLastRouteLegacy, name);
  }
}

/// Restore the last route. Reads from same blob as user.
Future<String?> getLastRoute() async {
  final blob = await _readAuthBlob();
  if (blob != null) {
    final r = blob['lastRoute'];
    if (r != null && r is String) return r.isEmpty ? null : r;
  }
  return readAuthStorageValue(_keyLastRouteLegacy);
}

/// Clear only the last route (e.g. when navigating back to home).
Future<void> clearLastRoute() async {
  final blob = await _readAuthBlob();
  if (blob != null) {
    await _writeAuthBlob({
      'user': blob['user'],
      'lastRoute': 'home',
    });
  }
  await removeAuthStorageValue(_keyLastRouteLegacy);
}
