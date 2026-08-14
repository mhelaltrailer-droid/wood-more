import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/meeting_constants.dart';
import '../models/meeting_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/meetings_ui.dart';
import '../utils/notification_time_display.dart';

class MeetingDetailScreen extends StatefulWidget {
  final UserModel currentUser;
  final int meetingId;

  const MeetingDetailScreen({
    super.key,
    required this.currentUser,
    required this.meetingId,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  MeetingModel? _meeting;
  bool _loading = true;
  String? _error;
  String? _busyType;

  bool get _canUpload => widget.currentUser.canUploadMeetings;
  bool get _canDelete => widget.currentUser.canDeleteMeetings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final storage = getStorage();
      if (storage is! ApiStorageService) {
        throw Exception('يتطلب اتصال API');
      }
      final meeting = await storage.getMeetingDetail(
        userId: widget.currentUser.id,
        meetingId: widget.meetingId,
      );
      if (!mounted) return;
      setState(() {
        _meeting = meeting;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = meetingsApiError(e);
      });
    }
  }

  bool _previousUploaded(String fileType) {
    final prev = previousMeetingFileType(fileType);
    if (prev == null) return true;
    return _meeting?.fileOf(prev) != null;
  }

  Future<void> _pickAndUpload(String fileType, {required bool replacing}) async {
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    if (bytes.length > meetingsMaxFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الملف أكبر من 5 ميجا'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _busyType = fileType);
    try {
      final updated = await storage.uploadMeetingFile(
        userId: widget.currentUser.id,
        meetingId: widget.meetingId,
        fileType: fileType,
        fileName: f.name,
        mimeType: 'application/pdf',
        dataBase64: base64Encode(bytes),
        sizeBytes: bytes.length,
      );
      if (!mounted) return;
      setState(() {
        _meeting = updated;
        _busyType = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            replacing
                ? 'تم استبدال ${meetingFileLabel(fileType)}'
                : 'تم رفع ${meetingFileLabel(fileType)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyType = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(meetingsApiError(e))),
      );
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteFile(String fileType) async {
    final label = meetingFileLabel(fileType);
    if (!await _confirm('حذف الملف', 'حذف $label من هذا الاجتماع؟')) return;
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    setState(() => _busyType = fileType);
    try {
      final updated = await storage.deleteMeetingFile(
        userId: widget.currentUser.id,
        meetingId: widget.meetingId,
        fileType: fileType,
      );
      if (!mounted) return;
      setState(() {
        _meeting = updated;
        _busyType = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حذف $label')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyType = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(meetingsApiError(e))),
      );
    }
  }

  Future<void> _deleteMeeting() async {
    if (!await _confirm(
      'حذف الاجتماع',
      'حذف الاجتماع وكل ملفاته؟ لا يمكن التراجع.',
    )) {
      return;
    }
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    try {
      await storage.deleteMeeting(
        userId: widget.currentUser.id,
        meetingId: widget.meetingId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(meetingsApiError(e))),
      );
    }
  }

  Future<void> _openFile(String fileType) async {
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    await openMeetingPdf(
      context: context,
      storage: storage,
      userId: widget.currentUser.id,
      meetingId: widget.meetingId,
      fileType: fileType,
    );
  }

  Future<void> _downloadFile(String fileType) async {
    final storage = getStorage();
    if (storage is! ApiStorageService) return;
    setState(() => _busyType = fileType);
    try {
      await downloadMeetingPdf(
        context: context,
        storage: storage,
        userId: widget.currentUser.id,
        meetingId: widget.meetingId,
        fileType: fileType,
      );
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meeting = _meeting;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          meeting == null
              ? 'تفاصيل الاجتماع'
              : 'اجتماع ${meeting.meetingNumber}',
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (_canDelete && _meeting != null)
            IconButton(
              tooltip: 'حذف الاجتماع',
              onPressed: _deleteMeeting,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final meeting = _meeting!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          meeting.subject,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text('رقم الاجتماع: ${meeting.meetingNumber}'),
        Text(
          'موعد الانعقاد: ${formatNotificationDateTime(meeting.scheduledAt)}',
        ),
        const SizedBox(height: 20),
        for (final type in meetingFileTypesInOrder) _fileCard(type),
      ],
    );
  }

  Widget _fileCard(String fileType) {
    final label = meetingFileLabel(fileType);
    final meta = _meeting?.fileOf(fileType);
    final uploaded = meta != null;
    final previousOk = _previousUploaded(fileType);
    final busy = _busyType == fileType;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            if (uploaded) ...[
              Text(
                'تم الرفع يوم ${formatNotificationDateTime(meta.uploadedAt)}',
                style: TextStyle(color: Colors.grey.shade800),
              ),
              if (meta.fileName.isNotEmpty)
                Text(
                  meta.fileName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ] else
              Text(
                'لم يتم ارفاق المستند بعد — $label',
                style: TextStyle(color: Colors.orange.shade800),
              ),
            if (!previousOk && !uploaded)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'ارفع ${meetingFileLabel(previousMeetingFileType(fileType)!)} أولاً',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (uploaded)
                  FilledButton.icon(
                    onPressed: busy ? null : () => _openFile(fileType),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('فتح للاطلاع'),
                  ),
                if (uploaded)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _downloadFile(fileType),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download'),
                  ),
                if (_canUpload && uploaded)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _pickAndUpload(fileType, replacing: true),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('استبدال'),
                  ),
                if (_canUpload && !uploaded && previousOk)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _pickAndUpload(fileType, replacing: false),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file, size: 18),
                    label: const Text('رفع PDF'),
                  ),
                if (_canDelete && uploaded)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _deleteFile(fileType),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('حذف الملف'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
