import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/cont_invoices_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/contractor_model.dart';
import '../models/project_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

class ContInvoicesFormScreen extends StatefulWidget {
  final UserModel currentUser;
  final ContInvoiceModel? existing;

  const ContInvoicesFormScreen({
    super.key,
    required this.currentUser,
    this.existing,
  });

  @override
  State<ContInvoicesFormScreen> createState() => _ContInvoicesFormScreenState();
}

class _ContInvoicesFormScreenState extends State<ContInvoicesFormScreen> {
  final _storage = getStorage();
  final _moneyFmt = NumberFormat('#,##0.00', 'en_US');
  final _qtyFmt = NumberFormat('#,##0.####', 'en_US');

  bool _loadingMeta = true;
  bool _saving = false;
  String? _error;

  List<ContractorModel> _contractors = const [];
  List<ProjectModel> _projects = const [];
  List<ProjectLocationModel> _locations = const [];
  List<_LocationOption> _locationOptions = const [];

  ContractorModel? _contractor;
  ProjectModel? _project;
  _LocationOption? _pickedLocation;
  DateTime _statementDate = DateTime.now();
  final _contractTypeCtrl = TextEditingController(
    text: contInvoicesDefaultContractType,
  );
  final _previouslyPaidCtrl = TextEditingController(text: '0');
  final _otherDeductionsCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final _newLocationCtrl = TextEditingController();

  /// عند إنشاء مستخلص جديد: نعبّئ السابق صرفه تلقائياً ما لم يعدّله المستخدم.
  bool _previouslyPaidTouched = false;
  String? _previouslyPaidHint;

