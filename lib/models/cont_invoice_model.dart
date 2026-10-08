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
  final String locationLabel;
  final String description;
  final String unit;
  final double prevQty;
  final double currentQty;
  final double unitPrice;
  final double percent;

  const ContInvoiceLineModel({
    this.id,
    this.sortOrder = 0,
    this.itemNo,
    this.locationLabel = '',
    this.description = '',
    this.unit = 'عدد',
    this.prevQty = 0,
    this.currentQty = 0,
    this.unitPrice = 0,
    this.percent = 100,
  });

  double get totalQty => prevQty + currentQty;

  double get lineTotal =>
      double.parse((totalQty * unitPrice * (percent / 100)).toStringAsFixed(2));

  ContInvoiceLineModel copyWith({
    int? id,
    int? sortOrder,
    int? itemNo,
    String? locationLabel,
    String? description,
    String? unit,
    double? prevQty,
    double? currentQty,
    double? unitPrice,
    double? percent,
  }) {
    return ContInvoiceLineModel(
      id: id ?? this.id,
      sortOrder: sortOrder ?? this.sortOrder,
      itemNo: itemNo ?? this.itemNo,
      locationLabel: locationLabel ?? this.locationLabel,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      prevQty: prevQty ?? this.prevQty,
      currentQty: currentQty ?? this.currentQty,
      unitPrice: unitPrice ?? this.unitPrice,
      percent: percent ?? this.percent,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'sort_order': sortOrder,
        'item_no': itemNo,
        'location_label': locationLabel,
        'description': description,
        'unit': unit,
        'prev_qty': prevQty,
        'current_qty': currentQty,
        'total_qty': totalQty,
        'unit_price': unitPrice,
        'percent': percent,
        'line_total': lineTotal,
      };

  factory ContInvoiceLineModel.fromMap(Map<String, dynamic> m) {
    return ContInvoiceLineModel(
      id: _ciInt(m['id']),
      sortOrder: _ciInt(m['sort_order'] ?? m['sortOrder']) ?? 0,
      itemNo: _ciInt(m['item_no'] ?? m['itemNo']),
      locationLabel:
          (m['location_label'] ?? m['locationLabel'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      unit: (m['unit'] ?? 'عدد').toString(),
      prevQty: _ciNum(m['prev_qty'] ?? m['prevQty']),
      currentQty: _ciNum(m['current_qty'] ?? m['currentQty']),
      unitPrice: _ciNum(m['unit_price'] ?? m['unitPrice']),
      percent: _ciNum(m['percent'], 100),
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
  final int? createdByUserId;
  final String createdByUserName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ContInvoiceLineModel> lines;

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
    this.createdByUserId,
    this.createdByUserName = '',
    this.createdAt,
    this.updatedAt,
    this.lines = const [],
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
    List<ContInvoiceLineModel>? lines,
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
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lines: lines ?? this.lines,
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
      amountDue: _ciNum(m['amount_due'] ?? m['amountDue']),
      notes: (m['notes'] ?? '').toString(),
      status: (m['status'] ?? 'draft').toString(),
      createdByUserId: _ciInt(m['created_by_user_id'] ?? m['createdByUserId']),
      createdByUserName:
          (m['created_by_user_name'] ?? m['createdByUserName'] ?? '')
              .toString(),
      createdAt: parseDate(m['created_at'] ?? m['createdAt']),
      updatedAt: parseDate(m['updated_at'] ?? m['updatedAt']),
      lines: lines,
    );
  }
}
