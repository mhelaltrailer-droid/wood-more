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
  /// قيمة اليومية (عطلات/ملاحظات) أو المبلغ الإجمالي (انتقالات/خصم).
  final TextEditingController amount;
  /// عدد اليوميات — لعطلات وملاحظات فقط.
  final TextEditingController days;
  final TextEditingController description;
  String deductionKind;
  ContractorModel? counterparty;

  _ManualLineState({
    required this.kind,
    required this.amount,
    required this.description,
    TextEditingController? days,
    this.deductionKind = 'مقطوعية',
    this.counterparty,
  }) : days = days ?? TextEditingController(text: '1');

  void dispose() {
    amount.dispose();
    days.dispose();
    description.dispose();
  }

  double get displayTotal {
    if (kind == contLineKindHoliday || kind == contLineKindNoteOnOther) {
      final d = double.tryParse(days.text.replaceAll(',', '').trim()) ?? 0;
      final v = double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
      return d * v;
    }
    return double.tryParse(amount.text.replaceAll(',', '').trim()) ?? 0;
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
  String _contractTypeChoice = contInvoicesDefaultContractType;
  final _contractTypeOtherCtrl = TextEditingController();
  final _previouslyPaidCtrl = TextEditingController(text: '0');
  final _otherDeductionsCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  bool get _isFlooring =>
      (_measureType ?? invoiceStructureMeasureFlooring) ==
      invoiceStructureMeasureFlooring;
  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;

  String get _resolvedContractType {
    if (_contractTypeChoice == contInvoicesContractTypeOther) {
      final t = _contractTypeOtherCtrl.text.trim();
      return t.isEmpty ? contInvoicesContractTypeOther : t;
    }
    return contInvoicesDefaultContractType;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _contractTypeOtherCtrl.dispose();
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
    final ct = inv.contractType.trim();
    if (ct.isEmpty || ct == contInvoicesDefaultContractType) {
      _contractTypeChoice = contInvoicesDefaultContractType;
      _contractTypeOtherCtrl.clear();
    } else {
      _contractTypeChoice = contInvoicesContractTypeOther;
      _contractTypeOtherCtrl.text = ct;
    }
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
          text: e0 == null
              ? '0'
              : _trim(e0.percent.clamp(0, 100).toDouble()),
        ),
        prevPercent: e0?.prevPercent ?? 0,
      );
      for (final m in manuals) {
        section.manuals.add(_manualFromLine(m));
      }
      _sections.add(section);
    }
    // orphan manuals without location — attach under synthetic section if needed
    if (orphans.isNotEmpty && _sections.isNotEmpty) {
      for (final m in orphans.where((e) => !e.isExecution)) {
        _sections.last.manuals.add(_manualFromLine(m));
      }
    }
  }

  _ManualLineState _manualFromLine(ContInvoiceLineModel m) {
    final isDaysBased = m.lineKind == contLineKindHoliday ||
        m.lineKind == contLineKindNoteOnOther;
    final days = isDaysBased && m.baseQty > 0 ? m.baseQty : 1;
    final rate = isDaysBased
        ? (m.unitPrice.abs() > 0
            ? m.unitPrice.abs()
            : (days > 0 ? m.lineTotal.abs() / days : m.lineTotal.abs()))
        : m.unitPrice.abs();
    return _ManualLineState(
      kind: m.lineKind,
      amount: TextEditingController(text: _trim(rate)),
      days: TextEditingController(text: _trim(days.toDouble())),
      description: TextEditingController(text: m.description),
      deductionKind: m.deductionKind.isEmpty ? 'مقطوعية' : m.deductionKind,
      counterparty: _contractors.cast<ContractorModel?>().firstWhere(
            (c) =>
                c?.id == m.counterpartyContractorId ||
                c?.name == m.counterpartyContractorName,
            orElse: () => null,
          ),
    );
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
            text: prevPercent > 0
                ? _trim(prevPercent.clamp(0, 100).toDouble())
                : '0',
          ),
          prevPercent: prevPercent.clamp(0, 100).toDouble(),
        ),
      );
    });
  }

  List<ContractorModel> get _otherContractors =>
      _contractors.where((c) => c.id != widget.contractor.id).toList();

  Future<void> _addManual(_SectionState section, String kind) async {
    if (kind == contLineKindNoteOnOther) {
      await _addNotesDialog(section);
      return;
    }
    if (kind == contLineKindDeduction) {
      await _addDeductionDialog(section);
      return;
    }
    if (kind == contLineKindHoliday) {
      await _addHolidayDialog(section);
      return;
    }
    // transport — قيمة واحدة
    final amountC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقالات'),
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
          description: TextEditingController(text: 'انتقالات'),
        ),
      );
    });
  }

  Future<void> _addHolidayDialog(_SectionState section) async {
    final daysC = TextEditingController(text: '1');
    final rateC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final total = _parse(daysC.text) * _parse(rateC.text);
          return AlertDialog(
            title: const Text('عطلات'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: daysC,
                  decoration: const InputDecoration(
                    labelText: 'عدد اليوميات',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateC,
                  decoration: const InputDecoration(
                    labelText: 'قيمة اليومية',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'الإجمالي',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _moneyFmt.format(total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
                  if (_parse(daysC.text) <= 0 || _parse(rateC.text) <= 0) {
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final days = _parse(daysC.text);
    final rate = _parse(rateC.text);
    setState(() {
      section.manuals.add(
        _ManualLineState(
          kind: contLineKindHoliday,
          amount: TextEditingController(text: _trim(rate)),
          days: TextEditingController(text: _trim(days)),
          description: TextEditingController(
            text: 'عطلات — ${_trim(days)} × ${_trim(rate)}',
          ),
        ),
      );
    });
  }

  Future<void> _addDeductionDialog(_SectionState section) async {
    String dedKind = contDeductionKindOptions.first;
    bool creditOther = false;
    ContractorModel? other;
    final amountC = TextEditingController();
    final otherDesc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('خصم'),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('خصم لصالح مقاول اخر'),
                  value: creditOther,
                  onChanged: (v) => setLocal(() {
                    creditOther = v ?? false;
                    if (!creditOther) other = null;
                  }),
                ),
                if (creditOther) ...[
                  DropdownButtonFormField<ContractorModel>(
                    value: other,
                    decoration: const InputDecoration(
                      labelText: 'المقاول',
                      border: OutlineInputBorder(),
                    ),
                    items: _otherContractors
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        )
                        .toList(),
                    onChanged: (v) => setLocal(() => other = v),
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
                if (_parse(amountC.text) <= 0) return;
                if (creditOther && other == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final counterparty = creditOther ? other : null;
    final desc = dedKind == 'أخرى' && otherDesc.text.trim().isNotEmpty
        ? otherDesc.text.trim()
        : (counterparty != null
            ? 'خصم — $dedKind لصالح ${counterparty.name}'
            : 'خصم — $dedKind');
    setState(() {
      section.manuals.add(
        _ManualLineState(
          kind: contLineKindDeduction,
          amount: TextEditingController(text: amountC.text.trim()),
          description: TextEditingController(text: desc),
          deductionKind: dedKind,
          counterparty: counterparty,
        ),
      );
    });
  }

  Future<void> _addNotesDialog(_SectionState section) async {
    bool deductOther = false;
    ContractorModel? other;
    final daysC = TextEditingController(text: '1');
    final rateC = TextEditingController();
    final descC = TextEditingController(text: 'يوميات ملاحظات');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final total = _parse(daysC.text) * _parse(rateC.text);
          return AlertDialog(
            title: const Text('يوميات ملاحظات'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: daysC,
                    decoration: const InputDecoration(
                      labelText: 'عدد اليوميات',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateC,
                    decoration: const InputDecoration(
                      labelText: 'قيمة اليومية',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'إجمالي القيمة',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _moneyFmt.format(total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('خصم على مقاول آخر'),
                    value: deductOther,
                    onChanged: (v) => setLocal(() {
                      deductOther = v ?? false;
                      if (!deductOther) other = null;
                    }),
                  ),
                  if (deductOther) ...[
                    DropdownButtonFormField<ContractorModel>(
                      value: other,
                      decoration: const InputDecoration(
                        labelText: 'المقاول الآخر',
                        border: OutlineInputBorder(),
                      ),
                      items: _otherContractors
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => other = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: descC,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      border: OutlineInputBorder(),
                    ),
                  ),
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
                  if (_parse(daysC.text) <= 0 || _parse(rateC.text) <= 0) {
                    return;
                  }
                  if (deductOther && other == null) return;
                  Navigator.pop(ctx, true);
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final days = _parse(daysC.text);
    final rate = _parse(rateC.text);
    setState(() {
      section.manuals.add(
        _ManualLineState(
          kind: contLineKindNoteOnOther,
          amount: TextEditingController(text: _trim(rate)),
          days: TextEditingController(text: _trim(days)),
          description: TextEditingController(text: descC.text.trim()),
          counterparty: deductOther ? other : null,
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
      final percent = _parse(s.currentPercent.text).clamp(0, 100).toDouble();
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
        final isDaysBased = m.kind == contLineKindHoliday ||
            m.kind == contLineKindNoteOnOther;
        out.add(
          ContInvoiceLineModel(
            sortOrder: sort++,
            itemNo: itemNo++,
            lineKind: m.kind,
            structureLocationId: s.structureLocationId,
            locationLabel: s.pathLabel,
            description: m.description.text.trim(),
            unit: isDaysBased ? 'يومية' : 'مقط',
            baseQty: isDaysBased ? _parse(m.days.text) : 1,
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
        contractType: _resolvedContractType,
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

  static const double _metricBoxW = 150;
  static const double _metricBoxH = 68;

  Widget _metricShell({
    required String label,
    required Widget child,
    Color? fill,
    Color? border,
  }) {
    return Container(
      width: _metricBoxW,
      height: _metricBoxH,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: fill ?? Colors.white,
        border: Border.all(
          color: border ?? const Color(0xFFB0BEC5),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey[700], height: 1.1),
          ),
          const SizedBox(height: 4),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _metricFieldBox({
    required String label,
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return _metricShell(
      label: label,
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: inputFormatters ??
            [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: onChanged,
      ),
    );
  }

  Widget _metricReadonlyBox({
    required String label,
    required String value,
    Color? fill,
    Color? border,
    Color? valueColor,
  }) {
    return _metricShell(
      label: label,
      fill: fill,
      border: border,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: valueColor,
          ),
        ),
      ),
    );
  }

  void _onPercentChanged(TextEditingController ctrl) {
    final raw = ctrl.text.replaceAll(',', '').trim();
    if (raw.isEmpty) {
      setState(() {});
      return;
    }
    final v = double.tryParse(raw);
    if (v != null && v > 100) {
      ctrl.value = const TextEditingValue(
        text: '100',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
    setState(() {});
  }

  Widget _buildSection(_SectionState s) {
    final baseQty = _parse(s.baseQty.text);
    final unitPrice = _parse(s.unitPrice.text);
    final percent = _parse(s.currentPercent.text).clamp(0, 100).toDouble();
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
                  _metricFieldBox(
                    label: 'عدد الأمتار',
                    controller: s.baseQty,
                    onChanged: (_) => setState(() {}),
                  ),
                _metricFieldBox(
                  label: _isFlooring ? 'سعر المتر' : 'قيمة الـ Unit',
                  controller: s.unitPrice,
                  onChanged: (_) => setState(() {}),
                ),
                _metricReadonlyBox(
                  label: 'النسبة السابقة',
                  value: '${_trim(s.prevPercent)} %',
                  fill: const Color(0xFFF5F5F5),
                ),
                _metricFieldBox(
                  label: 'النسبة الحالية %',
                  controller: s.currentPercent,
                  onChanged: (_) => _onPercentChanged(s.currentPercent),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    _MaxValueInputFormatter(100),
                  ],
                ),
                _metricReadonlyBox(
                  label: 'المستحق لهذه الفاتورة',
                  value: _moneyFmt.format(due),
                  fill: const Color(0xFFE0F2F1),
                  border: Colors.teal,
                  valueColor: Colors.teal.shade800,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _manualChip(
                  'عطلات',
                  Icons.add_circle_outline,
                  () => _addManual(s, contLineKindHoliday),
                ),
                _manualChip(
                  'انتقالات',
                  Icons.directions_car,
                  () => _addManual(s, contLineKindTransport),
                ),
                _manualChip(
                  'خصم',
                  Icons.remove_circle_outline,
                  () => _addManual(s, contLineKindDeduction),
                ),
                _manualChip(
                  'اضافة يوميات',
                  Icons.notes,
                  () => _addManual(s, contLineKindNoteOnOther),
                ),
              ],
            ),
            if (s.manuals.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...List.generate(s.manuals.length, (i) {
                final m = s.manuals[i];
                final sign = m.kind == contLineKindDeduction ? '-' : '+';
                String? sub;
                if (m.counterparty != null) {
                  sub = m.kind == contLineKindDeduction
                      ? 'لصالح: ${m.counterparty!.name}'
                      : 'خصم على: ${m.counterparty!.name}';
                }
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.description.text),
                  subtitle: sub != null ? Text(sub) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$sign${_moneyFmt.format(m.displayTotal)}',
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
                            child: DropdownButtonFormField<String>(
                              value: _contractTypeChoice,
                              decoration: const InputDecoration(
                                labelText: 'نوع المقاولة',
                                border: OutlineInputBorder(),
                              ),
                              items: contInvoicesContractTypeChoices
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _contractTypeChoice = v);
                              },
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
                      if (_contractTypeChoice ==
                          contInvoicesContractTypeOther) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contractTypeOtherCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اكتب نوع المقاولة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _addLocation,
                        icon: const Icon(Icons.account_tree_outlined),
                        label: const Text('إضافة موقع'),
                      ),
                      const SizedBox(height: 12),
                      if (_sections.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'أضف موقعاً من هيكلة المستخلصات للبدء.',
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

/// يمنع إدخال قيمة أكبر من [max] أثناء الكتابة.
class _MaxValueInputFormatter extends TextInputFormatter {
  final double max;

  _MaxValueInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final t = newValue.text.replaceAll(',', '').trim();
    if (t.isEmpty || t == '.') return newValue;
    final v = double.tryParse(t);
    if (v == null) return oldValue;
    if (v > max) {
      final capped = max == max.roundToDouble()
          ? max.toInt().toString()
          : max.toString();
      return TextEditingValue(
        text: capped,
        selection: TextSelection.collapsed(offset: capped.length),
      );
    }
    return newValue;
  }
}
