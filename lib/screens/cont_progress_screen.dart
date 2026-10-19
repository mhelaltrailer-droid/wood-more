import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/cont_invoices_constants.dart';
import '../core/invoice_structure_constants.dart';
import '../models/cont_progress_report_model.dart';
import '../models/contractor_model.dart';
import '../models/invoice_structure_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

/// شاشة مهندس الموقع: تسجيل إنجاز مقاول (نسبة / أمتار) من هيكلة المستخلصات.
class ContProgressScreen extends StatefulWidget {
  final UserModel currentUser;

  const ContProgressScreen({super.key, required this.currentUser});

  @override
  State<ContProgressScreen> createState() => _ContProgressScreenState();
}

class _ContProgressScreenState extends State<ContProgressScreen> {
  final _storage = getStorage();
  final _valueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  bool _loading = true;
  bool _saving = false;
  bool _loadingStructure = false;
  String? _error;

  List<ProjectModel> _projects = const [];
  List<ContractorModel> _contractors = const [];
  List<InvoiceStructureLocationModel> _structureLocs = const [];
  List<ContProgressReportModel> _recent = const [];

  ProjectModel? _project;
  ContractorModel? _contractor;
  InvoiceStructureLocationModel? _location;
  String? _measureType;

  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;
  bool get _isFlooring =>
      (_measureType ?? '') == invoiceStructureMeasureFlooring;
  bool get _isWpc => (_measureType ?? '') == invoiceStructureMeasureWpc;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_isApi) {
        throw Exception('يتطلب الاتصال بالخادم');
      }
      final projects = await _api.getProjects();
      final contractors = await _api.getContractors();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _contractors = contractors;
        _loading = false;
      });
      await _loadRecent();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadRecent() async {
    if (!_isApi) return;
    try {
      final list = await _api.getContProgressReports(
        userId: widget.currentUser.id,
        projectId: _project?.id,
        contractorId: _contractor?.id,
      );
      if (!mounted) return;
      setState(() => _recent = list);
    } catch (_) {}
  }

  String _pathOf(InvoiceStructureLocationModel node) {
    final byId = {for (final l in _structureLocs) l.id: l};
    final parts = <String>[];
    InvoiceStructureLocationModel? cur = node;
    final seen = <int>{};
    while (cur != null && !seen.contains(cur.id)) {
      seen.add(cur.id);
      parts.add(cur.name);
      cur = cur.parentId == null ? null : byId[cur.parentId!];
    }
    return parts.reversed.join(' / ');
  }

  Future<void> _onProjectChanged(ProjectModel? project) async {
    setState(() {
      _project = project;
      _location = null;
      _structureLocs = const [];
      _measureType = null;
      _valueCtrl.clear();
    });
    if (project == null) {
      await _loadRecent();
      return;
    }
    setState(() => _loadingStructure = true);
    try {
      final structure = await _api.getInvoiceStructure(
        userId: widget.currentUser.id,
        projectId: project.id,
      );
      if (!mounted || _project?.id != project.id) return;
      setState(() {
        _measureType = structure.measureType;
        _structureLocs = structure.locations;
        _loadingStructure = false;
      });
      if (structure.measureType == null ||
          structure.measureType!.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'نوع القياس غير محدد لهذا المشروع — حدّده من هيكلة المستخلصات أولاً',
            ),
          ),
        );
      }
      await _loadRecent();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStructure = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل هيكلة المستخلصات: $e')),
      );
    }
  }

  Future<void> _pickLocation() async {
    if (_project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المشروع أولاً')),
      );
      return;
    }
    if (_structureLocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد مواقع في هيكلة المستخلصات لهذا المشروع'),
        ),
      );
      return;
    }
    final picked = await showDialog<InvoiceStructureLocationModel>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SimpleDialog(
          title: const Text('اختر الموقع من هيكلة المستخلصات'),
          children: _structureLocs
              .map(
                (loc) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, loc),
                  child: Text(
                    _pathOf(loc),
                    style: TextStyle(
                      fontWeight: loc.type == 'work_site'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _location = picked);
  }

  double _parse(String s) =>
      double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

  Future<void> _submit() async {
    if (_project == null || _contractor == null || _location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل اختيار المشروع والمقاول والموقع')),
      );
      return;
    }
    if (_measureType == null || _measureType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع القياس غير محدد للمشروع')),
      );
      return;
    }
    final value = _parse(_valueCtrl.text);
    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFlooring ? 'أدخل عدد الأمتار' : 'أدخل نسبة الإنجاز',
          ),
        ),
      );
      return;
    }
    if (_isWpc && value > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('النسبة لا تتعدى 100%')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.createContProgressReport(
        userId: widget.currentUser.id,
        report: ContProgressReportModel(
          projectId: _project!.id,
          projectName: _project!.name,
          contractorId: _contractor!.id,
          contractorName: _contractor!.name,
          structureLocationId: _location!.id,
          locationLabel: _pathOf(_location!),
          measureType: _measureType!,
          progressKind: _isFlooring ? 'meters' : 'percent',
          progressValue: value,
          notes: _notesCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      _valueCtrl.clear();
      _notesCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الإنجاز'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadRecent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(contProgressHomeLabel),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _bootstrap,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _bootstrap,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      DropdownButtonFormField<ProjectModel>(
                        // ignore: deprecated_member_use
                        value: _project,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المشروع',
                          border: OutlineInputBorder(),
                        ),
                        items: _projects
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving ? null : _onProjectChanged,
                      ),
                      if (_loadingStructure) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ] else if (_project != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'نوع القياس: ${invoiceStructureMeasureLabel(_measureType)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _measureType == null
                                ? Colors.orange.shade800
                                : Colors.teal.shade800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<ContractorModel>(
                        // ignore: deprecated_member_use
                        value: _contractor,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المقاول',
                          border: OutlineInputBorder(),
                        ),
                        items: _contractors
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) async {
                                setState(() => _contractor = v);
                                await _loadRecent();
                              },
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: _saving ? null : _pickLocation,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'الموقع (من هيكلة المستخلصات)',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.account_tree_outlined),
                          ),
                          child: Text(
                            _location == null
                                ? 'اضغط للاختيار'
                                : _pathOf(_location!),
                            style: TextStyle(
                              color: _location == null
                                  ? Colors.grey[600]
                                  : null,
                              fontWeight: _location == null
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _valueCtrl,
                        decoration: InputDecoration(
                          labelText: _isFlooring
                              ? 'عدد الأمتار المنجزة'
                              : 'نسبة الإنجاز %',
                          border: const OutlineInputBorder(),
                          hintText: _isFlooring ? 'مثال: 50' : 'مثال: 80',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        enabled: !_saving && _measureType != null,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_saving,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text('إرسال الإنجاز'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'آخر الإنجازات المسجّلة',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      if (_recent.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('لا توجد إنجازات بعد'),
                          ),
                        )
                      else
                        ..._recent.map((r) {
                          final when = r.createdAt == null
                              ? '—'
                              : _dateFmt.format(r.createdAt!.toLocal());
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                '${r.contractorName} — ${r.valueLabel}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${r.projectName}\n${r.locationLabel}\n$when'
                                '${r.createdByUserName.isNotEmpty ? ' · ${r.createdByUserName}' : ''}',
                              ),
                              isThreeLine: true,
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}
