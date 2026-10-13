import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/invoice_structure_constants.dart';
import '../models/invoice_structure_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

/// هيكلة المستخلصات: شجرة مستقلة (موقع فرعي / موقع عمل) + نوع Flooring أو WPC.
class AdminInvoiceStructureScreen extends StatefulWidget {
  final UserModel admin;

  const AdminInvoiceStructureScreen({super.key, required this.admin});

  @override
  State<AdminInvoiceStructureScreen> createState() =>
      _AdminInvoiceStructureScreenState();
}

class _AdminInvoiceStructureScreenState
    extends State<AdminInvoiceStructureScreen> {
  final _db = getStorage();
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  String? _measureType;
  List<InvoiceStructureLocationModel> _flatList = [];
  bool _loading = false;
  final Set<int> _expandedIds = {};

  bool get _isApi => _db is ApiStorageService;
  ApiStorageService get _api => _db as ApiStorageService;

  bool get _isFlooring => _measureType == invoiceStructureMeasureFlooring;
  bool get _isWpc => _measureType == invoiceStructureMeasureWpc;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final list = await _db.getProjects();
    if (!mounted) return;
    setState(() => _projects = list);
  }

  Future<void> _onProjectChanged(ProjectModel? v) async {
    setState(() {
      _selectedProject = v;
      _measureType = null;
      _flatList = [];
      _expandedIds.clear();
    });
    if (v == null) return;
    await _loadStructure(promptIfNeeded: true);
  }

  Future<void> _loadStructure({bool promptIfNeeded = false}) async {
    if (_selectedProject == null) return;
    if (!_isApi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هيكلة المستخلصات تتطلب الاتصال بالخادم'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final state = await _api.getInvoiceStructure(
        userId: widget.admin.id,
        projectId: _selectedProject!.id,
      );
      if (!mounted) return;
      setState(() {
        _measureType = state.measureType;
        _flatList = state.locations;
        _loading = false;
      });
      if (promptIfNeeded && !state.hasMeasureType) {
        await _promptMeasureType();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _flatList = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحميل الهيكلة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _promptMeasureType() async {
    if (_selectedProject == null || !_isApi) return;
    final chosen = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('نوع قياس المستخلصات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر نوع المشروع مرة واحدة فقط.\nسيُعتمد بعده في الهيكلة والمستخلصات.',
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
            child: const Text('إلغاء اختيار المشروع'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (chosen == null) {
      setState(() {
        _selectedProject = null;
        _measureType = null;
        _flatList = [];
      });
      return;
    }
    try {
      await _api.setInvoiceStructureMeasureType(
        userId: widget.admin.id,
        projectId: _selectedProject!.id,
        measureType: chosen,
      );
      if (!mounted) return;
      setState(() => _measureType = chosen);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم اعتماد: ${invoiceStructureMeasureLabel(chosen)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
      setState(() {
        _selectedProject = null;
        _measureType = null;
        _flatList = [];
      });
    }
  }

  List<InvoiceStructureLocationModel> _childrenOf(int? parentId) {
    return _flatList.where((e) => e.parentId == parentId).toList()
      ..sort(
        (a, b) => a.displayOrder != b.displayOrder
            ? a.displayOrder.compareTo(b.displayOrder)
            : a.id.compareTo(b.id),
      );
  }

  Future<_NodeFormResult?> _showNodeForm({
    required String title,
    required String type,
    InvoiceStructureLocationModel? existing,
  }) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final orderC = TextEditingController(
      text: '${existing?.displayOrder ?? 0}',
    );
    final metersC = TextEditingController(
      text: existing?.totalMeters != null
          ? _trimNum(existing!.totalMeters!)
          : '',
    );
    final priceC = TextEditingController(
      text: existing?.meterPrice != null
          ? _trimNum(existing!.meterPrice!)
          : '',
    );
    final unitValueC = TextEditingController(
      text: existing?.unitValue != null
          ? _trimNum(existing!.unitValue!)
          : '',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameC,
                decoration: InputDecoration(
                  labelText: type == 'folder'
                      ? 'اسم الموقع الفرعي'
                      : 'اسم موقع العمل',
                ),
                textDirection: TextDirection.ltr,
                autofocus: true,
              ),
              if (existing != null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: orderC,
                  decoration: const InputDecoration(
                    labelText: 'ترتيب العرض (رقم)',
                  ),
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                ),
              ],
              if (_isFlooring) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: metersC,
                  decoration: const InputDecoration(
                    labelText: 'إجمالي الأمتار (اختياري)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textDirection: TextDirection.ltr,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceC,
                  decoration: const InputDecoration(
                    labelText: 'سعر المتر (اختياري)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textDirection: TextDirection.ltr,
                ),
              ],
              if (_isWpc) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: unitValueC,
                  decoration: const InputDecoration(
                    labelText: 'قيمة الـ Unit (اختياري)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textDirection: TextDirection.ltr,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(existing == null ? 'إضافة' : 'حفظ'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    return _NodeFormResult(
      name: nameC.text.trim(),
      displayOrder: int.tryParse(orderC.text.trim()) ?? existing?.displayOrder ?? 0,
      totalMeters: _parseOptional(metersC.text),
      meterPrice: _parseOptional(priceC.text),
      unitValue: _parseOptional(unitValueC.text),
    );
  }

  static String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  static double? _parseOptional(String raw) {
    final s = raw.trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  Future<void> _addNode({int? parentId, required String type}) async {
    if (_selectedProject == null || _measureType == null) return;
    final form = await _showNodeForm(
      title: type == 'folder' ? 'إضافة موقع فرعي' : 'إضافة موقع عمل',
      type: type,
    );
    if (form == null || !mounted) return;
    try {
      await _api.addInvoiceStructureLocation(
        userId: widget.admin.id,
        projectId: _selectedProject!.id,
        parentId: parentId,
        name: form.name,
        type: type,
        totalMeters: _isFlooring ? form.totalMeters : null,
        meterPrice: _isFlooring ? form.meterPrice : null,
        unitValue: _isWpc ? form.unitValue : null,
      );
      await _loadStructure();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت الإضافة'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editNode(InvoiceStructureLocationModel node) async {
    final form = await _showNodeForm(
      title: 'تعديل',
      type: node.type,
      existing: node,
    );
    if (form == null || !mounted) return;
    try {
      await _api.updateInvoiceStructureLocation(
        userId: widget.admin.id,
        id: node.id,
        name: form.name,
        displayOrder: form.displayOrder,
        totalMeters: _isFlooring ? form.totalMeters : null,
        meterPrice: _isFlooring ? form.meterPrice : null,
        unitValue: _isWpc ? form.unitValue : null,
        clearFlooringFields: _isFlooring,
        clearUnitValue: _isWpc,
      );
      await _loadStructure();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التعديل'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteNode(InvoiceStructureLocationModel node) async {
    final children = _childrenOf(node.id);
    final hasChildren = children.isNotEmpty;
    final msg = hasChildren
        ? 'حذف "${node.name}"؟ سيتم حذف جميع المواقع التابعة تحته.'
        : 'حذف "${node.name}"؟';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteInvoiceStructureLocation(
        userId: widget.admin.id,
        id: node.id,
      );
      await _loadStructure();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم الحذف'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _nodeMeta(InvoiceStructureLocationModel node) {
    final parts = <String>[];
    if (_isFlooring) {
      if (node.totalMeters != null) {
        parts.add('أمتار: ${_trimNum(node.totalMeters!)}');
      }
      if (node.meterPrice != null) {
        parts.add('سعر: ${_trimNum(node.meterPrice!)}');
      }
    }
    if (_isWpc && node.unitValue != null) {
      parts.add('قيمة: ${_trimNum(node.unitValue!)}');
    }
    return parts.isEmpty ? '' : '  (${parts.join(' · ')})';
  }

  Widget _buildTree(int? parentId, int depth) {
    final children = _childrenOf(parentId);
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((node) {
        final isExpanded = _expandedIds.contains(node.id);
        final subChildren = _childrenOf(node.id);
        final hasKids = subChildren.isNotEmpty;
        final icon = node.isFolder
            ? Icon(Icons.folder, color: Colors.amber[700], size: 24)
            : Icon(Icons.place, color: Colors.green[700], size: 22);

        return Padding(
          padding: EdgeInsets.only(left: depth * 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasKids
                      ? () => setState(() {
                            if (isExpanded) {
                              _expandedIds.remove(node.id);
                            } else {
                              _expandedIds.add(node.id);
                            }
                          })
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: hasKids
                              ? Icon(
                                  isExpanded
                                      ? Icons.expand_more
                                      : Icons.chevron_right,
                                  size: 28,
                                  color: const Color(0xFF1B5E20),
                                )
                              : const SizedBox(width: 28),
                        ),
                        icon,
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: node.name,
                                  style: TextStyle(
                                    fontWeight: node.isFolder
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                if (_nodeMeta(node).isNotEmpty)
                                  TextSpan(
                                    text: _nodeMeta(node),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          tooltip: 'إضافة موقع فرعي',
                          onPressed: () =>
                              _addNode(parentId: node.id, type: 'folder'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.place, size: 20),
                          tooltip: 'إضافة موقع عمل',
                          onPressed: () =>
                              _addNode(parentId: node.id, type: 'work_site'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editNode(node),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteNode(node),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isExpanded) _buildTree(node.id, depth + 1),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(invoiceStructureHomeLabel),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<ProjectModel?>(
              value: _selectedProject,
              decoration: const InputDecoration(
                labelText: 'المشروع',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('— اختر المشروع —'),
                ),
                ..._projects.map(
                  (p) => DropdownMenuItem(value: p, child: Text(p.name)),
                ),
              ],
              onChanged: _onProjectChanged,
            ),
            if (_selectedProject != null && _measureType != null) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFlooring
                            ? Icons.square_foot
                            : Icons.view_module_outlined,
                        color: const Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'نوع القياس: ${invoiceStructureMeasureLabel(_measureType)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_selectedProject != null && _measureType != null) ...[
              FilledButton.icon(
                icon: const Icon(Icons.folder),
                label: const Text('إضافة موقع فرعي'),
                onPressed: () => _addNode(parentId: null, type: 'folder'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.place),
                label: const Text('إضافة موقع عمل (جذر)'),
                onPressed: () => _addNode(parentId: null, type: 'work_site'),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_flatList.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'لا توجد مواقع بعد.\nأضف موقعاً فرعياً أو موقع عمل، ويمكن التفرع بلا حد (فرعي داخل فرعي، وعمل داخل عمل).',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                _buildTree(null, 0),
            ],
          ],
        ),
      ),
    );
  }
}

class _NodeFormResult {
  final String name;
  final int displayOrder;
  final double? totalMeters;
  final double? meterPrice;
  final double? unitValue;

  const _NodeFormResult({
    required this.name,
    required this.displayOrder,
    this.totalMeters,
    this.meterPrice,
    this.unitValue,
  });
}
