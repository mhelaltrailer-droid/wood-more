import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../core/cont_invoices_constants.dart';
import '../core/invoice_structure_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/contractor_model.dart';
import '../models/invoice_structure_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

/// الشاشة 2: بنود التنفيذ + الأربعة اليدوية بعد اختيار المواقع من هيكلة المستخلصات.
class ContInvoicesWorkScreen extends StatefulWidget {
  final UserModel currentUser;
  final ContractorModel contractor;
  final ProjectModel project;
  final ContInvoiceModel? existing;

  const ContInvoicesWorkScreen({
    super.key,
    required this.currentUser,
    required this.contractor,
    required this.project,
    this.existing,
  });

  @override
  State<ContInvoicesWorkScreen> createState() => _ContInvoicesWorkScreenState();
}

class _SectionState {
  final int structureLocationId;
  final String pathLabel;
  final TextEditingController baseQty;
  final TextEditingController unitPrice;
  final TextEditingController currentPercent;
  double prevPercent;
  final List<_ManualLineState> manuals;

  _SectionState({
    required this.structureLocationId,
    required this.pathLabel,
    required this.baseQty,
    required this.unitPrice,
    required this.currentPercent,
    this.prevPercent = 0,
    List<_ManualLineState>? manuals,
  }) : manuals = manuals ?? [];

  void dispose() {
    baseQty.dispose();
    unitPrice.dispose();
    currentPercent.dispose();
    for (final m in manuals) {
      m.dispose();
    }
  }
}

class _ManualLineState {
  final String kind;
  final TextEditingController amount;
  final TextEditingController description;
  String deductionKind;
  ContractorModel? counterparty;

  _ManualLineState({
    required this.kind,
    required this.amount,
    required this.description,
    this.deductionKind = 'مقطوعية',
    this.counterparty,
  });

  void dispose() {
    amount.dispose();
    description.dispose();
  }
}

class _ContInvoicesWorkScreenState extends State<ContInvoicesWorkScreen> {
  final _storage = getStorage();
  final _moneyFmt = NumberFormat('#,##0.00', 'en_US');

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _measureType;
  List<InvoiceStructureLocationModel> _structureLocs = const [];
  List<ContractorModel> _contractors = const [];
  final List<_SectionState> _sections = [];