  /// location -> editable lines
  final Map<String, List<_LineEditors>> _sections = {};
  final List<String> _sectionOrder = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _contractTypeCtrl.dispose();
    _previouslyPaidCtrl.dispose();
    _otherDeductionsCtrl.dispose();
    _notesCtrl.dispose();
    _newLocationCtrl.dispose();
    for (final lines in _sections.values) {
      for (final line in lines) {
        line.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
    });
    try {
      if (_storage is! ApiStorageService) {
        throw Exception('Cont-Invoices يتطلب الاتصال بالخادم');
      }
      final api = _storage as ApiStorageService;
      final contractors = await api.getContractors();
      final projects = await api.getProjects();

      ContInvoiceModel? detail = widget.existing;
      if (detail?.id != null) {
        detail = await api.getContInvoiceDetail(
          detail!.id!,
          widget.currentUser.id,
        );
      }

      _contractors = contractors;
      _projects = projects;

      if (detail != null) {
        _applyExisting(detail);
        if (detail.projectId != null) {
          await _loadLocationsForProject(detail.projectId!);
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) {
      setState(() => _loadingMeta = false);
    }
  }

  Future<void> _loadLocationsForProject(int projectId) async {
    try {
      final api = _storage as ApiStorageService;
      final locs = await api.getProjectLocations(projectId);
      if (!mounted) return;
      setState(() {
        _locations = locs;
        _locationOptions = _buildLocationOptions(locs);
        _pickedLocation = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locations = const [];
        _locationOptions = const [];
        _pickedLocation = null;
      });
    }
  }

  List<_LocationOption> _buildLocationOptions(List<ProjectLocationModel> locs) {
    final byId = {for (final l in locs) l.id: l};
    String pathOf(ProjectLocationModel node) {
      final parts = <String>[];
      ProjectLocationModel? cur = node;
      final guard = <int>{};
      while (cur != null && !guard.contains(cur.id)) {
        guard.add(cur.id);
        parts.insert(0, cur.name);
        cur = cur.parentId == null ? null : byId[cur.parentId!];
      }
      return parts.join(' / ');
    }

    final options = locs
        .map(
          (l) => _LocationOption(
            id: l.id,
            name: l.name,
            path: pathOf(l),
            type: l.type,
          ),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return options;
  }

  Future<void> _onContractorChanged(ContractorModel? v) async {
    setState(() => _contractor = v);
    // عند التعديل نحتفظ بالقيمة المحفوظة؛ التعبئة التلقائية للمستخلص الجديد فقط.
    if (widget.existing?.id != null || v == null) return;
    if (_previouslyPaidTouched) return;
    await _autofillPreviouslyPaid(v);
  }

  Future<void> _onProjectChanged(ProjectModel? v) async {
    setState(() {
      _project = v;
      _locations = const [];
      _locationOptions = const [];
      _pickedLocation = null;
    });
    if (v != null) {
      await _loadLocationsForProject(v.id);
    }
  }

  Future<void> _autofillPreviouslyPaid(ContractorModel contractor) async {
    try {
      final api = _storage as ApiStorageService;
      final data = await api.getContInvoicePreviousPaid(
        userId: widget.currentUser.id,
        contractorId: contractor.id,
        contractorName: contractor.name,
        excludeId: widget.existing?.id,
      );
      if (!mounted || _previouslyPaidTouched) return;
      final hasPrevious = data['has_previous'] == true;
      final amount = (data['previously_paid'] is num)
          ? (data['previously_paid'] as num).toDouble()
          : double.tryParse('${data['previously_paid']}') ?? 0;
      setState(() {
        _previouslyPaidCtrl.text = _trimNum(amount);
        _previouslyPaidHint = hasPrevious
            ? 'من آخر مستخلص للمقاول (إجمالي ${NumberFormat('#,##0.00', 'en_US').format(amount)})'
            : 'أول مستخلص لهذا المقاول — أدخل السابق صرفه يدوياً إن وُجد';
      });
    } catch (_) {
      // تجاهل: يبقى الحقل يدوياً
    }
  }

  static String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _applyExisting(ContInvoiceModel inv) {
    ContractorModel? contractor;
    for (final c in _contractors) {
      if (inv.contractorId != null && c.id == inv.contractorId) {
        contractor = c;
        break;
      }
    }
    if (contractor == null && inv.contractorName.isNotEmpty) {
      for (final c in _contractors) {
        if (c.name == inv.contractorName) {
          contractor = c;
          break;
        }
      }
    }
    _contractor = contractor;

    ProjectModel? project;
    for (final p in _projects) {
      if (inv.projectId != null && p.id == inv.projectId) {
        project = p;
        break;
      }
    }
    if (project == null && inv.projectName.isNotEmpty) {
      for (final p in _projects) {
        if (p.name == inv.projectName) {
          project = p;
          break;
        }
      }
    }
    _project = project;

    _statementDate = inv.statementDate ?? DateTime.now();
    _contractTypeCtrl.text = inv.contractType.isEmpty
        ? contInvoicesDefaultContractType
        : inv.contractType;
    _previouslyPaidCtrl.text = inv.previouslyPaid.toString();
    _otherDeductionsCtrl.text = inv.otherDeductions.toString();
    _notesCtrl.text = inv.notes;

    for (final line in inv.lines) {
      final loc =
          line.locationLabel.trim().isEmpty ? 'عام' : line.locationLabel.trim();
      if (!_sections.containsKey(loc)) {
        _sections[loc] = [];
        _sectionOrder.add(loc);
      }
      _sections[loc]!.add(_LineEditors.fromModel(line));
    }
  }

  double get _previouslyPaid =>
      double.tryParse(_previouslyPaidCtrl.text.replaceAll(',', '')) ?? 0;
  double get _otherDeductions =>
      double.tryParse(_otherDeductionsCtrl.text.replaceAll(',', '')) ?? 0;

  List<ContInvoiceLineModel> _collectLines() {
    final out = <ContInvoiceLineModel>[];
    var sort = 0;
    var itemNo = 1;
    for (final loc in _sectionOrder) {
      final lines = _sections[loc] ?? const [];
      for (final ed in lines) {
        out.add(ed.toModel(sortOrder: sort, itemNo: itemNo, location: loc));
        sort += 1;
        itemNo += 1;
      }
    }
    return out;
  }

  double get _grandTotal =>
      _collectLines().fold<double>(0, (s, l) => s + l.lineTotal);

  double get _amountDue =>
      double.parse((_grandTotal - _previouslyPaid - _otherDeductions)
          .toStringAsFixed(2));

  void _addSectionFromLabel(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر أو اكتب اسم المبنى / مكان العمل')),
      );
      return;
    }
    if (_sections.containsKey(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا المكان موجود بالفعل')),
      );
      return;
    }
    setState(() {
      _sections[name] = [_LineEditors.empty()];
      _sectionOrder.add(name);
      _newLocationCtrl.clear();
      _pickedLocation = null;
    });
  }

  void _addSectionManual() => _addSectionFromLabel(_newLocationCtrl.text);

