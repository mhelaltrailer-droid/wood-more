import '../core/cont_invoices_constants.dart';

double _ciNum(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '')) ?? fallback;
}

int? _ciInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

class ContInvoiceLineModel {
  final int? id;
  final int sortOrder;
  final int? itemNo;
  final String lineKind;
  final int? structureLocationId;
  final String locationLabel;
  final String description;
  final String unit;
  final double prevQty;
  final double currentQty;
  final double baseQty;
  final double unitPrice;
  final double prevPercent;
  final double percent;
  final String deductionKind;
  final int? counterpartyContractorId;
  final String counterpartyContractorName;

  const ContInvoiceLineModel({
    this.id,
    this.sortOrder = 0,
    this.itemNo,
    this.lineKind = 'execution',
    this.structureLocationId,
    this.locationLabel = '',
    this.description = '',
    this.unit = 'عدد',
    this.prevQty = 0,
    this.currentQty = 0,
    this.baseQty = 0,
    this.unitPrice = 0,
    this.prevPercent = 0,
    this.percent = 100,
    this.deductionKind = '',
    this.counterpartyContractorId,
    this.counterpartyContractorName = '',
  });

  bool get isExecution => lineKind == 'execution';

  double get totalQty =>
      baseQty > 0 ? baseQty : (prevQty + currentQty);

  double get baseAmount => totalQty * unitPrice;

  /// مستحق هذه الفاتورة لبند التنفيذ = فرق النسب × الأساس.
  double get executionDue {
    final delta = (percent - prevPercent).clamp(0, 1000);
    return double.parse((baseAmount * (delta / 100)).toStringAsFixed(2));
  }

  double get lineTotal {
    if (lineKind == 'execution') return executionDue;
    if (lineKind == 'deduction') {
      final amt = unitPrice.abs();
      return double.parse((-amt).toStringAsFixed(2));
    }
    // holiday | transport | note_on_other — عدد × قيمة إن وُجد عدد
    final qty = baseQty > 0 ? baseQty : 1;
    final amt = (qty * unitPrice).abs();
    return double.parse(amt.toStringAsFixed(2));
  }

