import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/daily_report_model.dart';
import '../services/storage_service.dart';
import 'daily_report_step2_screen.dart';

/// الخطوة 1 من التقرير اليومي: البيانات الأساسية + المرفقات
class DailyReportStep1Screen extends StatefulWidget {
  final UserModel user;
  final DailyReportData report;

  const DailyReportStep1Screen({super.key, required this.user, required this.report});

  @override
  State<DailyReportStep1Screen> createState() => _DailyReportStep1ScreenState();
}

class _DailyReportStep1ScreenState extends State<DailyReportStep1Screen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  final _workPlaceController = TextEditingController();
  final _workReportController = TextEditingController();
  final _executedTodayController = TextEditingController();
  final _workersController = TextEditingController();
  static const List<String> _supervisorOptions = ['Emam', 'Mansour', 'لايوجد مشرف', 'Ahmed'];
  static const List<String> _contractorOptions = ['حسام حسن', 'ابراهيم النجار', 'لايوجد مقاول', 'ابراهيم حسن'];
  String? _selectedSupervisor;
  String? _selectedContractor;
  final _tomorrowPlanController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _imagePaths = [];
  String? _documentPath;
  String? _documentFileName;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _imagePaths = List.from(widget.report.imagePaths);
    _documentPath = widget.report.documentPath;
    _workPlaceController.text = widget.report.workPlace;
    _workReportController.text = widget.report.workReport;
    _executedTodayController.text = widget.report.executedToday;
    _selectedSupervisor = widget.report.supervisorName.isEmpty ? null : (_supervisorOptions.contains(widget.report.supervisorName) ? widget.report.supervisorName : null);
    _selectedContractor = widget.report.contractorName.isEmpty ? null : (_contractorOptions.contains(widget.report.contractorName) ? widget.report.contractorName : null);
    _workersController.text = widget.report.workersCount;
    _tomorrowPlanController.text = widget.report.tomorrowPlan;
    _notesController.text = widget.report.notes;
  }

  @override
  void dispose() {
    _workPlaceController.dispose();
    _workReportController.dispose();
    _executedTodayController.dispose();
    _workersController.dispose();
    _tomorrowPlanController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final list = await _db.getProjects();
    final current = list.cast<ProjectModel?>().firstWhere(
          (p) => p?.id == widget.report.projectId,
          orElse: () => null,
        );
    setState(() {
      _projects = list;
      _selectedProject = current;
    });
  }

  static String _mimeFromExtension(String? path) {
    final ext = path?.split('.').last.toLowerCase() ?? '';
    switch (ext) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      default: return 'image/jpeg';
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر قراءة الملف')));
        return;
      }
      final mime = _mimeFromExtension(file.name);
      final base64 = base64Encode(bytes);
      setState(() {
        _documentPath = 'data:$mime;base64,$base64';
        _documentFileName = file.name;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرفاق: ${file.name}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickImages() async {
    if (_imagePaths.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحد الأقصى 3 صور')));
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      final remaining = 3 - _imagePaths.length;
      final toAdd = result.files.take(remaining).toList();
      for (final file in toAdd) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final mime = _mimeFromExtension(file.name);
        final base64 = base64Encode(bytes);
        _imagePaths.add('data:$mime;base64,$base64');
      }
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرفاق ${toAdd.length} صورة')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  void _goNext() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر المشروع')));
      return;
    }
    final report = DailyReportData(
      userName: widget.report.userName,
      userId: widget.report.userId,
      projectId: _selectedProject!.id,
      projectName: _selectedProject!.name,
      reportDate: widget.report.reportDate,
      workPlace: _workPlaceController.text.trim(),
      workReport: _workReportController.text.trim(),
      executedToday: _executedTodayController.text.trim(),
      supervisorName: _selectedSupervisor ?? '',
      contractorName: _selectedContractor ?? '',
      workersCount: _workersController.text.trim(),
      tomorrowPlan: _tomorrowPlanController.text.trim(),
      documentPath: _documentPath,
      imagePaths: List.from(_imagePaths),
      notes: _notesController.text.trim(),
      materials: widget.report.materials,
      expenses: widget.report.expenses,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyReportStep2Screen(user: widget.user, report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(widget.report.reportDate);
    final timeStr = DateFormat('hh:mm a', 'ar').format(widget.report.reportDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير اليومي - الخطوة 1'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _readOnlyRow('اسم المهندس', widget.report.userName),
            const SizedBox(height: 16),
            DropdownButtonFormField<ProjectModel>(
              value: _selectedProject,
              decoration: const InputDecoration(
                labelText: 'اسم المشروع *',
                border: OutlineInputBorder(),
              ),
              items: _projects.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
              onChanged: (p) => setState(() => _selectedProject = p),
              validator: (v) => v == null ? 'اختر المشروع' : null,
            ),
            const SizedBox(height: 12),
            _readOnlyRow('التاريخ', dateStr),
            _readOnlyRow('الوقت', timeStr),
            const SizedBox(height: 16),
            TextFormField(
              controller: _workPlaceController,
              decoration: const InputDecoration(
                labelText: 'مكان العمل *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _workReportController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'تقرير الأعمال *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _executedTodayController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'ما تم تنفيذه اليوم *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSupervisor,
              decoration: const InputDecoration(
                labelText: 'المشرف',
                border: OutlineInputBorder(),
              ),
              items: _supervisorOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedSupervisor = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedContractor,
              decoration: const InputDecoration(
                labelText: 'المقاول',
                border: OutlineInputBorder(),
              ),
              items: _contractorOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedContractor = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _workersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد العمال',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tomorrowPlanController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'خطة عمل الغد *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDocument,
              icon: const Icon(Icons.attach_file),
              label: const Text('إرفاق مستند (PDF أو Word)'),
            ),
            if (_documentPath != null) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.description, color: Color(0xFF1B5E20)),
                title: Text(_documentFileName ?? 'مستند مرفق', overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() { _documentPath = null; _documentFileName = null; }),
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _imagePaths.length >= 3 ? null : _pickImages,
              icon: const Icon(Icons.photo_library),
              label: Text('إرفاق صور (${_imagePaths.length}/3)'),
            ),
            if (_imagePaths.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._imagePaths.asMap().entries.map((e) => ListTile(
                    leading: e.value.startsWith('data:') || e.value.startsWith('http')
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(e.value, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                          )
                        : const Icon(Icons.image),
                    title: Text('صورة ${e.key + 1}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _imagePaths.removeAt(e.key)),
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'الملاحظات',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _goNext,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF1B5E20),
              ),
              child: const Text('التالي'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
