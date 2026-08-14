import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_storage_service.dart';
import 'egypt_local_time.dart';
import 'open_stored_attachment.dart';
import 'reports_sys_attachment_save.dart';

String meetingsApiError(Object error) {
  var text = error.toString();
  if (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map && decoded['error'] != null) {
      return decoded['error'].toString();
    }
  } catch (_) {}
  return text;
}

String egyptWallClockToIso(DateTime date, TimeOfDay time) {
  final utc = DateTime.utc(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).subtract(egyptUtcOffset);
  return utc.toIso8601String();
}

Future<void> openMeetingPdf({
  required BuildContext context,
  required ApiStorageService storage,
  required int userId,
  required int meetingId,
  required String fileType,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final file = await storage.getMeetingFileData(
      userId: userId,
      meetingId: meetingId,
      fileType: fileType,
    );
    final raw = file['data_base64'] ?? '';
    final bytes = base64Decode(raw);
    final mime = file['mime_type'] ?? 'application/pdf';
    final name = file['file_name']?.isNotEmpty == true
        ? file['file_name']!
        : 'meeting.pdf';
    if (context.mounted) Navigator.of(context).pop();
    final err = await openStoredAttachment(
      bytes: bytes,
      fileName: name,
      dataUrl: 'data:$mime;base64,$raw',
    );
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الملف: $err')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(meetingsApiError(e))),
      );
    }
  }
}

Future<void> downloadMeetingPdf({
  required BuildContext context,
  required ApiStorageService storage,
  required int userId,
  required int meetingId,
  required String fileType,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final file = await storage.getMeetingFileData(
      userId: userId,
      meetingId: meetingId,
      fileType: fileType,
    );
    final raw = file['data_base64'] ?? '';
    final bytes = base64Decode(raw);
    final mime = file['mime_type'] ?? 'application/pdf';
    final name = file['file_name']?.isNotEmpty == true
        ? file['file_name']!
        : 'meeting.pdf';
    if (context.mounted) Navigator.of(context).pop();
    final err = await saveReportsSysAttachment(
      bytes: bytes,
      fileName: name,
      mimeType: mime,
    );
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تنزيل الملف: $err')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تنزيل الملف')),
    );
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(meetingsApiError(e))),
      );
    }
  }
}
