import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/project_model.dart';
import '../models/attendance_record_model.dart';
import '../models/daily_report_model.dart';
import '../models/zone_model.dart';
import '../models/building_model.dart';
import '../models/supervisor_model.dart';
import '../models/contractor_model.dart';
import '../models/project_stock_model.dart';
import '../models/unit_model.dart';
import '../models/building_material_model.dart';
import '../models/building_cutlist_model.dart';
import '../data/default_materials.dart';

/// تخزين للويب باستخدام SharedPreferences
class WebStorageService {
  static const _usersKey = 'wood_users';
  static const _projectsKey = 'wood_projects_v2';
  static const _attendanceKey = 'wood_attendance';
  static const _materialsKey = 'wood_materials_v3';
  static const _dailyReportsKey = 'wood_daily_reports';
  static const _zonesKey = 'wood_zones';
  static const _buildingsKey = 'wood_buildings';
  static const _supervisorsKey = 'wood_supervisors';
  static const _contractorsKey = 'wood_contractors';
  static const _projectStockKey = 'wood_project_stock';
  static const _unitsKey = 'wood_units';
  static const _buildingMaterialsKey = 'wood_building_materials';
  static const _buildingCutlistKey = 'wood_building_cutlist';
  static const _engineerBalanceKey = 'wood_engineer_balance';
  static const _engineerCustodyKey = 'wood_engineer_custody';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<void> _initData() async {
    final prefs = await _prefs;
    if (prefs.getString(_usersKey) == null) {
      final users = [
        {'id': 1, 'name': 'Hany', 'email': 'hany.samir1708@gmail.com', 'role': 'site_engineer'},
        {'id': 2, 'name': 'Emam', 'email': 'amirelazab46@gmail.com', 'role': 'site_engineer'},
        {'id': 3, 'name': 'Mansur', 'email': 'saedm0566@gmail.com', 'role': 'site_engineer'},
        {'id': 4, 'name': 'Mahmud', 'email': 'mahmoudsiko630@gmail.com', 'role': 'site_engineer'},
        {'id': 5, 'name': 'Abdhusseny', 'email': 'abdallaelhosseny1011@gmail.com', 'role': 'site_engineer'},
        {'id': 6, 'name': 'Hamza', 'email': 'hamzamhamad704@gmail.com', 'role': 'site_engineer'},
        {'id': 7, 'name': 'Gohary', 'email': 'mohamedelgohary371@gmail.com', 'role': 'site_engineer'},
        {'id': 8, 'name': 'Amr', 'email': 'amrelshabrawy55@gmail.com', 'role': 'site_engineer'},
        {'id': 9, 'name': 'Hassan', 'email': 'mouhammed.helal@gmail.com', 'role': 'site_engineer'},
        {'id': 10, 'name': 'Helal', 'email': 'mouhamedhelal.cor@gmail.com', 'role': 'site_engineer_manager'},
        {'id': 11, 'name': 'Shams', 'email': 'islam.shams2050@gmail.com', 'role': 'site_engineer_manager'},
        {'id': 12, 'name': 'Abdrhman', 'email': 'AbdelrhmanEllaithy828@gmail.com', 'role': 'site_engineer_manager'},
        {'id': 13, 'name': 'مسؤول التطبيق', 'email': 'mouhammedhelal@gmail.com', 'role': 'app_admin'},
      ];
      await prefs.setString(_usersKey, jsonEncode(users));
    } else {
      final list = jsonDecode(prefs.getString(_usersKey)!) as List;
      final hasAdmin = list.any((e) => ((e as Map)['email'] as String).toLowerCase() == 'mouhammedhelal@gmail.com');
      if (!hasAdmin) {
        final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
        list.add({'id': nextId, 'name': 'مسؤول التطبيق', 'email': 'mouhammedhelal@gmail.com', 'role': 'app_admin'});
        await prefs.setString(_usersKey, jsonEncode(list));
      }
    }
    if (prefs.getString(_projectsKey) == null) {
      final projectNames = [
        'UTC_Z5_CRC_F', 'Mivida 31_CRC_F', 'UTC_Z5_EMAAR Building C_F', 'Zed east_ORASCOM_F',
        'Belle Vie_El-Hazek_F', 'CAIRO GATE elain (02)_CRC_F', 'Cairo gate_ACC_W', 'Z1_EMAAR_F',
        'Community Center_CRC_W', 'Terrace Zayed_CRC_W', 'Silver Sands_REDCON_D', 'CAR SHADE_W&M_W',
        'OLD CITY_ORASCOM_W', 'Cairo gate-Eden_ATRUM_F', 'AUC Campus Expansion_Orascom_W&F',
        'UTC - 2 Villa- Link International_W', 'UTC - 2 Villa- Link International_F', 'City Gate_CCC_W',
        'cairo gate - locanda_INOVOO_F', 'Village West _ club_FIT-OUT_W', 'Village West _Villa_W',
        'Mivida gardens_Atrium_F', 'Village West_CRC_ F', 'Up Town Cairo _Z5 _EMAAR_W', 'Belle Vie _ EMAAR_W',
        'Village West _ CRC_ W', 'Wood&More(head office)',
      ];
      final projects = projectNames.asMap().entries.map((e) => {'id': e.key + 1, 'name': e.value}).toList();
      await prefs.setString(_projectsKey, jsonEncode(projects));
    }
    if (prefs.getString(_attendanceKey) == null) {
      await prefs.setString(_attendanceKey, jsonEncode([]));
    }
    if (prefs.getString(_materialsKey) == null) {
      final materialsList = defaultMaterialsList.asMap().entries.map((e) => {'id': e.key + 1, 'name': e.value}).toList();
      await prefs.setString(_materialsKey, jsonEncode(materialsList));
    }
    if (prefs.getString(_dailyReportsKey) == null) {
      await prefs.setString(_dailyReportsKey, jsonEncode([]));
    }
    if (prefs.getString(_zonesKey) == null) await prefs.setString(_zonesKey, jsonEncode([]));
    if (prefs.getString(_buildingsKey) == null) await prefs.setString(_buildingsKey, jsonEncode([]));
    if (prefs.getString(_supervisorsKey) == null) await prefs.setString(_supervisorsKey, jsonEncode([]));
    if (prefs.getString(_contractorsKey) == null) await prefs.setString(_contractorsKey, jsonEncode([]));
    if (prefs.getString(_projectStockKey) == null) await prefs.setString(_projectStockKey, jsonEncode([]));
    if (prefs.getString(_unitsKey) == null) await prefs.setString(_unitsKey, jsonEncode([]));
    if (prefs.getString(_buildingMaterialsKey) == null) await prefs.setString(_buildingMaterialsKey, jsonEncode([]));
    if (prefs.getString(_buildingCutlistKey) == null) await prefs.setString(_buildingCutlistKey, jsonEncode([]));
    if (prefs.getString(_engineerBalanceKey) == null) await prefs.setString(_engineerBalanceKey, jsonEncode([]));
    if (prefs.getString(_engineerCustodyKey) == null) await prefs.setString(_engineerCustodyKey, jsonEncode([]));
  }

