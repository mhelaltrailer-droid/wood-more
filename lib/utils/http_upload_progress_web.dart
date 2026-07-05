import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> postJsonWithProgress({
  required Uri uri,
  required Map<String, dynamic> body,
  required void Function(int sent, int total) onProgress,
  Duration timeout = const Duration(minutes: 15),
}) async {
  final bodyBytes = utf8.encode(jsonEncode(body));
  onProgress(0, bodyBytes.length);
  final response = await http
      .post(
        uri,
        body: bodyBytes,
        headers: {'Content-Type': 'application/json'},
      )
      .timeout(timeout);
  onProgress(bodyBytes.length, bodyBytes.length);
  if (response.statusCode >= 400) {
    throw Exception(
      response.body.isNotEmpty ? response.body : 'HTTP ${response.statusCode}',
    );
  }
}
