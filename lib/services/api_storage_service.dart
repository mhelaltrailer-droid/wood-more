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
import '../models/work_phase_model.dart';
import '../models/detailed_report_model.dart';
import '../models/project_location_model.dart';
import '../models/location_material_model.dart';
import '../models/location_withdrawal_model.dart';
import '../models/location_withdrawal_for_period_model.dart';
import '../models/activity_log_model.dart';

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

  Future<bool> isSystemLocked() async {
    try {
      final data = await _get('system-lock');
      return data['locked'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setSystemLocked(bool locked) async {
    await _put('system-lock', {'locked': locked});
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
    final projects = list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ProjectModel.fromMap(m);
    }).toList();
    return _deduplicateProjectsByName(projects);
  }

  /// الحصول على جميع المشاريع كما هي من الخادم (يشمل الأسماء المكررة).
  Future<List<ProjectModel>> getProjectsRaw() async {
    final list = await _getList('projects');
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return ProjectModel.fromMap(m);
    }).toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      });
  }

  static List<ProjectModel> _deduplicateProjectsByName(List<ProjectModel> list) {
    final seen = <String>{};
    return list.where((p) => seen.add(p.name)).toList()..sort((a, b) => a.name.compareTo(b.name));
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

  // ——— هيكل مواقع المشروع (project_locations) ———
  Future<List<ProjectLocationModel>> getProjectLocations(int projectId) async {
    final list = await _getList('project-locations?projectId=$projectId');
    return list.map((e) => ProjectLocationModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addProjectLocation({required int projectId, int? parentId, required String name, required String type, int displayOrder = 0}) async {
    return _post('project-locations', {
      'projectId': projectId,
      'parentId': parentId,
      'name': name,
      'type': type,
      'display_order': displayOrder,
    });
  }

  Future<void> updateProjectLocation(int id, {String? name, int? displayOrder}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (displayOrder != null) body['display_order'] = displayOrder;
    if (body.isEmpty) return;
    await _put('project-locations/$id', body);
  }

  Future<void> deleteProjectLocation(int id) async {
    await _delete('project-locations/$id');
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

  Future<void> deleteAttendanceRecord(int id) async {
    await _delete('attendance/$id');
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
      'contractors_json': report.contractors.map((c) => c.toJson()).toList(),
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

  Future<void> deleteDailyReport(int id) async {
    await _delete('daily-reports/$id');
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

  Future<List<WorkPhaseModel>> getWorkPhases() async {
    final list = await _getList('work-phases');
    return list.map((e) => WorkPhaseModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addDetailedReport(DetailedReportModel report) async {
    final body = report.toJson();
    body['lines'] = report.lines.map((e) => e.toJson()).toList();
    return _post('detailed-reports', body);
  }

  Future<void> patchDetailedReportExpenses({
    required int reportId,
    required int userId,
    required List<ExpenseItem> expenses,
  }) async {
    await _put('detailed-reports/$reportId/expenses', {
      'userId': userId,
      'expenses': expenses.map((e) => e.toJson()).toList(),
    });
  }

  Future<List<DetailedReportModel>> getDetailedReports({
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
    final uri = Uri.parse(_path('detailed-reports')).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list.map((e) => DetailedReportModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// حذف تقرير مفصّل (صلاحية المسؤول المحدد في الواجهة فقط)
  Future<void> deleteDetailedReport(int id) async {
    await _delete('detailed-reports/$id');
  }

  // ——— هيكلة المخازن: خامات لكل موقع فرعي ———
  Future<List<LocationMaterialModel>> getLocationMaterials(int locationId) async {
    final list = await _getList('location-materials?locationId=$locationId');
    return list.map((e) => LocationMaterialModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<int> addLocationMaterial(LocationMaterialModel m) async {
    return _post('location-materials', {
      'locationId': m.locationId,
      'materialName': m.materialName,
      'quantity': m.quantity,
      'unit': m.unit,
    });
  }

  Future<void> updateLocationMaterial(LocationMaterialModel m) async {
    await _put('location-materials/${m.id}', {
      'materialName': m.materialName,
      'quantity': m.quantity,
      'unit': m.unit,
    });
  }

  Future<void> deleteLocationMaterial(int id) async {
    await _delete('location-materials/$id');
  }

  Future<int> addExecutedPlan({
    required DetailedReportModel plan,
    required int userId,
    required String userName,
    required DateTime planDate,
    required String status,
    int? sourcePlanId,
    String? modificationSummary,
    String? postponeReasonKey,
    String? postponeReasonLabel,
    String? postponeCustomReason,
    String? postponeNotes,
    DateTime? postponeReopenDate,
  }) async {
    return _post('executed-plans', {
      'sourcePlanId': sourcePlanId,
      'userId': userId,
      'userName': userName,
      'projectId': plan.projectId,
      'projectName': plan.projectName,
      'planDate': DateTime(planDate.year, planDate.month, planDate.day).toIso8601String(),
      'status': status,
      'modificationSummary': modificationSummary,
      'postponeReasonKey': postponeReasonKey,
      'postponeReasonLabel': postponeReasonLabel,
      'postponeCustomReason': postponeCustomReason,
      'postponeNotes': postponeNotes,
      'postponeReopenDate': postponeReopenDate != null
          ? DateTime(postponeReopenDate.year, postponeReopenDate.month, postponeReopenDate.day).toIso8601String()
          : null,
      'plan': plan.toJson(),
    });
  }

  Future<Map<String, dynamic>?> getLatestExecutedPlanStatus({
    required int sourcePlanId,
    required int userId,
  }) async {
    final uri = Uri.parse(_path('executed-plans/latest')).replace(queryParameters: {
      'sourcePlanId': sourcePlanId.toString(),
      'userId': userId.toString(),
    });
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return null;
    final decoded = jsonDecode(r.body);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<Map<String, dynamic>>> getPostponeReasons() async {
    final uri = Uri.parse(_path('postpone-reasons'));
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getPostponedReopenedPlans({
    required DateTime reopenDate,
    required int userId,
  }) async {
    final d = DateTime(reopenDate.year, reopenDate.month, reopenDate.day);
    final uri = Uri.parse(_path('executed-plans/postponed-reopens')).replace(queryParameters: {
      'reopenDate': d.toIso8601String(),
      'userId': userId.toString(),
    });
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getDailyPlanMovementSummary({
    required DateTime date,
    required String requesterEmail,
  }) async {
    final uri = Uri.parse(_path('executed-plans/daily-summary')).replace(queryParameters: {
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'requesterEmail': requesterEmail.trim().toLowerCase(),
    });
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<List<ActivityLogModel>> getActivityLogs({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String requesterEmail,
    int? userId,
    String? actionType,
  }) async {
    final params = <String, String>{
      'dateFrom': DateTime(dateFrom.year, dateFrom.month, dateFrom.day).toIso8601String(),
      'dateTo': DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999).toIso8601String(),
      'requesterEmail': requesterEmail.trim().toLowerCase(),
    };
    if (userId != null) params['userId'] = userId.toString();
    if (actionType != null && actionType.trim().isNotEmpty) params['actionType'] = actionType.trim();
    final uri = Uri.parse(_path('activity-logs')).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list.map((e) => ActivityLogModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<LocationWithdrawalModel?> getLocationWithdrawal(int locationId) async {
    final uri = Uri.parse(_path('location-withdrawal')).replace(queryParameters: {'locationId': locationId.toString()});
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null) return null;
    return LocationWithdrawalModel.fromMap(Map<String, dynamic>.from(decoded as Map));
  }

  Future<void> createLocationWithdrawal({
    required int locationId,
    required int userId,
    required String userName,
    String? disbursementPermitImagesJson,
    String? deliveryPermitImagesJson,
  }) async {
    final uri = Uri.parse(_path('location-withdrawal'));
    final body = {
      'locationId': locationId,
      'userId': userId,
      'userName': userName,
      if (disbursementPermitImagesJson != null) 'disbursementPermitImagesJson': disbursementPermitImagesJson,
      if (deliveryPermitImagesJson != null) 'deliveryPermitImagesJson': deliveryPermitImagesJson,
    };
    final r = await http.post(uri, body: jsonEncode(body), headers: {'Content-Type': 'application/json'});
    if (r.statusCode >= 400) {
      final err = r.body;
      if (err.contains('already_withdrawn')) throw Exception('تم سحب الخامات من هذا المكان مسبقاً');
      throw Exception(err);
    }
  }

  /// إلغاء سحب الخامات لموقع فرعي واسترجاع رصيد المخزن (مسؤول التطبيق).
  Future<void> deleteLocationWithdrawal(int locationId) async {
    final uri = Uri.parse(_path('location-withdrawal')).replace(queryParameters: {'locationId': locationId.toString()});
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  /// سحوبات خامات في الفترة (نفس تاريخ التقرير + مهندس + موقع فرعي للمطابقة في التقرير المجمع)
  Future<List<LocationWithdrawalForPeriodModel>> getLocationWithdrawalsForPeriod({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    final fromD = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toD = DateTime(dateTo.year, dateTo.month, dateTo.day);
    final params = <String, String>{
      'dateFrom': '${fromD.year.toString().padLeft(4, '0')}-${fromD.month.toString().padLeft(2, '0')}-${fromD.day.toString().padLeft(2, '0')}',
      'dateTo': '${toD.year.toString().padLeft(4, '0')}-${toD.month.toString().padLeft(2, '0')}-${toD.day.toString().padLeft(2, '0')}',
    };
    if (projectId != null) params['projectId'] = projectId.toString();
    final uri = Uri.parse(_path('location-withdrawals-for-period')).replace(queryParameters: params);
    final r = await http.get(uri);
    // خادم قديم بدون هذا المسار: نكمل التقرير المجمع مع عمود خامات = ---------
    if (r.statusCode == 404) return [];
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list.map((e) => LocationWithdrawalForPeriodModel.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

}
