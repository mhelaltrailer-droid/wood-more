import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<void> postJsonWithProgress({
  required Uri uri,
  required Map<String, dynamic> body,
  required void Function(int sent, int total) onProgress,
  Duration timeout = const Duration(minutes: 15),
}) async {
  final bodyBytes = utf8.encode(jsonEncode(body));
  final total = bodyBytes.length;
  final completer = Completer<void>();

  final xhr = html.HttpRequest();
  xhr.open('POST', uri.toString());
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.timeout = timeout.inMilliseconds;

  onProgress(0, total);

  xhr.upload.onProgress.listen((event) {
    if (event.lengthComputable == true) {
      final loaded = event.loaded ?? 0;
      final t = event.total ?? total;
      onProgress(loaded, t > 0 ? t : total);
    }
  });

  xhr.onLoad.listen((_) {
    final status = xhr.status ?? 0;
    if (status >= 400) {
      final text = xhr.responseText ?? '';
      completer.completeError(
        Exception(text.isNotEmpty ? text : 'HTTP $status'),
      );
    } else {
      onProgress(total, total);
      completer.complete();
    }
  });

  xhr.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('network_error'));
    }
  });

  xhr.onTimeout.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(TimeoutException('upload_timeout', timeout));
    }
  });

  xhr.send(bodyBytes);
  return completer.future;
}
