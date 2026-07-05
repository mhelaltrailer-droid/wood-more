Future<void> postJsonWithProgress({
  required Uri uri,
  required Map<String, dynamic> body,
  required void Function(int sent, int total) onProgress,
  Duration timeout = const Duration(minutes: 15),
}) async {
  throw UnsupportedError('postJsonWithProgress is not supported on this platform');
}
