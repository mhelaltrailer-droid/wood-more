import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/cont_invoices_constants.dart';
import '../core/invoice_structure_constants.dart';
import '../models/cont_invoice_model.dart';
import '../models/contractor_model.dart';
import '../models/invoice_structure_location_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import '../utils/open_stored_attachment.dart';
import '../utils/reports_sys_attachment_save.dart';
import '../utils/cont_invoice_statement_pdf.dart';
import '../widgets/cont_invoice_payment_dialog.dart';

enum _ContLineEditMode { none, priceOnly, full }

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
  final _dateFmt = DateFormat('dd/MM/yyyy');

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

  String _status = contStatusDraft;
  String _returnReason = '';
  List<ContInvoiceActionModel> _actions = const [];
  List<ContInvoicePaymentModel> _payments = const [];
  List<ContInvoiceModel> _openRemainders = const [];
  double _paidAmount = 0;
  double _remainingAmount = 0;
  bool _workflowBusy = false;
  bool _exportingPdf = false;
  int? _invoiceId;

  int? get _effectiveInvoiceId => _invoiceId ?? widget.existing?.id;

  bool get _isFlooring =>
      (_measureType ?? invoiceStructureMeasureFlooring) ==
      invoiceStructureMeasureFlooring;
  bool get _isApi => _storage is ApiStorageService;
  ApiStorageService get _api => _storage as ApiStorageService;

  _ContLineEditMode get _lineEditMode {
    if (widget.currentUser.isPrimaryAppAdmin) return _ContLineEditMode.full;
    final email = widget.currentUser.email;
    switch (_status) {
      case contStatusDraft:
        return isContInvoicesQsEmail(email)
            ? _ContLineEditMode.full
            : _ContLineEditMode.none;
      case contStatusPendingPrice:
        return isContInvoicesAhAminEmail(email)
            ? _ContLineEditMode.priceOnly
            : _ContLineEditMode.none;
      case contStatusPendingPm:
        return isContInvoicesPmEmail(email)
            ? _ContLineEditMode.full
            : _ContLineEditMode.none;
      default:
        return _ContLineEditMode.none;
    }
  }

  bool get _canSaveLines => _lineEditMode != _ContLineEditMode.none;

  bool get _canSubmit =>
      _status == contStatusDraft &&
      _effectiveInvoiceId != null &&
      (isContInvoicesQsEmail(widget.currentUser.email) ||
          widget.currentUser.isPrimaryAppAdmin);

  bool get _canForward {
    if (_effectiveInvoiceId == null) return false;
    final email = widget.currentUser.email;
    if (_status == contStatusPendingPrice) {
      return isContInvoicesAhAminEmail(email) ||
          widget.currentUser.isPrimaryAppAdmin;
    }
    if (_status == contStatusPendingPm) {
      return isContInvoicesPmEmail(email) ||
          widget.currentUser.isPrimaryAppAdmin;
    }
    return false;
  }

  bool get _canReturn =>
      _status == contStatusPendingOm &&
      _effectiveInvoiceId != null &&
      (isContInvoicesOmEmail(widget.currentUser.email) ||
          widget.currentUser.isPrimaryAppAdmin);

  bool get _canApprove =>
      _status == contStatusPendingOm &&
      _effectiveInvoiceId != null &&
      (isContInvoicesOmEmail(widget.currentUser.email) ||
          widget.currentUser.isPrimaryAppAdmin);

  bool get _canRecordPayment {
    if (_effectiveInvoiceId == null) return false;
    if (_status != contStatusApproved && _status != contStatusPartiallyPaid) {
      return false;
    }
    if (_remainingCash <= 0) return false;
    return isContInvoicesAhAminEmail(widget.currentUser.email) ||
        widget.currentUser.isPrimaryAppAdmin;
  }

  bool get _showCashLedger =>
      _status == contStatusApproved ||
      _status == contStatusPartiallyPaid ||
      _status == contStatusPaid;

  bool get _canPrintStatement => canPrintContInvoiceStatement(_status);

  double get _remainingCash {
    if (_remainingAmount > 0) return _remainingAmount;
    final due = _amountDue;
    final left = double.parse((due - _paidAmount).toStringAsFixed(2));
    return left < 0 ? 0 : left;
  }

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
      await _loadOpenRemainders();
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

  bool _sameContractor(ContInvoiceModel inv) {
    if (widget.contractor.id != 0 && inv.contractorId == widget.contractor.id) {
      return true;
    }
    return inv.contractorName.trim().toLowerCase() ==
        widget.contractor.name.trim().toLowerCase();
  }

  Future<void> _loadOpenRemainders() async {
    try {
      final list = await _api.getContInvoices(widget.currentUser.id);
      final currentId = _effectiveInvoiceId;
      final open = list.where((inv) {
        if (currentId != null && inv.id == currentId) return false;
        if (inv.status != contStatusApproved &&
            inv.status != contStatusPartiallyPaid) {
          return false;
        }
        if (inv.remainingAmount <= 0.009) return false;
        return _sameContractor(inv);
      }).toList()
        ..sort((a, b) {
          final ad = a.statementDate ?? DateTime(1970);
          final bd = b.statementDate ?? DateTime(1970);
          return ad.compareTo(bd);
        });
      if (mounted) setState(() => _openRemainders = open);
    } catch (_) {}
  }

  void _applyExisting(ContInvoiceModel inv) {
    _invoiceId = inv.id;
    _status = inv.status;
    _returnReason = inv.returnReason;
    _actions = inv.actions;
    _payments = inv.payments;
    _paidAmount = inv.paidAmount;
    _remainingAmount = inv.remainingAmount;
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

  Future<void> _runWorkflow(
    Future<ContInvoiceModel> Function() call, {
    bool popOnSuccess = true,
  }) async {
    setState(() => _workflowBusy = true);
    try {
      final updated = await call();
      if (!mounted) return;
      _applyExisting(updated);
      await _loadOpenRemainders();
      if (!mounted) return;
      setState(() {});
      if (popOnSuccess) {
        Navigator.of(context).pop(updated);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تنفيذ الإجراء')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإجراء: $e')),
      );
    } finally {
      if (mounted) setState(() => _workflowBusy = false);
    }
  }

  Future<void> _confirmReturn() async {
    final commentC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرجاع لمدير المشروعات'),
        content: TextField(
          controller: commentC,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'ملاحظات الإرجاع (مطلوب)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (commentC.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('إرجاع'),
          ),
        ],
      ),
    );
    final id = _effectiveInvoiceId;
    if (ok != true || id == null) return;
    await _runWorkflow(
      () => _api.returnContInvoice(
        id: id,
        userId: widget.currentUser.id,
        comment: commentC.text.trim(),
      ),
    );
  }

  Future<Map<String, String>?> _loadPaymentFile({
    required ContInvoicePaymentModel payment,
    ContInvoicePaymentAttachmentModel? attachment,
  }) async {
    final invoiceId = _effectiveInvoiceId;
    final paymentId = payment.id;
    if (invoiceId == null || paymentId == null) return null;
    return _api.getContInvoicePaymentFile(
      invoiceId: invoiceId,
      paymentId: paymentId,
      userId: widget.currentUser.id,
      attachmentId: attachment?.id,
    );
  }

  Future<void> _openPaymentVoucher({
    required ContInvoicePaymentModel payment,
    ContInvoicePaymentAttachmentModel? attachment,
  }) async {
    try {
      final file = await _loadPaymentFile(
        payment: payment,
        attachment: attachment,
      );
      if (file == null) return;
      final raw = file['data_base64'] ?? '';
      final bytes = Uint8List.fromList(base64Decode(raw));
      final err = await openStoredAttachment(
        bytes: bytes,
        fileName: file['file_name'] ?? attachment?.fileName ?? payment.fileName,
      );
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر فتح المرفق: $err')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل مرفق الصرف: $e')),
      );
    }
  }

  Future<void> _downloadPaymentVoucher({
    required ContInvoicePaymentModel payment,
    ContInvoicePaymentAttachmentModel? attachment,
  }) async {
    try {
      final file = await _loadPaymentFile(
        payment: payment,
        attachment: attachment,
      );
      if (file == null) return;
      final raw = file['data_base64'] ?? '';
      final bytes = Uint8List.fromList(base64Decode(raw));
      final err = await saveReportsSysAttachment(
        bytes: bytes,
        fileName: file['file_name'] ?? attachment?.fileName ?? 'voucher',
        mimeType: file['mime_type'] ?? attachment?.mimeType,
      );
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر التنزيل: $err')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تنزيل المرفق: $e')),
      );
    }
  }

  Future<void> _printPaymentVoucher({
    required ContInvoicePaymentModel payment,
    ContInvoicePaymentAttachmentModel? attachment,
  }) async {
    try {
      final file = await _loadPaymentFile(
        payment: payment,
        attachment: attachment,
      );
      if (file == null) return;
      final raw = file['data_base64'] ?? '';
      final bytes = Uint8List.fromList(base64Decode(raw));
      final name = file['file_name'] ?? attachment?.fileName ?? 'voucher';
      final mime = (file['mime_type'] ?? attachment?.mimeType ?? '').toLowerCase();
      if (mime.contains('pdf') || name.toLowerCase().endsWith('.pdf')) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
        return;
      }
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        ),
      );
      await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر طباعة المرفق: $e')),
      );
    }
  }

  Future<void> _confirmRecordPayment() async {
    final remaining = _remainingCash;
    if (remaining <= 0) return;
    final draft = await showContInvoicePaymentDialog(
      context: context,
      remaining: remaining,
      moneyFmt: _moneyFmt,
      invoiceLabel:
          '${widget.project.name} — ${DateFormat('dd/MM/yyyy').format(_statementDate)}',
    );
    final id = _effectiveInvoiceId;
    if (draft == null || id == null) return;
    await _runWorkflow(
      () => _api.markContInvoicePaid(
        id: id,
        userId: widget.currentUser.id,
        amount: draft.amount,
        comment: draft.comment,
        attachments: draft.attachments,
      ),
      popOnSuccess: false,
    );
  }

  Future<void> _exportStatementPdf() async {
    if (!_canPrintStatement || _exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final inv = ContInvoiceModel(
        id: _effectiveInvoiceId,
        contractorId: widget.contractor.id,
        contractorName: widget.contractor.name,
        projectId: widget.project.id,
        projectName: widget.project.name,
        statementDate: _statementDate,
        contractType: _resolvedContractType,
        previouslyPaid: _previouslyPaid,
        otherDeductions: _otherDeductions,
        totalAmount: _grandTotal,
        amountDue: _amountDue,
        notes: _notesCtrl.text.trim(),
        status: _status,
        statusLabelAr: contInvoiceStatusLabelAr(_status),
        paidAmount: _paidAmount,
        remainingAmount: _remainingCash,
        lines: _collectLines(),
      );
      await printContInvoiceStatementPdf(inv);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تصدير المستخلص: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<ContInvoiceModel?> _persistDraft({bool pop = true}) async {
    if (!_canSaveLines) return null;
    if (_sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف موقعاً واحداً على الأقل')),
      );
      return null;
    }
    setState(() => _saving = true);
    try {
      final invoice = ContInvoiceModel(
        id: _effectiveInvoiceId,
        contractorId: widget.contractor.id,
        contractorName: widget.contractor.name,
        projectId: widget.project.id,
        projectName: widget.project.name,
        statementDate: _statementDate,
        contractType: _resolvedContractType,
        previouslyPaid: _previouslyPaid,
        otherDeductions: _otherDeductions,
        notes: _notesCtrl.text.trim(),
        status: _status,
        lines: _collectLines(),
      );
      final ContInvoiceModel saved;
      if (_effectiveInvoiceId != null) {
        saved = await _api.updateContInvoice(
          id: _effectiveInvoiceId!,
          userId: widget.currentUser.id,
          invoice: invoice,
        );
      } else {
        saved = await _api.createContInvoice(
          userId: widget.currentUser.id,
          invoice: invoice,
        );
      }
      if (!mounted) return null;
      _applyExisting(saved);
      if (pop) Navigator.of(context).pop(saved);
      return saved;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    await _persistDraft(pop: true);
  }

  Future<void> _saveThenWorkflow(
    Future<ContInvoiceModel> Function(int invoiceId) workflow,
  ) async {
    final saved = await _persistDraft(pop: false);
    final id = saved?.id ?? _effectiveInvoiceId;
    if (id == null) return;
    await _runWorkflow(
      () => workflow(id),
      popOnSuccess: true,
    );
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
    bool readOnly = false,
  }) {
    if (readOnly) {
      return _metricReadonlyBox(label: label, value: controller.text);
    }
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
    final mode = _lineEditMode;
    final readOnly = mode == _ContLineEditMode.none;
    final priceOnly = mode == _ContLineEditMode.priceOnly;
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
                if (!readOnly && !priceOnly)
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
                    readOnly: readOnly || priceOnly,
                  ),
                _metricFieldBox(
                  label: _isFlooring ? 'سعر المتر' : 'قيمة الـ Unit',
                  controller: s.unitPrice,
                  onChanged: (_) => setState(() {}),
                  readOnly: readOnly,
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
                  readOnly: readOnly || priceOnly,
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
            if (!readOnly && !priceOnly) ...[
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
            ],
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
                      if (!readOnly && !priceOnly)
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
    final headerReadOnly = _lineEditMode != _ContLineEditMode.full;
    final statusLabel = contInvoiceStatusLabelAr(_status);
    final busy = _saving || _workflowBusy || _exportingPdf;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'تعديل مستخلص' : 'مستخلص مقاول'),
          actions: [
            if (_canPrintStatement)
              IconButton(
                tooltip: 'تصدير المستخلص PDF',
                onPressed: busy || _loading || _exportingPdf
                    ? null
                    : _exportStatementPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
            if (_canSaveLines)
              TextButton.icon(
                onPressed: busy || _loading ? null : _save,
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
                        color: const Color(0xFFE3F2FD),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'الحالة: $statusLabel',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (_returnReason.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'سبب الإرجاع: ${_returnReason.trim()}',
                                  style: TextStyle(color: Colors.orange.shade900),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (_openRemainders.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card(
                          color: const Color(0xFFFFF3E0),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'مستحقات غير مصروفة سابقة',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'كل مستخلص لوحده. الباقي لا يُضاف لمستحق هذا المستخلص ولا يُدمج.',
                                ),
                                const SizedBox(height: 8),
                                ..._openRemainders.map((inv) {
                                  final dateLabel = inv.statementDate == null
                                      ? '—'
                                      : _dateFmt.format(inv.statementDate!);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '${inv.projectName} — $dateLabel\n'
                                      'باقي هذا المستخلص: ${_moneyFmt.format(inv.remainingAmount)}'
                                      '  |  ${inv.statusLabelAr.isNotEmpty ? inv.statusLabelAr : contInvoiceStatusLabelAr(inv.status)}',
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
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
                              onChanged: headerReadOnly
                                  ? null
                                  : (v) {
                                      if (v == null) return;
                                      setState(() => _contractTypeChoice = v);
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: headerReadOnly
                                  ? null
                                  : () async {
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
                          readOnly: headerReadOnly,
                          decoration: const InputDecoration(
                            labelText: 'اكتب نوع المقاولة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      if (_lineEditMode == _ContLineEditMode.full) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _addLocation,
                          icon: const Icon(Icons.account_tree_outlined),
                          label: const Text('إضافة موقع'),
                        ),
                      ],
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
                                      readOnly: headerReadOnly,
                                      decoration: const InputDecoration(
                                        labelText: 'السابق صرفه',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      onChanged: headerReadOnly
                                          ? null
                                          : (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _otherDeductionsCtrl,
                                      readOnly: headerReadOnly,
                                      decoration: const InputDecoration(
                                        labelText: 'خصومات أخرى',
                                        border: OutlineInputBorder(),
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      onChanged: headerReadOnly
                                          ? null
                                          : (_) => setState(() {}),
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
                              if (_showCashLedger) ...[
                                _sumRow('المصروف', _paidAmount),
                                _sumRow(
                                  'الباقي للصرف',
                                  _remainingCash,
                                  bold: true,
                                  due: true,
                                ),
                              ],
                              if (_canPrintStatement) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : _exportStatementPdf,
                                  icon: const Icon(Icons.picture_as_pdf_outlined),
                                  label: const Text('تصدير المستخلص PDF'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        readOnly: headerReadOnly,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_actions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'سجل الإجراءات',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._actions.reversed.take(8).map(
                              (a) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${a.action} — ${a.actorUserName}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                subtitle: a.comment.trim().isEmpty
                                    ? null
                                    : Text(a.comment),
                              ),
                            ),
                      ],
                      const SizedBox(height: 20),
                      if (_canSaveLines)
                        FilledButton.icon(
                          onPressed: busy ? null : _save,
                          icon: const Icon(Icons.save),
                          label: Text(
                            _status == contStatusDraft
                                ? (isEdit ? 'تحديث المسودة' : 'حفظ المسودة')
                                : 'حفظ التعديلات',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: const Color(0xFF1B5E20),
                          ),
                        ),
                      if (_canSubmit) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _saveThenWorkflow(
                                    (id) => _api.submitContInvoice(
                                      id: id,
                                      userId: widget.currentUser.id,
                                    ),
                                  ),
                          icon: const Icon(Icons.send),
                          label: const Text('إرسال لمراجعة السعر'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                      if (_canForward) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _saveThenWorkflow(
                                    (id) => _api.forwardContInvoice(
                                      id: id,
                                      userId: widget.currentUser.id,
                                    ),
                                  ),
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(
                            _status == contStatusPendingPrice
                                ? 'إرسال لمدير المشروعات'
                                : 'إرسال لاعتماد العمليات',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                      if (_canReturn) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _confirmReturn,
                          icon: const Icon(Icons.undo),
                          label: const Text('إرجاع لمدير المشروعات'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                      if (_canApprove) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () => _runWorkflow(
                                    () => _api.approveContInvoice(
                                      id: _effectiveInvoiceId!,
                                      userId: widget.currentUser.id,
                                    ),
                                  ),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('اعتماد نهائي'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: Colors.teal.shade700,
                          ),
                        ),
                      ],
                      if (_showCashLedger && _payments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'سجل الصرف',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ..._payments.map((p) {
                          final when = p.createdAt == null
                              ? '—'
                              : DateFormat('dd/MM/yyyy HH:mm')
                                  .format(p.createdAt!.toLocal());
                          final who = p.createdByUserName.trim();
                          final files = p.attachments.isNotEmpty
                              ? p.attachments
                              : (p.hasAttachment
                                  ? [
                                      ContInvoicePaymentAttachmentModel(
                                        fileName: p.fileName,
                                        mimeType: p.mimeType,
                                        sizeBytes: p.sizeBytes,
                                      ),
                                    ]
                                  : const <ContInvoicePaymentAttachmentModel>[]);
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                children: [
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.payments_outlined),
                                    title: Text(
                                      _moneyFmt.format(p.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (who.isNotEmpty) who,
                                        when,
                                        if (p.note.trim().isNotEmpty)
                                          p.note.trim(),
                                      ].join(' · '),
                                    ),
                                  ),
                                  ...files.map(
                                    (att) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.attach_file),
                                      title: Text(
                                        att.fileName.isEmpty
                                            ? 'مرفق صرف'
                                            : att.fileName,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Wrap(
                                        spacing: 0,
                                        children: [
                                          IconButton(
                                            tooltip: 'فتح',
                                            onPressed: () => _openPaymentVoucher(
                                              payment: p,
                                              attachment: att,
                                            ),
                                            icon: const Icon(Icons.visibility_outlined),
                                          ),
                                          IconButton(
                                            tooltip: 'تنزيل',
                                            onPressed: () =>
                                                _downloadPaymentVoucher(
                                              payment: p,
                                              attachment: att,
                                            ),
                                            icon: const Icon(Icons.download_outlined),
                                          ),
                                          IconButton(
                                            tooltip: 'طباعة',
                                            onPressed: () => _printPaymentVoucher(
                                              payment: p,
                                              attachment: att,
                                            ),
                                            icon: const Icon(Icons.print_outlined),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      if (_canRecordPayment) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: busy ? null : _confirmRecordPayment,
                          icon: const Icon(Icons.payments),
                          label: Text(
                            _paidAmount > 0
                                ? 'تسجيل دفعة صرف'
                                : 'تسجيل صرف',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: Colors.indigo,
                          ),
                        ),
                      ],
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
