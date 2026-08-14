import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/meeting_constants.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/egypt_local_time.dart';
import '../utils/meetings_ui.dart';

class MeetingCreateScreen extends StatefulWidget {
  final UserModel currentUser;

  const MeetingCreateScreen({super.key, required this.currentUser});

  @override
  State<MeetingCreateScreen> createState() => _MeetingCreateScreenState();
}

class _MeetingCreateScreenState extends State<MeetingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectC = TextEditingController();
  final _numberC = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  String? _fileName;
  String? _dataBase64;
  int _sizeBytes = 0;
  bool _saving = false;

  @override
  void dispose() {
    _subjectC.dispose();
    _numberC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = toEgyptWallClock(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B5E20),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickPdf() async {
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
    setState(() {
      _fileName = f.name;
      _dataBase64 = base64Encode(bytes);
      _sizeBytes = bytes.length;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد تاريخ ووقت الانعقاد')),
      );
      return;
    }
    if (_dataBase64 == null || _fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أرفق ملف Call of Meeting (PDF)')),
      );
      return;
    }
    final storage = getStorage();
    if (storage is! ApiStorageService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يتطلب اتصال API')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await storage.createMeeting(
        userId: widget.currentUser.id,
        meetingNumber: _numberC.text.trim(),
        subject: _subjectC.text.trim(),
        scheduledAt: egyptWallClockToIso(_date!, _time!),
        fileName: _fileName!,
        mimeType: 'application/pdf',
        dataBase64: _dataBase64!,
        sizeBytes: _sizeBytes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(meetingsApiError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date == null
        ? 'اختر التاريخ'
        : DateFormat('yyyy/MM/dd').format(_date!);
    final timeLabel = _time == null ? 'اختر الساعة' : _time!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call of Meeting'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _subjectC,
              decoration: const InputDecoration(
                labelText: 'موضوع الاجتماع *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'موضوع الاجتماع إلزامي' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberC,
              decoration: const InputDecoration(
                labelText: 'رقم الاجتماع *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'رقم الاجتماع إلزامي' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event),
                    label: Text(dateLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(timeLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Call of Meeting',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(_fileName ?? 'إرفاق ملف PDF'),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('إنشاء الاجتماع'),
            ),
          ],
        ),
      ),
    );
  }
}