  DateTime _statementDate = DateTime.now();
  final _contractTypeCtrl = TextEditingController(
    text: contInvoicesDefaultContractType,
  );
  final _previouslyPaidCtrl = TextEditingController(text: '0');
  final _otherDeductionsCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  bool get _isFlooring =>
      (_measureType ?? invoiceStructureMeasureFlooring) ==
      invoiceStructureMeasureFlooring;
  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;

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
    for (final s in _sections) {
      s.dispose();
    }
    super.dispose();
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

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_isApi) throw Exception('Cont-Invoices يتطلب الاتصال بالخادم');
      final structure = await _api.getInvoiceStructure(
        userId: widget.currentUser.id,
        projectId: widget.project.id,
      );
      final contractors = await _api.getContractors();
      _measureType = structure.measureType;
      _structureLocs = structure.locations;
      _contractors = contractors;

      if (widget.existing?.id != null) {
        final detail = await _api.getContInvoiceDetail(
          widget.existing!.id!,
          widget.currentUser.id,
        );
        _applyExisting(detail);
      } else {
        await _autofillPreviouslyPaid();
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _autofillPreviouslyPaid() async {
    try {
      final data = await _api.getContInvoicePreviousPaid(
        userId: widget.currentUser.id,
        contractorId: widget.contractor.id,
        contractorName: widget.contractor.name,
      );
      final amount = (data['previously_paid'] is num)
          ? (data['previously_paid'] as num).toDouble()
          : 0.0;
      _previouslyPaidCtrl.text = amount == amount.roundToDouble()
          ? amount.toInt().toString()
          : amount.toString();
    } catch (_) {}
  }

  void _applyExisting(ContInvoiceModel inv) {
    _statementDate = inv.statementDate ?? DateTime.now();
    _contractTypeCtrl.text = inv.contractType;
    _previouslyPaidCtrl.text = inv.previouslyPaid.toString();
    _otherDeductionsCtrl.text = inv.otherDeductions.toString();
    _notesCtrl.text = inv.notes;

    final byLoc = <int, List<ContInvoiceLineModel>>{};
    final orphans = <ContInvoiceLineModel>[];
    for (final line in inv.lines) {
      final sid = line.structureLocationId;
      if (sid == null) {
        orphans.add(line);
        continue;
      }
      byLoc.putIfAbsent(sid, () => []).add(line);
    }
    for (final entry in byLoc.entries) {
      final loc = _structureLocs.cast<InvoiceStructureLocationModel?>().firstWhere(
            (l) => l?.id == entry.key,
            orElse: () => null,
          );
      final path = loc != null ? _pathOf(loc) : (entry.value.first.locationLabel);
      final exec = entry.value.where((e) => e.isExecution).toList();
      final manuals = entry.value.where((e) => !e.isExecution).toList();
      final e0 = exec.isNotEmpty ? exec.first : null;
      final section = _SectionState(
        structureLocationId: entry.key,
        pathLabel: path.isEmpty ? 'موقع ${entry.key}' : path,
        baseQty: TextEditingController(
          text: e0 == null ? '' : _trim(e0.baseQty),
        ),
        unitPrice: TextEditingController(
          text: e0 == null ? '' : _trim(e0.unitPrice),
        ),
        currentPercent: TextEditingController(
          text: e0 == null ? '0' : _trim(e0.percent),
        ),
        prevPercent: e0?.prevPercent ?? 0,
      );
      for (final m in manuals) {
        section.manuals.add(
          _ManualLineState(
            kind: m.lineKind,
            amount: TextEditingController(text: _trim(m.unitPrice.abs())),
            description: TextEditingController(text: m.description),
            deductionKind:
                m.deductionKind.isEmpty ? 'مقطوعية' : m.deductionKind,
            counterparty: _contractors.cast<ContractorModel?>().firstWhere(
                  (c) =>
                      c?.id == m.counterpartyContractorId ||
                      c?.name == m.counterpartyContractorName,
                  orElse: () => null,
                ),
          ),
        );
      }
      _sections.add(section);
    }
    // orphan manuals without location — attach under synthetic section if needed
    if (orphans.isNotEmpty && _sections.isNotEmpty) {
      for (final m in orphans.where((e) => !e.isExecution)) {
        _sections.last.manuals.add(
          _ManualLineState(
            kind: m.lineKind,
            amount: TextEditingController(text: _trim(m.unitPrice.abs())),
            description: TextEditingController(text: m.description),
            deductionKind:
                m.deductionKind.isEmpty ? 'مقطوعية' : m.deductionKind,
          ),
        );
      }
    }
  }

  static String _trim(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  double _parse(String s) =>
      double.tryParse(s.replaceAll(',', '').trim()) ?? 0;

  Future<void> _addLocation() async {
    if (_structureLocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد مواقع في هيكلة المستخلصات لهذا المشروع'),
        ),
      );
      return;
    }
    final used = _sections.map((s) => s.structureLocationId).toSet();
    final options = _structureLocs
        .where((l) => !used.contains(l.id))
        .toList()
      ..sort((a, b) => _pathOf(a).compareTo(_pathOf(b)));
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة كل المواقع المتاحة')),
      );
      return;
    }
    final picked = await showDialog<InvoiceStructureLocationModel>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('اختر موقعاً من هيكلة المستخلصات'),
        children: options
            .map(
              (o) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, o),
                child: Text(_pathOf(o)),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;

    double baseQty = _isFlooring
        ? (picked.totalMeters ?? 0)
        : 1;
    double unitPrice = _isFlooring
        ? (picked.meterPrice ?? 0)
        : (picked.unitValue ?? 0);
    double prevPercent = 0;

    try {
      final prog = await _api.getContInvoiceLocationProgress(
        userId: widget.currentUser.id,
        projectId: widget.project.id,
        structureLocationId: picked.id,
        contractorId: widget.contractor.id,
        contractorName: widget.contractor.name,
        excludeId: widget.existing?.id,
      );
      if (prog['has_previous'] == true) {
        prevPercent = (prog['prev_percent'] is num)
            ? (prog['prev_percent'] as num).toDouble()
            : 0;
        if (prog['base_qty'] is num && (prog['base_qty'] as num) > 0) {
          baseQty = (prog['base_qty'] as num).toDouble();
        }
        if (prog['unit_price'] is num && (prog['unit_price'] as num) > 0) {
          unitPrice = (prog['unit_price'] as num).toDouble();
        }
      }
    } catch (_) {}

    setState(() {
      _sections.add(
        _SectionState(
          structureLocationId: picked.id,
          pathLabel: _pathOf(picked),
          baseQty: TextEditingController(
            text: baseQty > 0 ? _trim(baseQty) : '',
          ),
          unitPrice: TextEditingController(
            text: unitPrice > 0 ? _trim(unitPrice) : '',
          ),
          currentPercent: TextEditingController(
            text: prevPercent > 0 ? _trim(prevPercent) : '0',
          ),
          prevPercent: prevPercent,
        ),
      );
    });
  }

  Future<void> _addManual(_SectionState section, String kind) async {
    if (kind == contLineKindNoteOnOther) {
      ContractorModel? other;
      final amountC = TextEditingController();
      final descC = TextEditingController(text: 'يوميات ملاحظات بالخصم على مقاول آخر');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('يوميات ملاحظات بالخصم على مقاول آخر'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ContractorModel>(
                  value: other,
                  decoration: const InputDecoration(
                    labelText: 'المقاول الآخر',
                    border: OutlineInputBorder(),
                  ),
                  items: _contractors
                      .where((c) => c.id != widget.contractor.id)
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => other = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountC,
                  decoration: const InputDecoration(
                    labelText: 'القيمة',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descC,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  if (other == null || _parse(amountC.text) <= 0) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || other == null) return;
      setState(() {
        section.manuals.add(
          _ManualLineState(
            kind: kind,
            amount: TextEditingController(text: amountC.text.trim()),
            description: TextEditingController(text: descC.text.trim()),
            counterparty: other,
          ),
        );
      });
      return;
    }

    if (kind == contLineKindDeduction) {
      String dedKind = contDeductionKindOptions.first;
      final amountC = TextEditingController();
      final otherDesc = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('خصم'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: dedKind,
                  decoration: const InputDecoration(
                    labelText: 'نوع الخصم',
                    border: OutlineInputBorder(),
                  ),
                  items: contDeductionKindOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setLocal(() => dedKind = v ?? dedKind),
                ),
                if (dedKind == 'أخرى') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: otherDesc,
                    decoration: const InputDecoration(
                      labelText: 'وصف الخصم',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: amountC,
                  decoration: const InputDecoration(
                    labelText: 'القيمة',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  if (_parse(amountC.text) <= 0) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      );
      if (ok != true) return;
      setState(() {
        section.manuals.add(
          _ManualLineState(
            kind: kind,
            amount: TextEditingController(text: amountC.text.trim()),
            description: TextEditingController(
              text: dedKind == 'أخرى' && otherDesc.text.trim().isNotEmpty
                  ? otherDesc.text.trim()
                  : 'خصم — $dedKind',
            ),
            deductionKind: dedKind,
          ),
        );
      });
      return;
    }

    // holiday / transport
    final label = kind == contLineKindHoliday ? 'عطلات' : 'انتقالات';
    final amountC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: amountC,
          decoration: const InputDecoration(
            labelText: 'القيمة',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (_parse(amountC.text) <= 0) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      section.manuals.add(
        _ManualLineState(
          kind: kind,
          amount: TextEditingController(text: amountC.text.trim()),
          description: TextEditingController(text: label),
        ),
      );
    });
  }

  List<ContInvoiceLineModel> _collectLines() {
    final out = <ContInvoiceLineModel>[];
    var sort = 0;
    var itemNo = 1;
    for (final s in _sections) {
      final baseQty = _parse(s.baseQty.text);
      final unitPrice = _parse(s.unitPrice.text);
      final percent = _parse(s.currentPercent.text);
      out.add(
        ContInvoiceLineModel(
          sortOrder: sort++,
          itemNo: itemNo++,
          lineKind: contLineKindExecution,
          structureLocationId: s.structureLocationId,
          locationLabel: s.pathLabel,
          description: s.pathLabel,
          unit: _isFlooring ? 'م2' : 'مقط',
          baseQty: _isFlooring ? baseQty : 1,
          unitPrice: unitPrice,
          prevPercent: s.prevPercent,
          percent: percent,
        ),
      );
      for (final m in s.manuals) {
        out.add(
          ContInvoiceLineModel(
            sortOrder: sort++,
            itemNo: itemNo++,
            lineKind: m.kind,
            structureLocationId: s.structureLocationId,
            locationLabel: s.pathLabel,
            description: m.description.text.trim(),
            unit: 'مقط',
            baseQty: 1,
            unitPrice: _parse(m.amount.text),
            prevPercent: 0,
            percent: 100,
            deductionKind: m.kind == contLineKindDeduction ? m.deductionKind : '',
            counterpartyContractorId: m.counterparty?.id,
            counterpartyContractorName: m.counterparty?.name ?? '',
          ),
        );
      }
    }
    return out;
  }

  double get _grandTotal =>
      _collectLines().fold<double>(0, (s, l) => s + l.lineTotal);
  double get _previouslyPaid => _parse(_previouslyPaidCtrl.text);
  double get _otherDeductions => _parse(_otherDeductionsCtrl.text);
  double get _amountDue =>
      double.parse((_grandTotal - _previouslyPaid - _otherDeductions)
          .toStringAsFixed(2));

  Future<void> _save() async {
    if (_sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف موقعاً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final invoice = ContInvoiceModel(
        id: widget.existing?.id,
        contractorId: widget.contractor.id,
        contractorName: widget.contractor.name,
        projectId: widget.project.id,
        projectName: widget.project.name,
        statementDate: _statementDate,
        contractType: _contractTypeCtrl.text.trim().isEmpty
            ? contInvoicesDefaultContractType
            : _contractTypeCtrl.text.trim(),
        previouslyPaid: _previouslyPaid,
        otherDeductions: _otherDeductions,
        notes: _notesCtrl.text.trim(),
        lines: _collectLines(),
      );
      final ContInvoiceModel saved;
      if (widget.existing?.id != null) {
        saved = await _api.updateContInvoice(
          id: widget.existing!.id!,
          userId: widget.currentUser.id,
          invoice: invoice,
        );
      } else {
        saved = await _api.createContInvoice(
          userId: widget.currentUser.id,
          invoice: invoice,
        );
      }
      if (!mounted) return;
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

  Widget _manualChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _buildSection(_SectionState s) {
    final baseQty = _parse(s.baseQty.text);
    final unitPrice = _parse(s.unitPrice.text);
    final percent = _parse(s.currentPercent.text);
    final due = ContInvoiceLineModel(
      baseQty: _isFlooring ? baseQty : 1,
      unitPrice: unitPrice,
      prevPercent: s.prevPercent,
      percent: percent,
    ).executionDue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.pathLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() {
                    s.dispose();
                    _sections.remove(s);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isFlooring
                  ? 'Flooring — أمتار × سعر المتر'
                  : 'WPC — قيمة الـ Unit',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_isFlooring)
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: s.baseQty,
                      decoration: const InputDecoration(
                        labelText: 'عدد الأمتار',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: s.unitPrice,
                    decoration: InputDecoration(
                      labelText: _isFlooring ? 'سعر المتر' : 'قيمة الـ Unit',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Container(
                  width: 130,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueGrey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('النسبة السابقة', style: TextStyle(fontSize: 11)),
                      Text(
                        '${_trim(s.prevPercent)} %',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: s.currentPercent,
                    decoration: const InputDecoration(
                      labelText: 'النسبة الحالية %',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Container(
                  width: 160,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    border: Border.all(color: Colors.teal),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'المستحق لهذه الفاتورة',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        _moneyFmt.format(due),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _manualChip('عطلات', Icons.beach_access, () => _addManual(s, contLineKindHoliday)),
                _manualChip('انتقالات', Icons.directions_car, () => _addManual(s, contLineKindTransport)),
                _manualChip('خصم', Icons.remove_circle_outline, () => _addManual(s, contLineKindDeduction)),
                _manualChip(
                  'يوميات ملاحظات',
                  Icons.person_search,
                  () => _addManual(s, contLineKindNoteOnOther),
                ),
              ],
            ),
            if (s.manuals.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(s.manuals.length, (i) {
                final m = s.manuals[i];
                final sign = m.kind == contLineKindDeduction ? '-' : '+';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.description.text),
                  subtitle: m.counterparty != null
                      ? Text('على: ${m.counterparty!.name}')
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$sign${_moneyFmt.format(_parse(m.amount.text))}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: m.kind == contLineKindDeduction
                              ? Colors.red
                              : Colors.green.shade800,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          m.dispose();
                          s.manuals.removeAt(i);
                        }),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing?.id != null;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'تعديل مستخلص' : 'مستخلص مقاول'),
          actions: [
            TextButton.icon(
              onPressed: _saving || _loading ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('حفظ'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: const Color(0xFFE8F5E9),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'المقاول: ${widget.contractor.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'المشروع: ${widget.project.name}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (_measureType != null) ...[
                                const SizedBox(height: 4),
                                Text(invoiceStructureMeasureLabel(_measureType)),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _contractTypeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'نوع المقاولة (تركيب أو آخر)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _statementDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) {
                                  setState(() => _statementDate = d);
                                }
                              },
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
                      FilledButton.tonalIcon(
                        onPressed: _addLocation,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('إضافة موقع من هيكلة المستخلصات'),
                      ),
                      const SizedBox(height: 12),
                      if (_sections.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'أضف موقعاً فرعياً أو موقع عمل من هيكلة المستخلصات للبدء.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ..._sections.map(_buildSection),
                      const SizedBox(height: 8),
                      Card(
                        color: const Color(0xFFE8F5E9),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _previouslyPaidCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'السابق صرفه',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _otherDeductionsCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'خصومات أخرى',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _sumRow('الإجمالي', _grandTotal, bold: true),
                              _sumRow('السابق صرفه', _previouslyPaid),
                              _sumRow('خصومات أخرى', _otherDeductions),
                              const Divider(),
                              _sumRow('المستحق', _amountDue, bold: true, due: true),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(isEdit ? 'تحديث المسودة' : 'حفظ المسودة'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
      ),
    );
  }

  Widget _sumRow(String label, double value, {bool bold = false, bool due = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            _moneyFmt.format(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: due ? Colors.teal.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }
}
