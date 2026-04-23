import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/operation_reports_store.dart';
import '../services/storage_service.dart';

class OperationReportsScreen extends StatefulWidget {
  final UserModel user;

  const OperationReportsScreen({super.key, required this.user});

  @override
  State<OperationReportsScreen> createState() => _OperationReportsScreenState();
}

class _OperationReportsScreenState extends State<OperationReportsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _storage = getStorage();

  bool _loadingProjects = true;
  bool _submitting = false;
  List<ProjectModel> _projects = const [];
  String? _projectsError;
  int? _selectedProjectId;
  String? _selectedReportType;
  final List<String> _imageDataUris = [];

  static const List<String> _reportTypes = [
    'تقرير معاينة',
    'تقرير إثبات حالة',
    'تقرير تلفيات',
  ];

  @override
  void initState() {
    super.initState();
    OperationReportsStore.ensureLoaded();
    _loadProjects();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loadingProjects = true;
      _projectsError = null;
    });
    try {
      final projects = await _storage.getProjects() as List<ProjectModel>;
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projects = const [];
        _projectsError = 'تعذر تحميل قائمة المشاريع';
        _loadingProjects = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المشاريع: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _mimeFromExtension(String? fileName) {
    final ext = (fileName?.split('.').last ?? '').toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _attachImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      int addedCount = 0;
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final mime = _mimeFromExtension(file.name);
        _imageDataUris.add('data:$mime;base64,${base64Encode(bytes)}');
        addedCount++;
      }

      if (!mounted || addedCount == 0) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إرفاق $addedCount صورة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرفاق الصور: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageDataUris.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إرفاق صورة واحدة على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إرسال التقرير'),
        content: const Text('هل تريد إرسال التقرير الآن؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final selectedProject = _projects.firstWhere(
        (p) => p.id == _selectedProjectId,
        orElse: () => ProjectModel(id: -1, name: 'غير محدد'),
      );

      await OperationReportsStore.addSubmittedReport(
        reportType: _selectedReportType!,
        projectName: selectedProject.name,
        engineerName: widget.user.name,
        submittedAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() => _submitting = false);

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('تم إرسال التقرير'),
            content: Text(
              'المهندس: ${widget.user.name}\n'
              'المشروع: ${selectedProject.name}\n'
              'نوع التقرير: $_selectedReportType\n'
              'عدد الصور: ${_imageDataUris.length}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('حسناً'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      setState(() {
        _selectedProjectId = null;
        _selectedReportType = null;
        _imageDataUris.clear();
        _detailsController.clear();
        _formKey.currentState?.reset();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال التقرير: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير التشغيل'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: widget.user.name,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'اسم المهندس',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingProjects)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else
              DropdownButtonFormField<int>(
                value: _selectedProjectId,
                decoration: InputDecoration(
                  labelText: 'اسم المشروع',
                  border: const OutlineInputBorder(),
                  helperText: _projectsError,
                  helperStyle: const TextStyle(color: Colors.red),
                ),
                items: _projects
                    .map((project) => DropdownMenuItem<int>(
                          value: project.id,
                          child: Text(project.name),
                        ))
                    .toList(),
                validator: (value) => value == null ? 'يرجى اختيار المشروع' : null,
                onChanged: (value) => setState(() => _selectedProjectId = value),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedReportType,
              decoration: const InputDecoration(
                labelText: 'نوع التقرير',
                border: OutlineInputBorder(),
              ),
              items: _reportTypes
                  .map((type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              validator: (value) => value == null ? 'يرجى اختيار نوع التقرير' : null,
              onChanged: (value) => setState(() => _selectedReportType = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detailsController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'تفاصيل التقرير',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال تفاصيل التقرير';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _attachImages,
              icon: const Icon(Icons.attach_file),
              label: const Text('إرفاق صور'),
            ),
            const SizedBox(height: 8),
            if (_imageDataUris.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_imageDataUris.length, (index) {
                  final imagePath = _imageDataUris[index];
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imagePath,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 90,
                            height: 90,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: InkWell(
                          onTap: () => setState(() => _imageDataUris.removeAt(index)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              )
            else
              Text(
                'لم يتم إرفاق صور بعد',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إرسال التقرير'),
            ),
          ],
        ),
      ),
    );
  }
}
