import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

const String _keyCurrentUser = 'wood_more_current_user';

/// Persist the current user so they stay logged in after refresh.
Future<void> saveCurrentUser(UserModel user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyCurrentUser, jsonEncode(user.toMap()));
}

/// Restore the current user from storage (e.g. on app start / after refresh).
Future<UserModel?> getStoredUser() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyCurrentUser);
    if (json == null || json.isEmpty) return null;
    final map = jsonDecode(json) as Map<String, dynamic>;
    final id = map['id'];
    return UserModel(
      id: id is int ? id : int.parse(id.toString()),
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
    );
  } catch (_) {
    return null;
  }
}

/// Clear the stored user (on logout).
Future<void> clearCurrentUser() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_keyCurrentUser);
}
