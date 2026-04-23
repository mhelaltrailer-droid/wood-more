import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/supervisor_model.dart';
import '../models/contractor_model.dart';
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

/// قيمة ثابتة لخيار "أخرى" في قائمة المشروعات (id = 0 لا يوجد في قاعدة المشروعات)
const ProjectModel _otherProject = ProjectModel(id: 0, name: 'أخرى');

class _DailyReportStep1ScreenState extends State<DailyReportStep1Screen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  final _otherProjectNameController = TextEditingController();
  final _workPlaceController = TextEditingController();
  final _workReportController = TextEditingController();
  /// أسماء المشرفين من التخزين (نفس مصدر التقرير المفصل) + خيار لايوجد مشرف
  List<String> _supervisorOptions = ['لايوجد مشرف'];
  /// أسماء المقاولين من التخزين (نفس مصدر التقرير المفصل) + خيار لايوجد مقاول
  List<String> _contractorOptions = ['لايوجد مقاول'];
  String? _selectedSupervisor;
  final List<ContractorWorkers> _contractors = [];
  final _tomorrowPlanController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> _imagePaths = [];
  String? _documentPath;
  String? _documentFileName;

  bool get _isOtherProject => _selectedProject?.id == _otherProject.id;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadSupervisorsAndContractors();
    if (widget.report.projectName != null &&
        widget.report.projectName!.trim().startsWith('أخرى')) {
      final n = widget.report.projectName!.trim();
      if (n.startsWith('أخرى (') && n.endsWith(')')) {
        _otherProjectNameController.text = n.substring(6, n.length - 1).trim();
      }
    }
    _imagePaths = List.from(widget.report.imagePaths);
    _documentPath = widget.report.documentPath;
    _workPlaceController.text = widget.report.workPlace;
    _workReportController.text = widget.report.workReport;
    if (widget.report.supervisorName.isNotEmpty) _selectedSupervisor = widget.report.supervisorName;
    if (widget.report.contractors.isNotEmpty) {
      _contractors.addAll(widget.report.contractors.map((c) => ContractorWorkers(contractorName: c.contractorName, workersCount: c.workersCount)));
    } else if (widget.report.contractorName.isNotEmpty || widget.report.workersCount.isNotEmpty) {
      _contractors.add(ContractorWorkers(contractorName: widget.report.contractorName, workersCount: widget.report.workersCount));
    }
    if (_contractors.isEmpty) _contractors.add(ContractorWorkers());
    _tomorrowPlanController.text = widget.report.tomorrowPlan;
    _notesController.text = widget.report.notes;
  }

  @override
  void dispose() {
    _otherProjectNameController.dispose();
    _workPlaceController.dispose();
    _workReportController.dispose();
    _tomorrowPlanController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final list = await _db.getProjects();
    final isOther = widget.report.projectName != null &&
        widget.report.projectName!.trim().startsWith('أخرى');
    ProjectModel? current;
    if (isOther) {
      current = _otherProject;
    } else {
      current = list.cast<ProjectModel?>().firstWhere(
            (p) => p?.id == widget.report.projectId,
            orElse: () => null,
          );
      if (current != null && current.name == 'أخرى') current = _otherProject;
    }
    setState(() {
      _projects = list;
      _selectedProject = current;
    });
  }

  Future<void> _loadSupervisorsAndContractors() async {
    try {
      final supervisors = await _db.getSupervisors();
      final contractors = await _db.getContractors();
      if (mounted) {
        setState(() {
          _supervisorOptions = ['لايوجد مشرف', ...supervisors.map((s) => s.name)];
          _contractorOptions = ['لايوجد مقاول', ...contractors.map((c) => c.name)];
          if (_selectedSupervisor != null && _selectedSupervisor!.isNotEmpty && !_supervisorOptions.contains(_selectedSupervisor)) {
            _supervisorOptions = List.from(_supervisorOptions)..add(_selectedSupervisor!);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _supervisorOptions = ['لايوجد مشرف'];
          _contractorOptions = ['لايوجد مقاول'];
          if (_selectedSupervisor != null && _selectedSupervisor!.isNotEmpty && !_supervisorOptions.contains(_selectedSupervisor)) {
            _supervisorOptions = List.from(_supervisorOptions)..add(_selectedSupervisor!);
          }
        });
      }
    }
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
      final result = await FilePicker.pickFiles(
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
      final result = await FilePicker.pickFiles(
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
    if (_isOtherProject) {
      final otherName = _otherProjectNameController.text.trim();
      if (otherName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عند اختيار "أخرى" يرجى كتابة اسم المشروع في الخانة أدناه')),
        );
        return;
      }
    }
    final contractorsList = _contractors
        .where((c) => c.contractorName.trim().isNotEmpty || c.workersCount.trim().isNotEmpty)
        .map((c) => ContractorWorkers(contractorName: c.contractorName.trim(), workersCount: c.workersCount.trim()))
        .toList();
    final firstContractor = contractorsList.isNotEmpty ? contractorsList.first : ContractorWorkers();
    final int? reportProjectId = _isOtherProject ? null : _selectedProject!.id;
    final String reportProjectName = _isOtherProject
        ? 'أخرى (${_otherProjectNameController.text.trim()})'
        : _selectedProject!.name;
    final report = DailyReportData(
      userName: widget.report.userName,
      userId: widget.report.userId,
      projectId: reportProjectId,
      projectName: reportProjectName,
      reportDate: widget.report.reportDate,
      workPlace: _workPlaceController.text.trim(),
      workReport: _workReportController.text.trim(),
      executedToday: '',
      supervisorName: _selectedSupervisor ?? '',
      contractorName: firstContractor.contractorName,
      workersCount: firstContractor.workersCount,
      contractors: contractorsList,
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
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'اسم المشروع *',
                border: OutlineInputBorder(),
              ),
              items: [
                ..._projects
                    .where((p) => p.name != 'أخرى')
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                const DropdownMenuItem(value: _otherProject, child: Text('أخرى')),
              ],
              onChanged: (p) => setState(() => _selectedProject = p),
              validator: (v) => v == null ? 'اختر المشروع' : null,
            ),
            if (_isOtherProject) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherProjectNameController,
                decoration: const InputDecoration(
                  labelText: 'حدد المشروع (إلزامي عند اختيار أخرى) *',
                  hintText: 'اكتب اسم المشروع أو وصفاً قصيراً',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (_isOtherProject && (v == null || v.trim().isEmpty)) return 'مطلوب عند اختيار أخرى';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ],
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
                labelText: 'تفاصيل تقرير اعمال اليوم *',
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
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('— اختر المشرف —')),
                ..._supervisorOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _selectedSupervisor = v),
            ),
            const SizedBox(height: 16),
            const Text('المقاولون وعدد العمال (يمكن إضافة أكثر من مقاول)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ..._contractors.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final options = List<String>.from(_contractorOptions);
              if (c.contractorName.isNotEmpty && !options.contains(c.contractorName)) options.add(c.contractorName);
              return Padding(
                key: ValueKey('contractor_row_$i'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: c.contractorName.isEmpty ? null : (options.contains(c.contractorName) ? c.contractorName : null),
                        decoration: const InputDecoration(
                          labelText: 'المقاول',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _contractors[i] = ContractorWorkers(contractorName: v ?? '', workersCount: _contractors[i].workersCount)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: () {
                          final n = int.tryParse(c.workersCount.trim());
                          return (n != null && n >= 1 && n <= 12) ? n.toString() : null;
                        }(),
                        decoration: const InputDecoration(
                          labelText: 'عدد العمال (1–12)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(12, (n) => (n + 1).toString()).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _contractors[i] = ContractorWorkers(contractorName: _contractors[i].contractorName, workersCount: v ?? '')),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: _contractors.length > 1 ? () => setState(() => _contractors.removeAt(i)) : null,
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () => setState(() => _contractors.add(ContractorWorkers())),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('إضافة مقاول آخر'),
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
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'الملاحظات',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const Text('المرفقات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
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
