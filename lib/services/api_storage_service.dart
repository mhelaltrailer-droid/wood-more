import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/attendance_record_model.dart';
import '../models/daily_report_model.dart';
import '../models/zone_model.dart';
import '../models/building_model.dart';
import '../models/supervisor_model.dart';
import '../models/contractor_model.dart';
import '../models/project_stock_model.dart';
import '../models/project_stock_ledger_model.dart';
import '../models/unit_model.dart';
import '../models/building_material_model.dart';
import '../models/building_cutlist_model.dart';

/// Storage implementation that uses the REST API (PostgreSQL backend).
class ApiStorageService {
  final String baseUrl;

  ApiStorageService(this.baseUrl);

  String _path(String segment) => baseUrl.endsWith('/') ? '$baseUrl$segment' : '$baseUrl/$segment';

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse(_path(path));
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    return r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getList(String path) async {
    final uri = Uri.parse(_path(path));
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null) return [];
    return decoded is List ? decoded as List<dynamic> : [];
  }

  Future<int> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_path(path));
    final r = await http.post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return 0;
    final decoded = jsonDecode(r.body);
    return decoded is int ? decoded : int.tryParse(decoded.toString()) ?? 0;
  }

  Future<void> _postVoid(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_path(path));
    final r = await http.post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<void> _put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_path(path));
    final r = await http.put(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<void> _delete(String path) async {
    final uri = Uri.parse(_path(path));
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final uri = Uri.parse(_path('users/by-email')).replace(queryParameters: {'email': email});
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null) return null;
    final m = decoded as Map<String, dynamic>;
    return UserModel.fromMap(m);
  }

  /// التحقق من تسجيل الدخول (بريد + كلمة سر) عبر API
  Future<UserModel?> validateLogin(String email, String password) async {
    try {
      final uri = Uri.parse(_path('auth/login'));
      final r = await http.post(
        uri,
        body: jsonEncode({'email': email.trim(), 'password': password}),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode != 200) return null;
      if (r.body.isEmpty) return null;
      final decoded = jsonDecode(r.body);
      if (decoded == null || decoded is! Map<String, dynamic>) return null;
      return UserModel.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<List<UserModel>> getSiteEngineers() async {
    final list = await _getList('users/site-engineers');
    return list.map((e) => UserModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<UserModel>> getUsers() async {
    final list = await _getList('users');
    return list.map((e) => UserModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addUser(String name, String email, String password, String role) async {
    final body = <String, dynamic>{'name': name, 'email': email, 'role': role};
    if (password.trim().isNotEmpty) body['password'] = password.trim();
    return _post('users', body);
  }

  Future<void> updateUser(int id, String name, String email, String role, [String? password]) async {
    final body = <String, dynamic>{'name': name, 'email': email, 'role': role};
    if (password != null && password.trim().isNotEmpty) body['password'] = password.trim();
    await _put('users/$id', body);
  }

  Future<void> deleteUser(int id) async {
    await _delete('users/$id');
  }

  Future<List<ProjectModel>> getProjects() async {
    final list = await _getList('projects');
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ProjectModel.fromMap(m);
    }).toList();
  }

  Future<int> addProject(String name) async {
    return _post('projects', {'name': name});
  }

  Future<void> updateProject(int id, String name) async {
    await _put('projects/$id', {'name': name});
  }

  Future<void> deleteProject(int id) async {
    await _delete('projects/$id');
  }

  Future<List<ZoneModel>> getZones(int projectId) async {
    final list = await _getList('zones?projectId=$projectId');
    return list.map((e) => ZoneModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addZone(int projectId, String name) async {
    return _post('zones', {'projectId': projectId, 'name': name});
  }

  Future<void> updateZone(int id, String name) async {
    await _put('zones/$id', {'name': name});
  }

  Future<void> deleteZone(int id) async {
    await _delete('zones/$id');
  }

  Future<List<BuildingModel>> getBuildings(int zoneId) async {
    final list = await _getList('buildings?zoneId=$zoneId');
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return BuildingModel.fromMap(m);
    }).toList();
  }

  Future<int> addBuilding(BuildingModel b) async {
    return _post('buildings', {'zoneId': b.zoneId, 'name': b.name, 'storageInfo': b.storageInfo, 'modelDetails': b.modelDetails, 'cutList': b.cutList});
  }

  Future<void> updateBuilding(BuildingModel b) async {
    await _put('buildings/${b.id}', {'name': b.name, 'storageInfo': b.storageInfo, 'modelDetails': b.modelDetails, 'cutList': b.cutList});
  }

  Future<void> deleteBuilding(int id) async {
    await _delete('buildings/$id');
  }

  Future<int> addAttendanceRecord(AttendanceRecordModel record) async {
    return _post('attendance', {
      'userId': record.userId,
      'userName': record.userName,
      'type': record.type,
      'dateTime': record.dateTime.toIso8601String(),
      'location': record.location,
      'projectId': record.projectId,
      'projectName': record.projectName,
      'notes': record.notes,
    });
  }

  Future<List<AttendanceRecordModel>> getAllAttendanceRecords() async {
    final list = await _getList('attendance');
    return list.map((e) => AttendanceRecordModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecordsByUser(int userId) async {
    final list = await _getList('attendance/by-user/$userId');
    return list.map((e) => AttendanceRecordModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// موعد الحضور والانصراف لمستخدم في تاريخ معين (نفس اليوم فقط)
  Future<({DateTime? checkIn, DateTime? checkOut})> getAttendanceForUserOnDate(int userId, DateTime date) async {
    final list = await getAttendanceRecordsByUser(userId);
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    DateTime? checkIn;
    DateTime? checkOut;
    for (final r in list) {
      if (r.dateTime.isBefore(dayStart) || r.dateTime.isAfter(dayEnd)) continue;
      if (r.isCheckIn && (checkIn == null || r.dateTime.isBefore(checkIn))) checkIn = r.dateTime;
      if (r.isCheckOut && (checkOut == null || r.dateTime.isAfter(checkOut))) checkOut = r.dateTime;
    }
    return (checkIn: checkIn, checkOut: checkOut);
  }

  Future<List<String>> getMaterials() async {
    final list = await _getList('materials');
    return list.map((e) => e as String).toList();
  }

  Future<List<Map<String, dynamic>>> getMaterialsWithIds() async {
    final list = await _getList('materials/with-ids');
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<int> addMaterial(String name) async {
    return _post('materials', {'name': name});
  }

  Future<void> updateMaterial(int id, String name) async {
    await _put('materials/$id', {'name': name});
  }

  Future<void> deleteMaterial(int id) async {
    await _delete('materials/$id');
  }

  Future<int> addDailyReport(DailyReportData report) async {
    final body = {
      'userId': report.userId,
      'userName': report.userName,
      'projectId': report.projectId,
      'projectName': report.projectName,
      'reportDate': report.reportDate.toIso8601String(),
      'workPlace': report.workPlace,
      'workReport': report.workReport,
      'executedToday': report.executedToday,
      'supervisorName': report.supervisorName,
      'contractorName': report.contractorName,
      'workersCount': report.workersCount,
      'tomorrowPlan': report.tomorrowPlan,
      'documentPath': report.documentPath,
      'imagePaths': report.imagePaths,
      'notes': report.notes,
      'materials': report.materials.map((m) => m.toJson()).toList(),
      'expenses': report.expenses.map((e) => e.toJson()).toList(),
    };
    final uri = Uri.parse(_path('daily-reports'));
    final r = await http.post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    return decoded is int ? decoded : int.tryParse(decoded.toString()) ?? 0;
  }

  Future<List<DailyReportData>> getDailyReports({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? userId,
    int? projectId,
  }) async {
    final params = <String, String>{
      'dateFrom': DateTime(dateFrom.year, dateFrom.month, dateFrom.day).toIso8601String(),
      'dateTo': DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999).toIso8601String(),
    };
    if (userId != null) params['userId'] = userId.toString();
    if (projectId != null) params['projectId'] = projectId.toString();
    final uri = Uri.parse(_path('daily-reports')).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return DailyReportData.fromDbMap(m);
    }).toList();
  }

  Future<double> getEngineerBalance(int userId) async {
    final uri = Uri.parse(_path('engineer-balance/$userId'));
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    return (decoded is num) ? decoded.toDouble() : double.tryParse(decoded.toString()) ?? 0;
  }

  Future<void> setEngineerBalance(int userId, double balance) async {
    await _postVoid('engineer-balance', {'userId': userId, 'balance': balance});
  }

  Future<void> addCustody(int userId, double amount, String note) async {
    await _postVoid('custody', {'userId': userId, 'amount': amount, 'note': note});
  }

  /// تسجيل حركة إضافة رصيد أو سحب رصيد فقط (الخادم قد يدعم balance-movement)
  Future<void> addBalanceMovement(int userId, double amount, String note, String movementType) async {
    try {
      await _postVoid('balance-movement', {'userId': userId, 'amount': amount, 'note': note, 'movementType': movementType});
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCustodyRecords({int? userId}) async {
    final path = userId != null ? 'custody?userId=$userId' : 'custody';
    final list = await _getList(path);
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      if (!m.containsKey('movement_type') && m.containsKey('movementType')) m['movement_type'] = m['movementType'];
      m['movement_type'] ??= 'custody';
      return m;
    }).toList();
  }

  Future<List<SupervisorModel>> getSupervisors() async {
    final list = await _getList('supervisors');
    return list.map((e) => SupervisorModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addSupervisor(String name) async {
    return _post('supervisors', {'name': name});
  }

  Future<void> updateSupervisor(int id, String name) async {
    await _put('supervisors/$id', {'name': name});
  }

  Future<void> deleteSupervisor(int id) async {
    await _delete('supervisors/$id');
  }

  Future<List<ContractorModel>> getContractors() async {
    final list = await _getList('contractors');
    return list.map((e) => ContractorModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addContractor(String name) async {
    return _post('contractors', {'name': name});
  }

  Future<void> updateContractor(int id, String name) async {
    await _put('contractors/$id', {'name': name});
  }

  Future<void> deleteContractor(int id) async {
    await _delete('contractors/$id');
  }

  Future<List<ProjectStockModel>> getProjectStock(int projectId) async {
    final list = await _getList('project-stock?projectId=$projectId');
    return list.map((e) => ProjectStockModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addProjectStock(ProjectStockModel s) async {
    return _post('project-stock', {'projectId': s.projectId, 'materialName': s.materialName, 'quantity': s.quantity, 'unit': s.unit});
  }

  Future<void> updateProjectStock(ProjectStockModel s) async {
    await _put('project-stock/${s.id}', {'materialName': s.materialName, 'quantity': s.quantity, 'unit': s.unit});
  }

  Future<void> deleteProjectStock(int id) async {
    await _delete('project-stock/$id');
  }

  Future<void> addProjectStockLedgerEntry({
    required int projectId,
    required String materialName,
    required String unit,
    required double quantityDelta,
    required String type,
    required String userName,
    DateTime? createdAt,
    int? userId,
  }) async {
    final body = <String, dynamic>{
      'projectId': projectId,
      'materialName': materialName,
      'unit': unit,
      'quantityDelta': quantityDelta,
      'type': type,
      'userName': userName,
    };
    if (userId != null) body['userId'] = userId;
    if (createdAt != null) body['createdAt'] = createdAt.toIso8601String();
    await _postVoid('project-stock-ledger', body);
  }

  Future<List<ProjectStockLedgerModel>> getStockLedger(int projectId, String materialName) async {
    final list = await _getList('project-stock-ledger?projectId=$projectId&materialName=${Uri.encodeComponent(materialName)}');
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      if (!m.containsKey('project_id') && m.containsKey('projectId')) m['project_id'] = m['projectId'];
      if (!m.containsKey('material_name') && m.containsKey('materialName')) m['material_name'] = m['materialName'];
      if (!m.containsKey('quantity_delta') && m.containsKey('quantityDelta')) m['quantity_delta'] = m['quantityDelta'];
      if (!m.containsKey('created_at') && m.containsKey('createdAt')) m['created_at'] = m['createdAt'];
      if (!m.containsKey('user_id') && m.containsKey('userId')) m['user_id'] = m['userId'];
      if (!m.containsKey('user_name') && m.containsKey('userName')) m['user_name'] = m['userName'];
      return ProjectStockLedgerModel.fromMap(m);
    }).toList();
  }

  Future<List<UnitModel>> getUnits(int buildingId) async {
    final list = await _getList('units?buildingId=$buildingId');
    return list.map((e) => UnitModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addUnit(UnitModel u) async {
    return _post('units', {'buildingId': u.buildingId, 'name': u.name, 'model': u.model, 'imagePath': u.imagePath});
  }

  Future<void> updateUnit(UnitModel u) async {
    await _put('units/${u.id}', {'name': u.name, 'model': u.model, 'imagePath': u.imagePath});
  }

  Future<void> deleteUnit(int id) async {
    await _delete('units/$id');
  }

  Future<List<BuildingMaterialModel>> getBuildingMaterials(int buildingId) async {
    final list = await _getList('building-materials?buildingId=$buildingId');
    return list.map((e) => BuildingMaterialModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addBuildingMaterial(BuildingMaterialModel m) async {
    return _post('building-materials', {
      'buildingId': m.buildingId,
      'materialName': m.materialName,
      'quantity': '',
      'unit': '',
      'length': m.length,
      'piecesCount': m.piecesCount,
      'totalLength': m.totalLength,
      'totalArea': m.totalArea,
      'imagePath': m.imagePath,
    });
  }

  Future<void> updateBuildingMaterial(BuildingMaterialModel m) async {
    await _put('building-materials/${m.id}', {
      'materialName': m.materialName,
      'length': m.length,
      'piecesCount': m.piecesCount,
      'totalLength': m.totalLength,
      'totalArea': m.totalArea,
      'imagePath': m.imagePath,
    });
  }

  Future<void> deleteBuildingMaterial(int id) async {
    await _delete('building-materials/$id');
  }

  Future<List<BuildingCutlistModel>> getBuildingCutlists(int buildingId) async {
    final list = await _getList('building-cutlists?buildingId=$buildingId');
    return list.map((e) => BuildingCutlistModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addBuildingCutlist(BuildingCutlistModel c) async {
    return _post('building-cutlists', {'buildingId': c.buildingId, 'imagePath': c.imagePath});
  }

  Future<void> deleteBuildingCutlist(int id) async {
    await _delete('building-cutlists/$id');
  }
}