  void _addSectionFromStructure() {
    final opt = _pickedLocation;
    if (opt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مكاناً من هيكلة المشروع')),
      );
      return;
    }
    // نستخدم اسم العقدة (مثل T1-101)؛ إن تكرر نستخدم المسار الكامل.
    final short = opt.name.trim();
    final label = _sections.containsKey(short) ? opt.path : short;
    _addSectionFromLabel(label);
  }

  void _removeSection(String loc) {
    setState(() {
      for (final line in _sections[loc] ?? const []) {
        line.dispose();
      }
      _sections.remove(loc);
      _sectionOrder.remove(loc);
    });
  }

  void _addLine(String loc) {
    setState(() {
      _sections.putIfAbsent(loc, () => []);
      _sections[loc]!.add(_LineEditors.empty());
    });
  }

  void _removeLine(String loc, int index) {
    setState(() {
      final list = _sections[loc];
      if (list == null || index < 0 || index >= list.length) return;
      list[index].dispose();
      list.removeAt(index);
      if (list.isEmpty) {
        _sections.remove(loc);
        _sectionOrder.remove(loc);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _statementDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _statementDate = picked);
    }
  }

  Future<void> _save() async {
    if (_contractor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المقاول')),
      );
      return;
    }
    if (_project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر المشروع')),
      );
      return;
    }
    final lines = _collectLines();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف بنداً واحداً على الأقل')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = _storage as ApiStorageService;
      final payload = ContInvoiceModel(
        id: widget.existing?.id,
        contractorId: _contractor!.id,
        contractorName: _contractor!.name,
        projectId: _project!.id,
        projectName: _project!.name,
        statementDate: _statementDate,
        contractType: _contractTypeCtrl.text.trim().isEmpty
            ? contInvoicesDefaultContractType
            : _contractTypeCtrl.text.trim(),
        previouslyPaid: _previouslyPaid,
        otherDeductions: _otherDeductions,
        notes: _notesCtrl.text.trim(),
        lines: lines,
      );

      final ContInvoiceModel saved;
      if (widget.existing?.id != null) {
        saved = await api.updateContInvoice(
          id: widget.existing!.id!,
          userId: widget.currentUser.id,
          invoice: payload,
        );
      } else {
        saved = await api.createContInvoice(
          userId: widget.currentUser.id,
          invoice: payload,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم الحفظ — المستحق: ${_moneyFmt.format(saved.amountDue)}',
          ),
        ),
      );
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing?.id != null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'تعديل Cont-Invoices' : 'مستخلص مقاول جديد'),
          actions: [
            TextButton.icon(
              onPressed: _saving || _loadingMeta ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('حفظ المسودة'),
            ),
          ],
        ),
        body: _loadingMeta
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 12),
                      _buildAddLocationCard(),
                      const SizedBox(height: 12),
                      ..._sectionOrder.map(_buildSectionCard),
                      const SizedBox(height: 12),
                      _buildTotalsCard(),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(
                          isEdit ? 'تحديث المسودة' : 'حفظ المسودة',
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'شركة وود اند مور — عقد مقاولة / مستخلص',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
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
              onChanged: _onContractorChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProjectModel>(
              value: _project,
              decoration: const InputDecoration(
                labelText: 'المشروع / العملية',
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
              onChanged: _onProjectChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _contractTypeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'نوع المقاولة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ المستخلص',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_statementDate),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddLocationCard() {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إضافة مبنى / مكان عمل',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_LocationOption>(
                    value: _pickedLocation,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _project == null
                          ? 'اختر المشروع أولاً — هيكلة المشروعات'
                          : _locationOptions.isEmpty
                              ? 'لا توجد مواقع في هيكلة هذا المشروع'
                              : 'من هيكلة المشروع',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _locationOptions
                        .map(
                          (o) => DropdownMenuItem(
                            value: o,
                            child: Text(
                              '${o.path}${o.type == 'work_site' ? ' (موقع عمل)' : ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _locationOptions.isEmpty
                        ? null
                        : (v) => setState(() => _pickedLocation = v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed:
                      _locationOptions.isEmpty ? null : _addSectionFromStructure,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('إضافة من الهيكلة'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newLocationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'أو إدخال يدوي (مثل T1-101 / Kids Area)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addSectionManual(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _addSectionManual,
                  icon: const Icon(Icons.add_business),
                  label: const Text('إضافة يدوي'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String loc) {
    final lines = _sections[loc] ?? const [];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFFF59D),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'حذف المكان',
                    onPressed: () => _removeSection(loc),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(lines.length, (i) {
              return _lineCard(loc, i, lines[i]);
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _addLine(loc),
                icon: const Icon(Icons.add),
                label: const Text('إضافة بند'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(String loc, int index, _LineEditors ed) {
    final model = ed.toModel(sortOrder: index, itemNo: index + 1, location: loc);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.teal.shade700,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'بند المستخلص',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف البند',
                  onPressed: () => _removeLine(loc, index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ed.description,
              decoration: const InputDecoration(
                labelText: 'البند / الوصف',
                border: OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _labeledField(
                  width: 140,
                  child: DropdownButtonFormField<String>(
                    value: contInvoicesUnitOptions.contains(ed.unit)
                        ? ed.unit
                        : contInvoicesUnitOptions.first,
                    decoration: const InputDecoration(
                      labelText: 'الوحدة',
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: contInvoicesUnitOptions
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => ed.unit = v);
                    },
                  ),
                ),
                _numFieldLabeled(ed.prevQty, 'الكمية السابقة', 150),
                _numFieldLabeled(ed.currentQty, 'الكمية الحالية', 150),
                _readonlyChip('إجمالي الكمية', _qtyFmt.format(model.totalQty)),
                _numFieldLabeled(ed.unitPrice, 'سعر الوحدة', 160),
                _numFieldLabeled(ed.percent, 'نسبة الإتمام %', 150),
                _readonlyChip(
                  'الإجمالي',
                  _moneyFmt.format(model.lineTotal),
                  emphasize: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeledField({required double width, required Widget child}) {
    return SizedBox(width: width, child: child);
  }

  Widget _numFieldLabeled(
    TextEditingController ctrl,
    String label,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _readonlyChip(String label, String value, {bool emphasize = false}) {
    return Container(
      width: emphasize ? 180 : 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFE0F2F1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasize ? Colors.teal : Colors.blueGrey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: emphasize ? 16 : 14,
              color: emphasize ? Colors.teal.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard() {
    return Card(
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _previouslyPaidCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'السابق صرفه',
                      helperText: _previouslyPaidHint,
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      _previouslyPaidTouched = true;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _otherDeductionsCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'خصومات أخرى',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _totalRow('الإجمالي', _grandTotal, emphasize: true),
            _totalRow('السابق صرفه', _previouslyPaid),
            _totalRow('خصومات أخرى', _otherDeductions),
            const Divider(),
            _totalRow('المستحق', _amountDue, emphasize: true, due: true),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool emphasize = false,
    bool due = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
                fontSize: emphasize ? 16 : 14,
              ),
            ),
          ),
          Text(
            _moneyFmt.format(value),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: emphasize ? 18 : 14,
              color: due ? Colors.indigo : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationOption {
  final int id;
  final String name;
  final String path;
  final String type;

  const _LocationOption({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      other is _LocationOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class _LineEditors {
  final TextEditingController description;
  final TextEditingController prevQty;
  final TextEditingController currentQty;
  final TextEditingController unitPrice;
  final TextEditingController percent;
  String unit;

  _LineEditors({
    required this.description,
    required this.prevQty,
    required this.currentQty,
    required this.unitPrice,
    required this.percent,
    this.unit = 'عدد',
  });

  factory _LineEditors.empty() => _LineEditors(
        description: TextEditingController(),
        prevQty: TextEditingController(text: '0'),
        currentQty: TextEditingController(text: '0'),
        unitPrice: TextEditingController(text: '0'),
        percent: TextEditingController(text: '100'),
      );

  factory _LineEditors.fromModel(ContInvoiceLineModel m) => _LineEditors(
        description: TextEditingController(text: m.description),
        prevQty: TextEditingController(text: _trimNum(m.prevQty)),
        currentQty: TextEditingController(text: _trimNum(m.currentQty)),
        unitPrice: TextEditingController(text: _trimNum(m.unitPrice)),
        percent: TextEditingController(text: _trimNum(m.percent)),
        unit: m.unit.isEmpty ? 'عدد' : m.unit,
      );

  static String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  ContInvoiceLineModel toModel({
    required int sortOrder,
    required int itemNo,
    required String location,
  }) {
    double parse(TextEditingController c) =>
        double.tryParse(c.text.replaceAll(',', '')) ?? 0;
    return ContInvoiceLineModel(
      sortOrder: sortOrder,
      itemNo: itemNo,
      locationLabel: location,
      description: description.text.trim(),
      unit: unit,
      prevQty: parse(prevQty),
      currentQty: parse(currentQty),
      unitPrice: parse(unitPrice),
      percent: percent.text.trim().isEmpty ? 100 : parse(percent),
    );
  }

  void dispose() {
    description.dispose();
    prevQty.dispose();
    currentQty.dispose();
    unitPrice.dispose();
    percent.dispose();
  }
}
