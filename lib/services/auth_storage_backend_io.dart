import 'package:shared_preferences/shared_preferences.dart';

Future<String?> readAuthStorageValue(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<void> writeAuthStorageValue(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> removeAuthStorageValue(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}
