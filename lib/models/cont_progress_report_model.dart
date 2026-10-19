double _cpNum(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '')) ?? fallback;
}

int? _cpInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

class ContProgressReportModel {
  final int? id;
  final int? projectId;
  final String projectName;
  final int? contractorId;
  final String contractorName;
  final int? structureLocationId;
  final String locationLabel;
  final String measureType;
  final String progressKind;
  final double progressValue;
  final String notes;
  final String status;
  final int? createdByUserId;
  final String createdByUserName;
  final DateTime? createdAt;

  const ContProgressReportModel({
    this.id,
    this.projectId,
    this.projectName = '',
    this.contractorId,
    this.contractorName = '',
    this.structureLocationId,
    this.locationLabel = '',
    this.measureType = '',
    this.progressKind = 'percent',
    this.progressValue = 0,
    this.notes = '',
    this.status = 'submitted',
    this.createdByUserId,
    this.createdByUserName = '',
    this.createdAt,
  });

  bool get isPercent => progressKind == 'percent';
  bool get isMeters => progressKind == 'meters';

  String get valueLabel {
    if (isMeters) {
      final v = progressValue == progressValue.roundToDouble()
          ? progressValue.toInt().toString()
          : progressValue.toString();
      return '$v م';
    }
    final v = progressValue == progressValue.roundToDouble()
        ? progressValue.toInt().toString()
        : progressValue.toString();
    return '$v %';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'project_id': projectId,
        'project_name': projectName,
        'contractor_id': contractorId,
        'contractor_name': contractorName,
        'structure_location_id': structureLocationId,
        'location_label': locationLabel,
        'measure_type': measureType,
        'progress_kind': progressKind,
        'progress_value': progressValue,
        'notes': notes,
      };

  factory ContProgressReportModel.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return ContProgressReportModel(
      id: _cpInt(m['id']),
      projectId: _cpInt(m['project_id'] ?? m['projectId']),
      projectName: (m['project_name'] ?? m['projectName'] ?? '').toString(),
      contractorId: _cpInt(m['contractor_id'] ?? m['contractorId']),
      contractorName:
          (m['contractor_name'] ?? m['contractorName'] ?? '').toString(),
      structureLocationId: _cpInt(
        m['structure_location_id'] ?? m['structureLocationId'],
      ),
      locationLabel:
          (m['location_label'] ?? m['locationLabel'] ?? '').toString(),
      measureType: (m['measure_type'] ?? m['measureType'] ?? '').toString(),
      progressKind:
          (m['progress_kind'] ?? m['progressKind'] ?? 'percent').toString(),
      progressValue: _cpNum(m['progress_value'] ?? m['progressValue']),
      notes: (m['notes'] ?? '').toString(),
      status: (m['status'] ?? 'submitted').toString(),
      createdByUserId: _cpInt(
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