  ContInvoiceLineModel copyWith({
    int? id,
    int? sortOrder,
    int? itemNo,
    String? lineKind,
    int? structureLocationId,
    String? locationLabel,
    String? description,
    String? unit,
    double? prevQty,
    double? currentQty,
    double? baseQty,
    double? unitPrice,
    double? prevPercent,
    double? percent,
    String? deductionKind,
    int? counterpartyContractorId,
    String? counterpartyContractorName,
  }) {
    return ContInvoiceLineModel(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      itemNo: itemNo ?? this.itemNo,
      lineKind: lineKind ?? this.lineKind,
      structureLocationId: structureLocationId ?? this.structureLocationId,
      locationLabel: locationLabel ?? this.locationLabel,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      prevQty: prevQty ?? this.prevQty,
      currentQty: currentQty ?? this.currentQty,
      baseQty: baseQty ?? this.baseQty,
      unitPrice: unitPrice ?? this.unitPrice,
      prevPercent: prevPercent ?? this.prevPercent,
      percent: percent ?? this.percent,
      deductionKind: deductionKind ?? this.deductionKind,
      counterpartyContractorId:
          counterpartyContractorId ?? this.counterpartyContractorId,
      counterpartyContractorName:
          counterpartyContractorName ?? this.counterpartyContractorName,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sort_order': sortOrder,
        'item_no': itemNo,
        'line_kind': lineKind,
        'structure_location_id': structureLocationId,
        'location_label': locationLabel,
        'description': description,
        'unit': unit,
        'prev_qty': prevQty,
        'current_qty': currentQty,
        'total_qty': totalQty,
        'base_qty': totalQty,
        'unit_price': unitPrice,
        'prev_percent': prevPercent,
        'percent': percent,
        'deduction_kind': deductionKind,
        'counterparty_contractor_id': counterpartyContractorId,
        'counterparty_contractor_name': counterpartyContractorName,
        'amount': lineTotal.abs(),
        'line_total': lineTotal,
      };

  factory ContInvoiceLineModel.fromMap(Map<String, dynamic> m) {
    final base = _ciNum(
      m['base_qty'] ?? m['baseQty'] ?? m['total_qty'] ?? m['totalQty'],
    );
    return ContInvoiceLineModel(
      id: _ciInt(m['id']),
      sortOrder: _ciInt(m['sort_order'] ?? m['sortOrder']) ?? 0,
      itemNo: _ciInt(m['item_no'] ?? m['itemNo']),
      lineKind: (m['line_kind'] ?? m['lineKind'] ?? 'execution').toString(),
      structureLocationId: _ciInt(
        m['structure_location_id'] ?? m['structureLocationId'],
      ),
      locationLabel:
          (m['location_label'] ?? m['locationLabel'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      unit: (m['unit'] ?? 'عدد').toString(),
      prevQty: _ciNum(m['prev_qty'] ?? m['prevQty']),
      currentQty: _ciNum(m['current_qty'] ?? m['currentQty']),
      baseQty: base,
      unitPrice: _ciNum(m['unit_price'] ?? m['unitPrice']),
      prevPercent: _ciNum(m['prev_percent'] ?? m['prevPercent'], 0),
      percent: _ciNum(m['percent'], 100),
      deductionKind: (m['deduction_kind'] ?? m['deductionKind'] ?? '').toString(),
      counterpartyContractorId: _ciInt(
        m['counterparty_contractor_id'] ?? m['counterpartyContractorId'],
      ),
      counterpartyContractorName: (m['counterparty_contractor_name'] ??
              m['counterpartyContractorName'] ??
              '')
          .toString(),
    );
  }
}

class ContInvoiceActionModel {
  final int? id;
  final int? invoiceId;
  final int? actorUserId;
  final String actorUserName;
  final String action;
  final String comment;
  final DateTime? createdAt;

  const ContInvoiceActionModel({
    this.id,
    this.invoiceId,
    this.actorUserId,
    this.actorUserName = '',
    this.action = '',
    this.comment = '',
    this.createdAt,
  });

  factory ContInvoiceActionModel.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return ContInvoiceActionModel(
      id: _ciInt(m['id']),
      invoiceId: _ciInt(m['invoice_id'] ?? m['invoiceId']),
      actorUserId: _ciInt(m['actor_user_id'] ?? m['actorUserId']),
      actorUserName:
          (m['actor_user_name'] ?? m['actorUserName'] ?? '').toString(),
      action: (m['action'] ?? '').toString(),
      comment: (m['comment'] ?? '').toString(),
      createdAt: parseDate(m['created_at'] ?? m['createdAt']),
    );
  }
}

class ContInvoicePaymentAttachmentModel {
  final int? id;
  final int? paymentId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  const ContInvoicePaymentAttachmentModel({
    this.id,
    this.paymentId,
    this.fileName = '',
    this.mimeType = '',
    this.sizeBytes = 0,
  });

  factory ContInvoicePaymentAttachmentModel.fromMap(Map<String, dynamic> m) {
    return ContInvoicePaymentAttachmentModel(
      id: _ciInt(m['id']),
      paymentId: _ciInt(m['payment_id'] ?? m['paymentId']),
      fileName: (m['file_name'] ?? m['fileName'] ?? '').toString(),
      mimeType: (m['mime_type'] ?? m['mimeType'] ?? '').toString(),
      sizeBytes: _ciInt(m['size_bytes'] ?? m['sizeBytes']) ?? 0,
    );
  }
}

class ContInvoicePaymentModel {
  final int? id;
  final int? invoiceId;
  final double amount;
  final String note;
  final bool hasAttachment;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final List<ContInvoicePaymentAttachmentModel> attachments;
  final int? createdByUserId;
  final String createdByUserName;
  final DateTime? createdAt;

  const ContInvoicePaymentModel({
    this.id,
    this.invoiceId,
    this.amount = 0,
    this.note = '',
    this.hasAttachment = false,
    this.fileName = '',
    this.mimeType = '',
    this.sizeBytes = 0,
    this.attachments = const [],
    this.createdByUserId,
    this.createdByUserName = '',
    this.createdAt,
  });

  factory ContInvoicePaymentModel.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final rawAtt = m['attachments'];
    final attachments = rawAtt is List
        ? rawAtt
            .map(
              (e) => ContInvoicePaymentAttachmentModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <ContInvoicePaymentAttachmentModel>[];
    final fileName = (m['file_name'] ?? m['fileName'] ?? '').toString();
    if (attachments.isEmpty && fileName.trim().isNotEmpty) {
      attachments.add(
        ContInvoicePaymentAttachmentModel(
          fileName: fileName,
          mimeType: (m['mime_type'] ?? m['mimeType'] ?? '').toString(),
          sizeBytes: _ciInt(m['size_bytes'] ?? m['sizeBytes']) ?? 0,
        ),
      );
    }
    final hasAtt = m['has_attachment'] == true ||
        m['hasAttachment'] == true ||
        attachments.isNotEmpty;
    return ContInvoicePaymentModel(
      id: _ciInt(m['id']),
      invoiceId: _ciInt(m['invoice_id'] ?? m['invoiceId']),
      amount: _ciNum(m['amount']),
      note: (m['note'] ?? m['comment'] ?? '').toString(),
      hasAttachment: hasAtt,
      fileName: attachments.isNotEmpty ? attachments.first.fileName : fileName,
      mimeType: attachments.isNotEmpty
          ? attachments.first.mimeType
          : (m['mime_type'] ?? m['mimeType'] ?? '').toString(),
      sizeBytes: attachments.isNotEmpty
          ? attachments.first.sizeBytes
          : (_ciInt(m['size_bytes'] ?? m['sizeBytes']) ?? 0),
      attachments: attachments,
      createdByUserId: _ciInt(
        m['created_by_user_id'] ?? m['createdByUserId'],
      ),
      createdByUserName: (m['created_by_user_name'] ??
              m['createdByUserName'] ??
              '')
          .toString(),
      createdAt: parseDate(m['created_at'] ?? m['createdAt']),
    );
  }
}

class ContInvoiceModel {
  final int? id;
  final int? contractorId;
  final String contractorName;
  final int? projectId;
  final String projectName;
  final DateTime? statementDate;
  final String contractType;
  final double previouslyPaid;
  final double otherDeductions;
  final double totalAmount;
  final double amountDue;
  final String notes;
  final String status;
  final String statusLabelAr;
  final String returnReason;
  final int? currentAssigneeUserId;
  final String currentAssigneeUserName;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final int? paidByUserId;
  final String paidByUserName;
  final double paidAmount;
  final double remainingAmount;
  final int? createdByUserId;
  final String createdByUserName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ContInvoiceLineModel> lines;
  final List<ContInvoiceActionModel> actions;
  final List<ContInvoicePaymentModel> payments;

  const ContInvoiceModel({
    this.id,
    this.contractorId,
    this.contractorName = '',
    this.projectId,
    this.projectName = '',
    this.statementDate,
    this.contractType = 'تركيب',
    this.previouslyPaid = 0,
    this.otherDeductions = 0,
    this.totalAmount = 0,
    this.amountDue = 0,
    this.notes = '',
    this.status = 'draft',
    this.statusLabelAr = '',
    this.returnReason = '',
    this.currentAssigneeUserId,
    this.currentAssigneeUserName = '',
    this.approvedAt,
    this.paidAt,
    this.paidByUserId,
    this.paidByUserName = '',
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.createdByUserId,
    this.createdByUserName = '',
    this.createdAt,
    this.updatedAt,
    this.lines = const [],
    this.actions = const [],
    this.payments = const [],
  });

  double get computedTotal => lines.fold<double>(
        0,
        (sum, line) => sum + line.lineTotal,
      );

  double get computedDue =>
      double.parse(
        (computedTotal - previouslyPaid - otherDeductions).toStringAsFixed(2),
      );

  ContInvoiceModel copyWith({
    int? id,
    int? contractorId,
    String? contractorName,
    int? projectId,
    String? projectName,
    DateTime? statementDate,
    String? contractType,
    double? previouslyPaid,
    double? otherDeductions,
    double? totalAmount,
    double? amountDue,
    String? notes,
    String? status,
    String? statusLabelAr,
    String? returnReason,
    int? currentAssigneeUserId,
    String? currentAssigneeUserName,
    DateTime? approvedAt,
    DateTime? paidAt,
    int? paidByUserId,
    String? paidByUserName,
    double? paidAmount,
    double? remainingAmount,
    List<ContInvoiceLineModel>? lines,
    List<ContInvoiceActionModel>? actions,
    List<ContInvoicePaymentModel>? payments,
  }) {
    return ContInvoiceModel(
      id: id ?? this.id,
      contractorId: contractorId ?? this.contractorId,
      contractorName: contractorName ?? this.contractorName,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      statementDate: statementDate ?? this.statementDate,
      contractType: contractType ?? this.contractType,
      previouslyPaid: previouslyPaid ?? this.previouslyPaid,
      otherDeductions: otherDeductions ?? this.otherDeductions,
      totalAmount: totalAmount ?? this.totalAmount,
      amountDue: amountDue ?? this.amountDue,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      statusLabelAr: statusLabelAr ?? this.statusLabelAr,
      returnReason: returnReason ?? this.returnReason,
      currentAssigneeUserId:
          currentAssigneeUserId ?? this.currentAssigneeUserId,
      currentAssigneeUserName:
          currentAssigneeUserName ?? this.currentAssigneeUserName,
      approvedAt: approvedAt ?? this.approvedAt,
      paidAt: paidAt ?? this.paidAt,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      paidByUserName: paidByUserName ?? this.paidByUserName,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lines: lines ?? this.lines,
      actions: actions ?? this.actions,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'contractor_id': contractorId,
        'contractor_name': contractorName,
        'project_id': projectId,
        'project_name': projectName,
        'statement_date': statementDate == null
            ? null
            : '${statementDate!.year.toString().padLeft(4, '0')}-'
                '${statementDate!.month.toString().padLeft(2, '0')}-'
                '${statementDate!.day.toString().padLeft(2, '0')}',
        'contract_type': contractType,
        'previously_paid': previouslyPaid,
        'other_deductions': otherDeductions,
        'total_amount': computedTotal,
        'amount_due': computedDue,
        'notes': notes,
        'status': status,
        'lines': lines.map((e) => e.toMap()).toList(),
      };

  factory ContInvoiceModel.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    final rawLines = m['lines'];
    final lines = rawLines is List
        ? rawLines
            .map(
              (e) => ContInvoiceLineModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <ContInvoiceLineModel>[];

    final rawActions = m['actions'];
    final actions = rawActions is List
        ? rawActions
            .map(
              (e) => ContInvoiceActionModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <ContInvoiceActionModel>[];

    final rawPayments = m['payments'];
    final payments = rawPayments is List
        ? rawPayments
            .map(
              (e) => ContInvoicePaymentModel.fromMap(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : <ContInvoicePaymentModel>[];

    final status = (m['status'] ?? 'draft').toString();
    final statusLabelRaw = m['status_label_ar'] ?? m['statusLabelAr'];
    final amountDue = _ciNum(m['amount_due'] ?? m['amountDue']);
    final paidAmount = _ciNum(m['paid_amount'] ?? m['paidAmount']);
    final remainingRaw = m['remaining_amount'] ?? m['remainingAmount'];
    final remainingAmount = remainingRaw == null
        ? double.parse((amountDue - paidAmount).toStringAsFixed(2))
        : _ciNum(remainingRaw);

    return ContInvoiceModel(
      id: _ciInt(m['id']),
      contractorId: _ciInt(m['contractor_id'] ?? m['contractorId']),
      contractorName:
          (m['contractor_name'] ?? m['contractorName'] ?? '').toString(),
      projectId: _ciInt(m['project_id'] ?? m['projectId']),
      projectName: (m['project_name'] ?? m['projectName'] ?? '').toString(),
      statementDate: parseDate(m['statement_date'] ?? m['statementDate']),
      contractType:
          (m['contract_type'] ?? m['contractType'] ?? 'تركيب').toString(),
      previouslyPaid: _ciNum(m['previously_paid'] ?? m['previouslyPaid']),
      otherDeductions: _ciNum(m['other_deductions'] ?? m['otherDeductions']),
      totalAmount: _ciNum(m['total_amount'] ?? m['totalAmount']),
      amountDue: amountDue,
      notes: (m['notes'] ?? '').toString(),
      status: status,
      statusLabelAr: statusLabelRaw != null &&
              statusLabelRaw.toString().isNotEmpty
          ? statusLabelRaw.toString()
          : contInvoiceStatusLabelAr(status),
      returnReason: (m['return_reason'] ?? m['returnReason'] ?? '').toString(),
      currentAssigneeUserId: _ciInt(
        m['current_assignee_user_id'] ?? m['currentAssigneeUserId'],
      ),
      currentAssigneeUserName: (m['current_assignee_user_name'] ??
              m['currentAssigneeUserName'] ??
              '')
          .toString(),
      approvedAt: parseDate(m['approved_at'] ?? m['approvedAt']),
      paidAt: parseDate(m['paid_at'] ?? m['paidAt']),
      paidByUserId: _ciInt(m['paid_by_user_id'] ?? m['paidByUserId']),
      paidByUserName:
          (m['paid_by_user_name'] ?? m['paidByUserName'] ?? '').toString(),
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      createdByUserId: _ciInt(m['created_by_user_id'] ?? m['createdByUserId']),
      createdByUserName:
          (m['created_by_user_name'] ?? m['createdByUserName'] ?? '')
              .toString(),
      createdAt: parseDate(m['created_at'] ?? m['createdAt']),
      updatedAt: parseDate(m['updated_at'] ?? m['updatedAt']),
      lines: lines,
      actions: actions,
      payments: payments,
    );
  }
}
