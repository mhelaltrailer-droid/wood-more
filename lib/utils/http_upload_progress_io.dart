import 'dart:convert';
import 'dart:io';

Future<void> postJsonWithProgress({
  required Uri uri,
  required Map<String, dynamic> body,
  required void Function(int sent, int total) onProgress,
  Duration timeout = const Duration(minutes: 15),
}) async {
  final bodyBytes = utf8.encode(jsonEncode(body));
  final client = HttpClient();
  client.connectionTimeout = timeout;
  try {
    final request = await client.postUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.contentLength = bodyBytes.length;
    const slice = 64 * 1024;
    var sent = 0;
    while (sent < bodyBytes.length) {
      final end =
          sent + slice < bodyBytes.length ? sent + slice : bodyBytes.length;
      request.add(bodyBytes.sublist(sent, end));
      sent = end;
      onProgress(sent, bodyBytes.length);
      await Future<void>.delayed(Duration.zero);
    }
    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) {
      throw Exception(
        responseBody.isNotEmpty
            ? responseBody
            : 'HTTP ${response.statusCode}',
      );
    }
  } finally {
    client.close(force: true);
  }
}