  Future<List<String>> getMaterials() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    if (list.isNotEmpty && list[0] is! Map) return list.map((e) => e as String).toList()..sort();
    return list.map((e) => (e as Map)['name'] as String).toList()..sort();
  }

  Future<List<Map<String, dynamic>>> getMaterialsWithIds() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    if (list.isEmpty) return [];
    if (list[0] is Map) return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return (list as List).asMap().entries.map((e) => {'id': e.key + 1, 'name': e.value as String}).toList();
  }

  /// حد أقصى لعدد التقارير المخزنة على الويب لتجنب QuotaExceededError
  static const int _maxStoredReports = 50;
  static const int _maxStoredBytes = 3 * 1024 * 1024; // 3 MB

  Future<void> addDailyReport(DailyReportData report) async {
    await _initData();
    final prefs = await _prefs;
    List list = jsonDecode(prefs.getString(_dailyReportsKey)!) as List;
    final map = report.toJson();
    map['id'] = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    map['created_at'] = DateTime.now().toIso8601String();
    list.insert(0, map);

    // الاحتفاظ بآخر _maxStoredReports تقرير فقط
    if (list.length > _maxStoredReports) {
      list = list.sublist(0, _maxStoredReports);
    }

    // تقليص المرفقات إذا كان حجم التقرير الجديد كبيراً جداً لتجنب تجاوز حد التخزين
    String encoded = jsonEncode(list);
    if (encoded.length > _maxStoredBytes) {
      map['document_path'] = null;
      map['image_paths'] = [];
      if (list.isNotEmpty) list[0] = map;
      encoded = jsonEncode(list);
    }

    try {
      await prefs.setString(_dailyReportsKey, encoded);
    } catch (e) {
      if (e.toString().contains('QuotaExceeded') || e.toString().contains('quota')) {
        // محاولة ثانية: تقليص عدد التقارير وإزالة مرفقات التقرير الجديد
        list = list.sublist(0, list.length > 20 ? 20 : list.length);
        if (list.isNotEmpty) {
          (list[0] as Map)['document_path'] = null;
          (list[0] as Map)['image_paths'] = [];
        }
        await prefs.setString(_dailyReportsKey, jsonEncode(list));
      } else {
        rethrow;
      }
    }

    // خصم إجمالي بنود الماليات من رصيد المهندس
    double total = 0;
    for (final e in report.expenses) {
      total += double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    if (total > 0) {
      final current = await getEngineerBalance(report.userId);
      await setEngineerBalance(report.userId, current - total);
    }
  }

  Future<double> getEngineerBalance(int userId) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_engineerBalanceKey)!) as List;
    for (final e in list) {
      final m = e as Map;
      if (m['user_id'] == userId) return (m['balance'] as num).toDouble();
    }
    return 0;
  }

  Future<void> setEngineerBalance(int userId, double balance) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_engineerBalanceKey)!) as List;
    final newList = list.where((e) => (e as Map)['user_id'] != userId).toList();
    newList.add({'user_id': userId, 'balance': balance});
    await prefs.setString(_engineerBalanceKey, jsonEncode(newList));
  }

  Future<void> addCustody(int userId, double amount, String note) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_engineerCustodyKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'user_id': userId, 'amount': amount, 'created_at': DateTime.now().toIso8601String(), 'note': note});
    await prefs.setString(_engineerCustodyKey, jsonEncode(list));
    final current = await getEngineerBalance(userId);
    await setEngineerBalance(userId, current + amount);
  }

  Future<List<Map<String, dynamic>>> getCustodyRecords({int? userId}) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_engineerCustodyKey)!) as List;
    var result = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (userId != null) result = result.where((e) => e['user_id'] == userId).toList();
    result.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return result.map((e) => {'id': e['id'], 'user_id': e['user_id'], 'amount': (e['amount'] as num).toDouble(), 'created_at': e['created_at'], 'note': e['note']}).toList();
  }

  Future<List<UserModel>> getSiteEngineers() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    final users = list
        .map((m) => UserModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .where((u) => u.role == 'site_engineer')
        .toList();
    users.sort((a, b) => a.name.compareTo(b.name));
    return users;
  }

  Future<UserModel?> getUserByEmail(String email) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    final emailLower = email.trim().toLowerCase();
    for (final m in list) {
      if ((m['email'] as String).toLowerCase() == emailLower) {
        return UserModel.fromMap(Map<String, dynamic>.from(m as Map));
      }
    }
    return null;
  }

  Future<List<ProjectModel>> getProjects() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectsKey)!) as List;
    return list.map((m) => ProjectModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> addAttendanceRecord(AttendanceRecordModel record) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_attendanceKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    final map = {
      'id': nextId,
      'user_id': record.userId,
      'user_name': record.userName,
      'type': record.type,
      'date_time': record.dateTime.toIso8601String(),
      'location': record.location,
      'project_id': record.projectId,
      'project_name': record.projectName,
      'notes': record.notes,
    };
    list.insert(0, map);
    await prefs.setString(_attendanceKey, jsonEncode(list));
  }

  Future<List<AttendanceRecordModel>> getAllAttendanceRecords() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_attendanceKey)!) as List;
    return list.map((m) => AttendanceRecordModel.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecordsByUser(int userId) async {
    final all = await getAllAttendanceRecords();
    final list = all.where((r) => r.userId == userId).toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // الأحدث أولاً
    return list;
  }

  Future<List<DailyReportData>> getDailyReports({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? userId,
    int? projectId,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_dailyReportsKey)!) as List;
    final fromDate = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toEnd = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999);
    final reports = <DailyReportData>[];
    for (final m in list) {
      final map = Map<String, dynamic>.from(m as Map);
      final report = DailyReportData.fromJson(map);
      final dt = report.reportDate;
      if (dt.isBefore(fromDate) || dt.isAfter(toEnd)) continue;
      if (userId != null && report.userId != userId) continue;
      if (projectId != null && report.projectId != projectId) continue;
      reports.add(report);
    }
    reports.sort((a, b) => b.reportDate.compareTo(a.reportDate));
    return reports;
  }

  // ——— لوح التحكم ———
  Future<List<UserModel>> getUsers() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    return list.map((m) => UserModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addUser(String name, String email, String role) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'name': name, 'email': email.trim().toLowerCase(), 'role': role});
    await prefs.setString(_usersKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateUser(int id, String name, String email, String role) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == id) {
        list[i] = {'id': id, 'name': name, 'email': email.trim().toLowerCase(), 'role': role};
        break;
      }
    }
    await prefs.setString(_usersKey, jsonEncode(list));
  }

  Future<void> deleteUser(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_usersKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_usersKey, jsonEncode(list));
  }

  Future<int> addProject(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectsKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'name': name});
    list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    await prefs.setString(_projectsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateProject(int id, String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == id) {
        list[i] = {'id': id, 'name': name};
        break;
      }
    }
    list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    await prefs.setString(_projectsKey, jsonEncode(list));
  }

  Future<void> deleteProject(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_projectsKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    final zones = (jsonDecode(prefs.getString(_zonesKey)!) as List).where((e) => (e as Map)['project_id'] != id).toList();
    final stock = (jsonDecode(prefs.getString(_projectStockKey)!) as List).where((e) => (e as Map)['project_id'] != id).toList();
    await prefs.setString(_projectsKey, jsonEncode(list));
    await prefs.setString(_zonesKey, jsonEncode(zones));
    await prefs.setString(_projectStockKey, jsonEncode(stock));
  }

  Future<List<ZoneModel>> getZones(int projectId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_zonesKey)!) as List).where((e) => (e as Map)['project_id'] == projectId).toList();
    return list.map((m) => ZoneModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addZone(int projectId, String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_zonesKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'project_id': projectId, 'name': name});
    await prefs.setString(_zonesKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateZone(int id, String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_zonesKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == id) {
        list[i] = {'id': id, 'project_id': (list[i] as Map)['project_id'], 'name': name};
        break;
      }
    }
    await prefs.setString(_zonesKey, jsonEncode(list));
  }

  Future<void> deleteZone(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_zonesKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    final buildings = (jsonDecode(prefs.getString(_buildingsKey)!) as List).where((e) => (e as Map)['zone_id'] != id).toList();
    await prefs.setString(_zonesKey, jsonEncode(list));
    await prefs.setString(_buildingsKey, jsonEncode(buildings));
  }

  Future<List<BuildingModel>> getBuildings(int zoneId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingsKey)!) as List).where((e) => (e as Map)['zone_id'] == zoneId).toList();
    return list.map((m) => BuildingModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addBuilding(BuildingModel b) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingsKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'zone_id': b.zoneId, 'name': b.name, 'storage_info': b.storageInfo, 'model_details': b.modelDetails, 'cut_list': b.cutList});
    await prefs.setString(_buildingsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateBuilding(BuildingModel b) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == b.id) {
        list[i] = {'id': b.id, 'zone_id': b.zoneId, 'name': b.name, 'storage_info': b.storageInfo, 'model_details': b.modelDetails, 'cut_list': b.cutList};
        break;
      }
    }
    await prefs.setString(_buildingsKey, jsonEncode(list));
  }

  Future<void> deleteBuilding(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingsKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    final units = (jsonDecode(prefs.getString(_unitsKey)!) as List).where((e) => (e as Map)['building_id'] != id).toList();
    final bm = (jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List).where((e) => (e as Map)['building_id'] != id).toList();
    final bc = (jsonDecode(prefs.getString(_buildingCutlistKey)!) as List).where((e) => (e as Map)['building_id'] != id).toList();
    await prefs.setString(_buildingsKey, jsonEncode(list));
    await prefs.setString(_unitsKey, jsonEncode(units));
    await prefs.setString(_buildingMaterialsKey, jsonEncode(bm));
    await prefs.setString(_buildingCutlistKey, jsonEncode(bc));
  }

  Future<List<ProjectStockModel>> getProjectStock(int projectId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_projectStockKey)!) as List).where((e) => (e as Map)['project_id'] == projectId).toList();
    return list.map((m) => ProjectStockModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.materialName.compareTo(b.materialName));
  }

  Future<int> addProjectStock(ProjectStockModel s) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectStockKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'project_id': s.projectId, 'material_name': s.materialName, 'quantity': s.quantity, 'unit': s.unit});
    await prefs.setString(_projectStockKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateProjectStock(ProjectStockModel s) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectStockKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == s.id) {
        list[i] = {'id': s.id, 'project_id': s.projectId, 'material_name': s.materialName, 'quantity': s.quantity, 'unit': s.unit};
        break;
      }
    }
    await prefs.setString(_projectStockKey, jsonEncode(list));
  }

  Future<void> deleteProjectStock(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_projectStockKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_projectStockKey, jsonEncode(list));
  }

  Future<List<UnitModel>> getUnits(int buildingId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_unitsKey)!) as List).where((e) => (e as Map)['building_id'] == buildingId).toList();
    return list.map((m) => UnitModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addUnit(UnitModel u) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_unitsKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'building_id': u.buildingId, 'name': u.name, 'model': u.model, 'image_path': u.imagePath});
    await prefs.setString(_unitsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateUnit(UnitModel u) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_unitsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == u.id) {
        list[i] = {'id': u.id, 'building_id': u.buildingId, 'name': u.name, 'model': u.model, 'image_path': u.imagePath};
        break;
      }
    }
    await prefs.setString(_unitsKey, jsonEncode(list));
  }

  Future<void> deleteUnit(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_unitsKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_unitsKey, jsonEncode(list));
  }

  Future<List<BuildingMaterialModel>> getBuildingMaterials(int buildingId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List).where((e) => (e as Map)['building_id'] == buildingId).toList();
    return list.map((m) => BuildingMaterialModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.materialName.compareTo(b.materialName));
  }

  Future<int> addBuildingMaterial(BuildingMaterialModel m) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({...m.toMap(), 'id': nextId});
    await prefs.setString(_buildingMaterialsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateBuildingMaterial(BuildingMaterialModel m) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == m.id) {
        list[i] = m.toMap();
        break;
      }
    }
    await prefs.setString(_buildingMaterialsKey, jsonEncode(list));
  }

  Future<void> deleteBuildingMaterial(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_buildingMaterialsKey, jsonEncode(list));
  }

  Future<List<BuildingCutlistModel>> getBuildingCutlists(int buildingId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingCutlistKey)!) as List).where((e) => (e as Map)['building_id'] == buildingId).toList();
    return list.map((m) => BuildingCutlistModel.fromMap(Map<String, dynamic>.from(m as Map))).toList();
  }

  Future<int> addBuildingCutlist(BuildingCutlistModel c) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingCutlistKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'building_id': c.buildingId, 'image_path': c.imagePath});
    await prefs.setString(_buildingCutlistKey, jsonEncode(list));
    return nextId;
  }

  Future<void> deleteBuildingCutlist(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingCutlistKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_buildingCutlistKey, jsonEncode(list));
  }

  Future<List<SupervisorModel>> getSupervisors() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_supervisorsKey)!) as List;
    return list.map((m) => SupervisorModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addSupervisor(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_supervisorsKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'name': name});
    await prefs.setString(_supervisorsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateSupervisor(int id, String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_supervisorsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == id) {
        list[i] = {'id': id, 'name': name};
        break;
      }
    }
    await prefs.setString(_supervisorsKey, jsonEncode(list));
  }

  Future<void> deleteSupervisor(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_supervisorsKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_supervisorsKey, jsonEncode(list));
  }

  Future<List<ContractorModel>> getContractors() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_contractorsKey)!) as List;
    return list.map((m) => ContractorModel.fromMap(Map<String, dynamic>.from(m as Map))).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addContractor(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_contractorsKey)!) as List;
    final nextId = list.isEmpty ? 1 : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'name': name});
    await prefs.setString(_contractorsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateContractor(int id, String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_contractorsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == id) {
        list[i] = {'id': id, 'name': name};
        break;
      }
    }
    await prefs.setString(_contractorsKey, jsonEncode(list));
  }

  Future<void> deleteContractor(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_contractorsKey)!) as List).where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_contractorsKey, jsonEncode(list));
  }

  Future<int> addMaterial(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    if (list.isNotEmpty && list[0] is Map) {
      final nextId = (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b)) + 1;
      list.add({'id': nextId, 'name': name});
    } else {
      list.add({'id': list.length + 1, 'name': name});
    }
    await prefs.setString(_materialsKey, jsonEncode(list));
    return list.length;
  }

  Future<void> updateMaterial(int id, String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if (list[i] is Map && (list[i] as Map)['id'] == id) {
        list[i] = {'id': id, 'name': name};
        break;
      }
    }
    await prefs.setString(_materialsKey, jsonEncode(list));
  }

  Future<void> deleteMaterial(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    if (list[0] is Map) {
      final newList = (list).where((e) => (e as Map)['id'] != id).toList();
      await prefs.setString(_materialsKey, jsonEncode(newList));
    }
  }
}
