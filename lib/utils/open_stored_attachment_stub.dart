import 'dart:typed_data';

import 'package:url_launcher/url_launcher.dart';

/// على الويب: محاولة فتح data URL مباشرة.
Future<String?> openStoredAttachment({
  required Uint8List bytes,
  required String fileName,
  String? dataUrl,
}) async {
  final uri = dataUrl != null ? Uri.tryParse(dataUrl) : null;
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, webOnlyWindowName: '_blank');
    return null;
  }
  return 'unsupported';
}
