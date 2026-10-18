import 'package:flutter/material.dart';

import '../core/invoice_structure_constants.dart';
import '../models/contractor_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import 'cont_invoices_work_screen.dart';

/// الشاشة 1: اختيار المقاول والمشروع ثم متابعة.
class ContInvoicesSelectScreen extends StatefulWidget {
  final UserModel currentUser;

  const ContInvoicesSelectScreen({super.key, required this.currentUser});

  @override
  State<ContInvoicesSelectScreen> createState() =>
      _ContInvoicesSelectScreenState();
}

class _ContInvoicesSelectScreenState extends State<ContInvoicesSelectScreen> {
  final _storage = getStorage();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<ContractorModel> _contractors = const [];
  List<ProjectModel> _projects = const [];
  ContractorModel? _contractor;
  ProjectModel? _project;
  String? _measureType;
  bool _checkingMeasure = false;

  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_isApi) {
        throw Exception('Cont-Invoices يتطلب الاتصال بالخادم');
      }
      final contractors = await _api.getContractors();
      final projects = await _api.getProjects();
      if (!mounted) return;
      setState(() {
        _contractors = contractors;
        _projects = projects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onProjectChanged(ProjectModel? project) async {
    setState(() {
      _project = project;
      _measureType = null;
    });
    if (project == null) return;
    setState(() => _checkingMeasure = true);
    try {
      final structure = await _api.getInvoiceStructure(
        userId: widget.currentUser.id,
        projectId: project.id,
      );
      if (!mounted || _project?.id != project.id) return;
      setState(() {
        _measureType = structure.measureType;
        _checkingMeasure = false;
      });
      if (structure.measureType == null ||
          structure.measureType!.trim().isEmpty) {
        await _ensureMeasureType(project);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingMeasure = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر قراءة نوع القياس: $e')),
      );
    }
  }

  /// تحديد Flooring / WPC مرة واحدة إن لم يكن معتمداً للمشروع.
  Future<bool> _ensureMeasureType(ProjectModel project) async {
    final chosen = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديد نوع القياس'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المشروع «${project.name}» غير محدد بعد.\n'
              'اختر Flooring أو WPC مرة واحدة — سيُعتمد في هيكلة المستخلصات والمستخلصات.',
              style: TextStyle(color: Colors.grey[800], height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, invoiceStructureMeasureFlooring),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Flooring'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, invoiceStructureMeasureWpc),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('WPC'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لاحقاً'),
          ),
        ],
      ),
    );
    if (!mounted || chosen == null) return false;

    setState(() => _busy = true);
    try {
      final result = await _api.setInvoiceStructureMeasureType(
        userId: widget.currentUser.id,
        projectId: project.id,
        measureType: chosen,
      );
      if (!mounted) return false;
      setState(() {
        _measureType = chosen;
        _busy = false;
      });
      final importMap = result['import'] is Map
          ? Map<String, dynamic>.from(result['import'] as Map)
          : null;
      final imported = (importMap?['imported'] is num)
          ? (importMap!['imported'] as num).toInt()
          : 0;
      final msg = imported > 0
          ? 'تم اعتماد ${invoiceStructureMeasureLabel(chosen)} — واستيراد $imported موقعاً'
          : 'تم اعتماد ${invoiceStructureMeasureLabel(chosen)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل اعتماد النوع: $e')),
      );
      return false;
    }
  }

  Future<void> _continue() async {
    if (_contractor == null || _project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المقاول والمشروع')),
      );
      return;
    }
    if (_busy || _checkingMeasure) return;

    var measure = _measureType;
    if (measure == null || measure.trim().isEmpty) {
      final ok = await _ensureMeasureType(_project!);
      if (!ok) return;
      measure = _measureType;
    }
    if (measure == null || measure.trim().isEmpty) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContInvoicesWorkScreen(
          currentUser: widget.currentUser,
          contractor: _contractor!,
          project: _project!,
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مستخلص جديد')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      DropdownButtonFormField<ContractorModel>(
                        value: _contractor,
                        decoration: const InputDecoration(
                          labelText: 'اسم المقاول',
                          border: OutlineInputBorder(),
                        ),
                        items: _contractors
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _contractor = v),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<ProjectModel>(
                        value: _project,
                        decoration: const InputDecoration(
                          labelText: 'المشروع',
                          border: OutlineInputBorder(),
                        ),
                        items: _projects
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.name),
                              ),
                            )
                            .toList(),
                        onChanged: _busy ? null : _onProjectChanged,
                      ),
                      if (_checkingMeasure) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(),
                      ] else if (_project != null) ...[
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'نوع القياس',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _measureType == null || _measureType!.isEmpty
                                ? 'غير محدد — سيُطلب عند المتابعة'
                                : invoiceStructureMeasureLabel(_measureType),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _measureType == null
                                  ? Colors.orange.shade800
                                  : Colors.teal.shade800,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _busy || _checkingMeasure ? null : _continue,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_back),
                        label: const Text('متابعة'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
