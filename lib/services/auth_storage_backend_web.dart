import 'dart:html' as html;

Future<String?> readAuthStorageValue(String key) async {
  return html.window.sessionStorage[key];
}

Future<void> writeAuthStorageValue(String key, String value) async {
  html.window.sessionStorage[key] = value;
}

Future<void> removeAuthStorageValue(String key) async {
  html.window.sessionStorage.remove(key);
}
