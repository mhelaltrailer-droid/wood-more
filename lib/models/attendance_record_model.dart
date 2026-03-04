/// نموذج سجل الحضور والانصراف
class AttendanceRecordModel {
  final int id;
  final int userId;
  final String userName;
  final String type; // 'check_in' أو 'check_out'
  final DateTime dateTime;
  final String location;
  final int? projectId;
  final String? projectName;
  final String? notes;

  const AttendanceRecordModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.dateTime,
    required this.location,
    this.projectId,
    this.projectName,
    this.notes,
  });

  bool get isCheckIn => type == 'check_in';
  bool get isCheckOut => type == 'check_out';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'type': type,
      'date_time': dateTime.toIso8601String(),
      'location': location,
      'project_id': projectId,
      'project_name': projectName,
      'notes': notes,
    };
  }

  factory AttendanceRecordModel.fromMap(Map<String, dynamic> map) {
    return AttendanceRecordModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      userName: map['user_name'] as String,
      type: map['type'] as String,
      dateTime: DateTime.parse(map['date_time'] as String),
      location: map['location'] as String,
      projectId: map['project_id'] as int?,
      projectName: map['project_name'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
