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
import '../models/notification_item_model.dart';
import '../models/shop_darwing_notification_model.dart';
import '../models/ir_mir_upload_model.dart';
import '../models/ms_sd_record_model.dart';
import '../models/mos_itp_record_model.dart';
import '../models/withdrawal_request_model.dart';
import '../models/reports_sys_model.dart';
import '../data/default_materials.dart';
import 'home_icon_order_service.dart';
import 'icon_visibility_service.dart';
import 'withdrawal_stock_validation.dart';
import '../data/materials_display.dart';
import 'attendance_duplicate_guard.dart';

/// تخزين للويب باستخدام SharedPreferences
class WebStorageService {
  static const _usersKey = 'wood_users';
  static const _projectsKey = 'wood_projects_v2';
  static const _attendanceKey = 'wood_attendance';
  static const _materialsKey = 'wood_materials_v3';
  static const _dailyReportsKey = 'wood_daily_reports';
  static const _zonesKey = 'wood_zones';
  static const _projectLocationsKey = 'wood_project_locations';
  static const _buildingsKey = 'wood_buildings';
  static const _supervisorsKey = 'wood_supervisors';
  static const _contractorsKey = 'wood_contractors';
  static const _projectStockKey = 'wood_project_stock';
  static const _projectStockLedgerKey = 'wood_project_stock_ledger';
  static const _locationMaterialsKey = 'wood_location_materials';
  static const _locationWithdrawalKey = 'wood_location_withdrawal';
  static const _unitsKey = 'wood_units';
  static const _buildingMaterialsKey = 'wood_building_materials';
  static const _buildingCutlistKey = 'wood_building_cutlist';
  static const _engineerBalanceKey = 'wood_engineer_balance';
  static const _engineerCustodyKey = 'wood_engineer_custody';
  static const _systemLockedKey = 'wood_system_locked';
  static const _homeIconsVisibilityKey = 'wood_home_icons_visibility';
  static const _notificationsKey = 'wood_notifications';
  static const _shopDarwingNotificationsKey = 'wood_shop_darwing_notifications';
  static const _irMirUploadsKey = 'wood_ir_mir_uploads';
  static const _msSdRecordsKey = 'wood_ms_sd_records';
  static const _mosItpRecordsKey = 'wood_mos_itp_records';

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  static List<Map<String, dynamic>> _defaultUsers() {
    const defaultPassword = '0000';
    return [
      {
        'id': 1,
        'name': 'Hany',
        'email': 'hany.samir1708@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 2,
        'name': 'Emam',
        'email': 'amirelazab46@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 3,
        'name': 'Mansur',
        'email': 'saedm0566@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 4,
        'name': 'Mahmud',
        'email': 'mahmoudsiko630@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 5,
        'name': 'Abdhusseny',
        'email': 'abdallaelhosseny1011@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 6,
        'name': 'Hamza',
        'email': 'hamzamhamad704@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 7,
        'name': 'Gohary',
        'email': 'mohamedelgohary371@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 8,
        'name': 'Amr',
        'email': 'amrelshabrawy55@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 9,
        'name': 'Hassan',
        'email': 'mouhammed.helal@gmail.com',
        'role': 'site_engineer',
        'password': defaultPassword,
      },
      {
        'id': 10,
        'name': 'Helal',
        'email': 'mouhamedhelal.cor@gmail.com',
        'role': 'site_engineer_manager',
        'password': defaultPassword,
      },
      {
        'id': 11,
        'name': 'Shams',
        'email': 'islam.shams2050@gmail.com',
        'role': 'site_engineer_manager',
        'password': defaultPassword,
      },
      {
        'id': 12,
        'name': 'Abdrhman',
        'email': 'AbdelrhmanEllaithy828@gmail.com',
        'role': 'site_engineer_manager',
        'password': defaultPassword,
      },
      {
        'id': 13,
        'name': 'مسؤول التطبيق',
        'email': 'mouhammedhelal@gmail.com',
        'role': 'app_admin',
        'password': defaultPassword,
      },
      {
        'id': 14,
        'name': 'Helal',
        'email': 'h@h.com',
        'role': 'app_admin',
        'password': '123',
      },
      {
        'id': 15,
        'name': 'account manager',
        'email': 'Account@gmail.com',
        'role': 'accountant',
        'password': '0000',
      },
    ];
  }

  Future<void> _initData() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) {
      await prefs.setString(_usersKey, jsonEncode(_defaultUsers()));
    } else {
      List<dynamic> list;
      try {
        list = jsonDecode(raw) as List;
      } catch (_) {
        await prefs.setString(_usersKey, jsonEncode(_defaultUsers()));
        return;
      }
      if (list.isEmpty) {
        await prefs.setString(_usersKey, jsonEncode(_defaultUsers()));
        return;
      }
      final hasAdmin = list.any(
        (e) =>
            ((e as Map)['email'] as String).toLowerCase() ==
            'mouhammedhelal@gmail.com',
      );
      if (!hasAdmin) {
        final nextId = list.isEmpty
            ? 1
            : (list
                      .map((e) => (e as Map)['id'] as int)
                      .reduce((a, b) => a > b ? a : b) +
                  1);
        list.add({
          'id': nextId,
          'name': 'مسؤول التطبيق',
          'email': 'mouhammedhelal@gmail.com',
          'role': 'app_admin',
          'password': '0000',
        });
        await prefs.setString(_usersKey, jsonEncode(list));
      }
      final hasHelal = list.any(
        (e) => ((e as Map)['email'] as String).toLowerCase() == 'h@h.com',
      );
      if (!hasHelal) {
        final nextId = list.isEmpty
            ? 1
            : (list
                      .map((e) => (e as Map)['id'] as int)
                      .reduce((a, b) => a > b ? a : b) +
                  1);
        list.add({
          'id': nextId,
          'name': 'Helal',
          'email': 'h@h.com',
          'role': 'app_admin',
          'password': '123',
        });
        await prefs.setString(_usersKey, jsonEncode(list));
      }
      final hasAccountant = list.any(
        (e) =>
            ((e as Map)['email'] as String).toLowerCase() ==
            'account@gmail.com',
      );
      if (!hasAccountant) {
        final nextId = list.isEmpty
            ? 1
            : (list
                      .map((e) => (e as Map)['id'] as int)
                      .reduce((a, b) => a > b ? a : b) +
                  1);
        list.add({
          'id': nextId,
          'name': 'account manager',
          'email': 'Account@gmail.com',
          'role': 'accountant',
          'password': '0000',
        });
        await prefs.setString(_usersKey, jsonEncode(list));
      }
    }
    if (prefs.getString(_projectsKey) == null) {
      final projectNames = [
        'UTC_Z5_CRC_F',
        'Mivida 31_CRC_F',
        'UTC_Z5_EMAAR Building C_F',
        'Zed east_ORASCOM_F',
        'Belle Vie_El-Hazek_F',
        'CAIRO GATE elain (02)_CRC_F',
        'Cairo gate_ACC_W',
        'Z1_EMAAR_F',
        'Community Center_CRC_W',
        'Terrace Zayed_CRC_W',
        'Silver Sands_REDCON_D',
        'CAR SHADE_W&M_W',
        'OLD CITY_ORASCOM_W',
        'Cairo gate-Eden_ATRUM_F',
        'AUC Campus Expansion_Orascom_W&F',
        'UTC - 2 Villa- Link International_W',
        'UTC - 2 Villa- Link International_F',
        'City Gate_CCC_W',
        'cairo gate - locanda_INOVOO_F',
        'Village West _ club_FIT-OUT_W',
        'Village West _Villa_W',
        'Mivida gardens_Atrium_F',
        'Village West_CRC_ F',
        'Up Town Cairo _Z5 _EMAAR_W',
        'Belle Vie _ EMAAR_W',
        'Village West _ CRC_ W',
        'Wood&More(head office)',
      ];
      final projects = projectNames
          .asMap()
          .entries
          .map((e) => {'id': e.key + 1, 'name': e.value})
          .toList();
      await prefs.setString(_projectsKey, jsonEncode(projects));
    }
    if (prefs.getString(_notificationsKey) == null) {
      await prefs.setString(_notificationsKey, jsonEncode(<Map<String, dynamic>>[]));
    }
    if (prefs.getString(_shopDarwingNotificationsKey) == null) {
      await prefs.setString(
        _shopDarwingNotificationsKey,
        jsonEncode(<Map<String, dynamic>>[]),
      );
    }
    if (prefs.getString(_irMirUploadsKey) == null) {
      await prefs.setString(_irMirUploadsKey, jsonEncode(<Map<String, dynamic>>[]));
    }
    if (prefs.getString(_msSdRecordsKey) == null) {
      await prefs.setString(_msSdRecordsKey, jsonEncode(<Map<String, dynamic>>[]));
    }
    if (prefs.getString(_mosItpRecordsKey) == null) {
      await prefs.setString(_mosItpRecordsKey, jsonEncode(<Map<String, dynamic>>[]));
    }
    if (prefs.getString(_attendanceKey) == null) {
      await prefs.setString(_attendanceKey, jsonEncode([]));
    }
    if (prefs.getString(_materialsKey) == null) {
      final materialsList = defaultMaterialsList
          .asMap()
          .entries
          .map((e) => {'id': e.key + 1, 'name': e.value})
          .toList();
      await prefs.setString(_materialsKey, jsonEncode(materialsList));
    }
    if (prefs.getString(_dailyReportsKey) == null) {
      await prefs.setString(_dailyReportsKey, jsonEncode([]));
    }
    if (prefs.getString(_zonesKey) == null)
      await prefs.setString(_zonesKey, jsonEncode([]));
    if (prefs.getString(_projectLocationsKey) == null)
      await prefs.setString(_projectLocationsKey, jsonEncode([]));
    if (prefs.getString(_buildingsKey) == null)
      await prefs.setString(_buildingsKey, jsonEncode([]));
    if (prefs.getString(_supervisorsKey) == null)
      await prefs.setString(_supervisorsKey, jsonEncode([]));
    if (prefs.getString(_contractorsKey) == null)
      await prefs.setString(_contractorsKey, jsonEncode([]));
    if (prefs.getString(_projectStockKey) == null)
      await prefs.setString(_projectStockKey, jsonEncode([]));
    if (prefs.getString(_projectStockLedgerKey) == null)
      await prefs.setString(_projectStockLedgerKey, jsonEncode([]));
    if (prefs.getString(_locationMaterialsKey) == null)
      await prefs.setString(_locationMaterialsKey, jsonEncode([]));
    if (prefs.getString(_locationWithdrawalKey) == null)
      await prefs.setString(_locationWithdrawalKey, jsonEncode([]));
    if (prefs.getString(_unitsKey) == null)
      await prefs.setString(_unitsKey, jsonEncode([]));
    if (prefs.getString(_buildingMaterialsKey) == null)
      await prefs.setString(_buildingMaterialsKey, jsonEncode([]));
    if (prefs.getString(_buildingCutlistKey) == null)
      await prefs.setString(_buildingCutlistKey, jsonEncode([]));
    if (prefs.getString(_engineerBalanceKey) == null)
      await prefs.setString(_engineerBalanceKey, jsonEncode([]));
    if (prefs.getString(_engineerCustodyKey) == null)
      await prefs.setString(_engineerCustodyKey, jsonEncode([]));
    if (!prefs.containsKey(_systemLockedKey))
      await prefs.setBool(_systemLockedKey, false);
    if (prefs.getString(_homeIconsVisibilityKey) == null) {
      await prefs.setString(
        _homeIconsVisibilityKey,
        jsonEncode(IconVisibilityService.normalizeAllConfig(null)),
      );
    }
    await _syncMaterialsCatalog();
  }

  Future<void> _syncMaterialsCatalog() async {
    final prefs = await _prefs;
    final allowed = defaultMaterialsList.map((e) => e.trim()).toSet();
    final raw = prefs.getString(_materialsKey);
    final list = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    final kept = list
        .where((e) => allowed.contains((e['name'] as String?)?.trim() ?? ''))
        .toList();
    final names = kept
        .map((e) => (e['name'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
    for (final name in defaultMaterialsList) {
      if (!names.contains(name)) {
        kept.add({'id': 0, 'name': name});
      }
    }
    final normalized = <Map<String, dynamic>>[];
    for (var i = 0; i < kept.length; i++) {
      normalized.add({
        'id': i + 1,
        'name': (kept[i]['name'] as String).trim(),
      });
    }
    await prefs.setString(_materialsKey, jsonEncode(normalized));
  }

  Future<bool> isSystemLocked() async {
    await _initData();
    final prefs = await _prefs;
    return prefs.getBool(_systemLockedKey) ?? false;
  }

  Future<void> setSystemLocked(
    bool locked, {
    String? requesterEmail,
  }) async {
    await _initData();
    final prefs = await _prefs;
    await prefs.setBool(_systemLockedKey, locked);
  }

  Future<Map<String, Map<String, bool>>> getHomeIconsVisibilityConfig() async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_homeIconsVisibilityKey);
    if (raw == null || raw.trim().isEmpty)
      return IconVisibilityService.normalizeAllConfig(null);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>)
        return IconVisibilityService.normalizeAllConfig(decoded);
      if (decoded is Map)
        return IconVisibilityService.normalizeAllConfig(
          Map<String, dynamic>.from(decoded),
        );
    } catch (_) {}
    return IconVisibilityService.normalizeAllConfig(null);
  }

  Future<void> setHomeIconsVisibilityForRole(
    String role,
    Map<String, bool> roleConfig,
  ) async {
    await _initData();
    final prefs = await _prefs;
    final current = await getHomeIconsVisibilityConfig();
    current[role] = Map<String, bool>.from(roleConfig);
    await prefs.setString(_homeIconsVisibilityKey, jsonEncode(current));
  }

  String _homeIconOrderKey(int userId) => 'wood_home_icon_order_$userId';

  Future<List<String>> getUserHomeIconOrder(int userId) async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_homeIconOrderKey(userId));
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return sanitizeSavedHomeIconOrder(
        decoded is List ? decoded : null,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> setUserHomeIconOrder({
    required int userId,
    required List<String> iconOrder,
  }) async {
    await _initData();
    final prefs = await _prefs;
    await prefs.setString(_homeIconOrderKey(userId), jsonEncode(iconOrder));
  }

  Future<List<String>> getMaterials() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    if (list.isNotEmpty && list[0] is! Map) {
      return sortMaterialsForDisplay(list.map((e) => e as String));
    }
    return sortMaterialsForDisplay(
      list.map((e) => (e as Map)['name'] as String),
    );
  }

  Future<List<Map<String, dynamic>>> getMaterialsWithIds() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    if (list.isEmpty) return [];
    if (list[0] is Map) {
      return sortMaterialRowsForDisplay(
        list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }
    return sortMaterialRowsForDisplay(
      (list as List)
          .asMap()
          .entries
          .map((e) => {'id': e.key + 1, 'name': e.value as String})
          .toList(),
    );
  }

  /// حد أقصى لعدد التقارير المخزنة على الويب لتجنب QuotaExceededError
  static const int _maxStoredReports = 50;
  static const int _maxStoredBytes = 3 * 1024 * 1024; // 3 MB

  Future<void> addDailyReport(DailyReportData report) async {
    await _initData();
    final prefs = await _prefs;
    List list = jsonDecode(prefs.getString(_dailyReportsKey)!) as List;
    final map = report.toJson();
    map['id'] = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
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
      if (e.toString().contains('QuotaExceeded') ||
          e.toString().contains('quota')) {
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

    // خصم الخامات من مخزن المشروع المختار في التقرير
    if (report.projectId != null) {
      for (final m in report.materials) {
        if (m.materialName.isEmpty || m.quantity.isEmpty) continue;
        final qty =
            double.tryParse(m.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        if (qty <= 0) continue;
        final unit = m.unit.isEmpty ? 'متر' : m.unit;
        await deductProjectStock(
          report.projectId!,
          m.materialName,
          unit,
          qty,
          report.userName,
          report.reportDate,
        );
      }
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

  Future<void> addCustody(
    int userId,
    double amount,
    String note, [
    String? documentPath,
  ]) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_engineerCustodyKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'user_id': userId,
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
      'note': note,
      'document_path': documentPath,
      'movement_type': 'custody',
    });
    await prefs.setString(_engineerCustodyKey, jsonEncode(list));
    final current = await getEngineerBalance(userId);
    await setEngineerBalance(userId, current - amount);
  }

  /// تسجيل حركة إضافة رصيد أو سحب رصيد فقط (بدون تغيير الرصيد)
  Future<void> addBalanceMovement(
    int userId,
    double amount,
    String note,
    String movementType,
  ) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_engineerCustodyKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'user_id': userId,
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
      'note': note,
      'document_path': null,
      'movement_type': movementType,
    });
    await prefs.setString(_engineerCustodyKey, jsonEncode(list));
  }

  Future<List<Map<String, dynamic>>> getCustodyRecords({int? userId}) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_engineerCustodyKey)!) as List;
    var result = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (userId != null)
      result = result.where((e) => e['user_id'] == userId).toList();
    result.sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return result
        .map(
          (e) => {
            'id': e['id'],
            'user_id': e['user_id'],
            'amount': (e['amount'] as num).toDouble(),
            'created_at': e['created_at'],
            'note': e['note'],
            'document_path': e['document_path'],
            'movement_type': e['movement_type'] as String? ?? 'custody',
          },
        )
        .toList();
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

  /// التحقق من تسجيل الدخول (بريد + كلمة سر)، كلمة السر الافتراضية المؤقتة: 0000
  Future<UserModel?> validateLogin(String email, String password) async {
    await _initData();
    final prefs = await _prefs;
    var raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) {
      await prefs.setString(_usersKey, jsonEncode(_defaultUsers()));
      raw = prefs.getString(_usersKey);
    }
    if (raw == null || raw.isEmpty) return null;
    List<dynamic> list;
    try {
      list = jsonDecode(raw) as List;
    } catch (_) {
      await prefs.setString(_usersKey, jsonEncode(_defaultUsers()));
      list = _defaultUsers();
    }
    if (list.isEmpty) {
      await prefs.setString(_usersKey, jsonEncode(_defaultUsers()));
      list = _defaultUsers();
    }
    final emailLower = email.trim().toLowerCase();
    final pwd = password.trim();
    for (final m in list) {
      final map = Map<String, dynamic>.from(m as Map);
      final storedEmail = (map['email']?.toString() ?? '').trim().toLowerCase();
      if (storedEmail != emailLower) continue;
      final stored = (map['password']?.toString() ?? '0000').trim();
      if (stored.isEmpty || pwd != stored) return null;
      return UserModel.fromMap(map);
    }
    return null;
  }

  Future<List<ProjectModel>> getProjects() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectsKey)!) as List;
    final projects = list
        .map((m) => ProjectModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    final seen = <String>{};
    final unique = projects.where((p) => seen.add(p.name)).toList();
    unique.sort((a, b) => a.name.compareTo(b.name));
    return unique;
  }

  Future<List<ProjectModel>> getProjectsRaw() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectsKey)!) as List;
    final projects = list
        .map((m) => ProjectModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    projects.sort((a, b) {
      final byName = a.name.compareTo(b.name);
      if (byName != 0) return byName;
      return a.id.compareTo(b.id);
    });
    return projects;
  }

  Future<void> addAttendanceRecord(AttendanceRecordModel record) async {
    await _initData();
    final prefs = await _prefs;
    final existing = await getAttendanceRecordsByUser(record.userId);
    final dup = duplicateAttendanceMessageIfAny(
      userRecords: existing,
      userId: record.userId,
      projectId: record.projectId,
      projectName: record.projectName,
      type: record.type,
      onDate: record.dateTime,
    );
    if (dup != null) throw DuplicateAttendanceException(dup);

    final list = jsonDecode(prefs.getString(_attendanceKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    final cal = attendanceLocalCalendarDateKey(record.dateTime);
    final map = {
      'id': nextId,
      'user_id': record.userId,
      'user_name': record.userName,
      'type': record.type,
      'date_time': record.dateTime.toIso8601String(),
      'calendar_date': cal,
      'location': record.location,
      'project_id': record.projectId,
      'project_name': record.projectName,
      'notes': record.notes,
    };
    list.insert(0, map);
    await prefs.setString(_attendanceKey, jsonEncode(list));
    await _notifySiteEngineerManagersOnAttendance(record);
  }

  Future<void> _notifySiteEngineerManagersOnAttendance(
    AttendanceRecordModel record,
  ) async {
    final users = await getUsers();
    final recipients = users
        .where(
          (u) =>
              u.role == 'site_engineer_manager' ||
              u.role == 'operation_manager' ||
              u.role == 'app_admin',
        )
        .toList(growable: false);
    if (recipients.isEmpty) return;
    final prefs = await _prefs;
    final raw = prefs.getString(_notificationsKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    var nextId = list.isEmpty
        ? 1
        : (list.map((e) => (e as Map)['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    final isCheckIn = record.type == 'check_in';
    final actionLabel = isCheckIn ? 'الحضور' : 'الانصراف';
    final projectName = (record.projectName ?? '').trim().isEmpty
        ? 'بدون مشروع'
        : record.projectName!.trim();
    final body =
        'قام "${record.userName}" بتسجيل $actionLabel بمشروع "$projectName"';
    final now = DateTime.now().toIso8601String();
    for (final recipient in recipients) {
      list.add({
        'id': nextId++,
        'recipient_user_id': recipient.id,
        'recipient_role': recipient.role,
        'title': 'تنبيه حضور/انصراف',
        'body': body,
        'event_type': 'attendance_${record.type}',
        'actor_user_id': record.userId,
        'actor_user_name': record.userName,
        'project_name': record.projectName,
        'created_at': now,
        'is_read': 0,
        'read_at': null,
      });
    }
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  Future<List<NotificationItemModel>> getNotificationsForUser(int userId) async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_notificationsKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    final result = list
        .map((e) => NotificationItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((n) => n.recipientUserId == userId)
        .toList();
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  Future<int> getUnreadNotificationsCount(int userId) async {
    final list = await getNotificationsForUser(userId);
    return list.where((n) => !n.isRead).length;
  }

  Future<void> markNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_notificationsKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    for (var i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      if (map['id'] != notificationId) continue;
      if (map['recipient_user_id'] != userId) continue;
      map['is_read'] = 1;
      map['read_at'] = DateTime.now().toIso8601String();
      list[i] = map;
      break;
    }
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  Future<void> deleteNotification({
    required int notificationId,
    required int userId,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_notificationsKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    for (final e in list) {
      final map = Map<String, dynamic>.from(e as Map);
      if (map['id'] != notificationId || map['recipient_user_id'] != userId) {
        continue;
      }
      final wrId = map['withdrawal_request_id'];
      final actionAt = map['action_taken_at'];
      if (wrId != null && (actionAt == null || actionAt.toString().isEmpty)) {
        throw Exception('action_required_before_delete');
      }
      break;
    }
    list.removeWhere((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return map['id'] == notificationId && map['recipient_user_id'] == userId;
    });
    await prefs.setString(_notificationsKey, jsonEncode(list));
  }

  Future<List<ShopDarwingNotificationModel>> getShopDarwingNotifications(
    int userId,
  ) async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_shopDarwingNotificationsKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    return list
        .map(
          (e) => ShopDarwingNotificationModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .where((n) => n.recipientUserId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<int> getUnreadShopDarwingNotificationsCount(int userId) async {
    final list = await getShopDarwingNotifications(userId);
    return list.where((n) => !n.isRead).length;
  }

  Future<void> markShopDarwingNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_shopDarwingNotificationsKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    for (var i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      if (map['id'] != notificationId) continue;
      if (map['recipient_user_id'] != userId) continue;
      map['is_read'] = 1;
      map['read_at'] = DateTime.now().toIso8601String();
      list[i] = map;
      break;
    }
    await prefs.setString(_shopDarwingNotificationsKey, jsonEncode(list));
  }

  Future<void> deleteShopDarwingNotification({
    required int notificationId,
    required int userId,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final raw = prefs.getString(_shopDarwingNotificationsKey) ?? '[]';
    final list = jsonDecode(raw) as List;
    list.removeWhere((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return map['id'] == notificationId && map['recipient_user_id'] == userId;
    });
    await prefs.setString(_shopDarwingNotificationsKey, jsonEncode(list));
  }

  Future<List<AttendanceRecordModel>> getAllAttendanceRecords() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_attendanceKey)!) as List;
    return list
        .map(
          (m) => AttendanceRecordModel.fromMap(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList();
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecordsByUser(
    int userId,
  ) async {
    final all = await getAllAttendanceRecords();
    final list = all.where((r) => r.userId == userId).toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // الأحدث أولاً
    return list;
  }

  /// موعد الحضور والانصراف لمستخدم في تاريخ معين (نفس اليوم فقط)
  Future<({DateTime? checkIn, DateTime? checkOut})> getAttendanceForUserOnDate(
    int userId,
    DateTime date,
  ) async {
    final list = await getAttendanceRecordsByUser(userId);
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    DateTime? checkIn;
    DateTime? checkOut;
    for (final r in list) {
      if (r.dateTime.isBefore(dayStart) || r.dateTime.isAfter(dayEnd)) continue;
      if (r.isCheckIn && (checkIn == null || r.dateTime.isBefore(checkIn)))
        checkIn = r.dateTime;
      if (r.isCheckOut && (checkOut == null || r.dateTime.isAfter(checkOut)))
        checkOut = r.dateTime;
    }
    return (checkIn: checkIn, checkOut: checkOut);
  }

  Future<void> deleteAttendanceRecord(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_attendanceKey)!) as List;
    final newList = list.where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_attendanceKey, jsonEncode(newList));
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
    final toEnd = DateTime(
      dateTo.year,
      dateTo.month,
      dateTo.day,
      23,
      59,
      59,
      999,
    );
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

  Future<void> deleteDailyReport(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_dailyReportsKey)!) as List;
    final newList = list.where((e) => (e as Map)['id'] != id).toList();
    await prefs.setString(_dailyReportsKey, jsonEncode(newList));
  }

  // ——— لوح التحكم ———
  Future<List<UserModel>> getUsers() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    final out = list
        .map<UserModel>(
          (m) => UserModel.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList();
    out.sort((UserModel a, UserModel b) => a.name.compareTo(b.name));
    return out;
  }

  Future<int> addUser(
    String name,
    String email,
    String password,
    String role,
  ) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    final pwd = password.trim().isEmpty ? '0000' : password.trim();
    list.add({
      'id': nextId,
      'name': name,
      'email': email.trim().toLowerCase(),
      'role': role,
      'password': pwd,
    });
    await prefs.setString(_usersKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateUser(
    int id,
    String name,
    String email,
    String role, [
    String? password,
  ]) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_usersKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      if (map['id'] != id) continue;
      final existingPassword = map['password']?.toString().trim() ?? '0000';
      final pwd = (password != null && password.trim().isNotEmpty)
          ? password.trim()
          : existingPassword;
      list[i] = {
        'id': id,
        'name': name,
        'email': email.trim().toLowerCase(),
        'role': role,
        'password': pwd.isEmpty ? '0000' : pwd,
      };
      break;
    }
    await prefs.setString(_usersKey, jsonEncode(list));
  }

  Future<void> deleteUser(int id, {String? requesterEmail}) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_usersKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_usersKey, jsonEncode(list));
  }

  Future<int> addProject(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectsKey)!) as List;
    final normalized = name.trim().toLowerCase();
    for (final row in list) {
      final map = Map<String, dynamic>.from(row as Map);
      final existing = (map['name']?.toString() ?? '').trim().toLowerCase();
      if (existing == normalized) return map['id'] as int;
    }
    final nextId = list.isEmpty
        ? 1
        : (list.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
    list.add({'id': nextId, 'name': name.trim()});
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
    final list = (jsonDecode(prefs.getString(_projectsKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    final zones = (jsonDecode(prefs.getString(_zonesKey)!) as List)
        .where((e) => (e as Map)['project_id'] != id)
        .toList();
    final plocs = (jsonDecode(prefs.getString(_projectLocationsKey)!) as List)
        .where((e) => (e as Map)['project_id'] != id)
        .toList();
    final stock = (jsonDecode(prefs.getString(_projectStockKey)!) as List)
        .where((e) => (e as Map)['project_id'] != id)
        .toList();
    await prefs.setString(_projectsKey, jsonEncode(list));
    await prefs.setString(_zonesKey, jsonEncode(zones));
    await prefs.setString(_projectLocationsKey, jsonEncode(plocs));
    await prefs.setString(_projectStockKey, jsonEncode(stock));
  }

  Future<List<ZoneModel>> getZones(int projectId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_zonesKey)!) as List)
        .where((e) => (e as Map)['project_id'] == projectId)
        .toList();
    return list
        .map((m) => ZoneModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addZone(int projectId, String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_zonesKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
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
        list[i] = {
          'id': id,
          'project_id': (list[i] as Map)['project_id'],
          'name': name,
        };
        break;
      }
    }
    await prefs.setString(_zonesKey, jsonEncode(list));
  }

  Future<void> deleteZone(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_zonesKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    final buildings = (jsonDecode(prefs.getString(_buildingsKey)!) as List)
        .where((e) => (e as Map)['zone_id'] != id)
        .toList();
    await prefs.setString(_zonesKey, jsonEncode(list));
    await prefs.setString(_buildingsKey, jsonEncode(buildings));
  }

  Future<List<ProjectLocationModel>> getProjectLocations(int projectId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_projectLocationsKey)!) as List)
        .where((e) => (e as Map)['project_id'] == projectId)
        .toList();
    return list
        .map(
          (m) =>
              ProjectLocationModel.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList()
      ..sort(
        (a, b) => a.displayOrder != b.displayOrder
            ? a.displayOrder.compareTo(b.displayOrder)
            : a.id.compareTo(b.id),
      );
  }

  Future<int> addProjectLocation({
    required int projectId,
    int? parentId,
    required String name,
    required String type,
    int displayOrder = 0,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectLocationsKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'project_id': projectId,
      'parent_id': parentId,
      'name': name,
      'type': type,
      'display_order': displayOrder,
    });
    await prefs.setString(_projectLocationsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateProjectLocation(
    int id, {
    String? name,
    int? displayOrder,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectLocationsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      final m = list[i] as Map;
      if (m['id'] == id) {
        if (name != null) m['name'] = name;
        if (displayOrder != null) m['display_order'] = displayOrder;
        list[i] = m;
        break;
      }
    }
    await prefs.setString(_projectLocationsKey, jsonEncode(list));
  }

  Future<void> deleteProjectLocation(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectLocationsKey)!) as List;
    final toRemove = <int>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final e in list) {
        final m = e as Map;
        final pid = m['parent_id'];
        final eid = m['id'] is int
            ? m['id'] as int
            : int.parse(m['id'].toString());
        if (pid != null &&
            toRemove.contains(pid is int ? pid : int.parse(pid.toString())) &&
            !toRemove.contains(eid)) {
          toRemove.add(eid);
          changed = true;
        }
      }
    }
    final filtered = list
        .where(
          (e) => !toRemove.contains(
            (e as Map)['id'] is int
                ? (e as Map)['id'] as int
                : int.parse((e as Map)['id'].toString()),
          ),
        )
        .toList();
    await prefs.setString(_projectLocationsKey, jsonEncode(filtered));
  }

  Future<List<BuildingModel>> getBuildings(int zoneId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingsKey)!) as List)
        .where((e) => (e as Map)['zone_id'] == zoneId)
        .toList();
    return list
        .map((m) => BuildingModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addBuilding(BuildingModel b) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingsKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'zone_id': b.zoneId,
      'name': b.name,
      'storage_info': b.storageInfo,
      'model_details': b.modelDetails,
      'cut_list': b.cutList,
    });
    await prefs.setString(_buildingsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateBuilding(BuildingModel b) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == b.id) {
        list[i] = {
          'id': b.id,
          'zone_id': b.zoneId,
          'name': b.name,
          'storage_info': b.storageInfo,
          'model_details': b.modelDetails,
          'cut_list': b.cutList,
        };
        break;
      }
    }
    await prefs.setString(_buildingsKey, jsonEncode(list));
  }

  Future<void> deleteBuilding(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingsKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    final units = (jsonDecode(prefs.getString(_unitsKey)!) as List)
        .where((e) => (e as Map)['building_id'] != id)
        .toList();
    final bm = (jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List)
        .where((e) => (e as Map)['building_id'] != id)
        .toList();
    final bc = (jsonDecode(prefs.getString(_buildingCutlistKey)!) as List)
        .where((e) => (e as Map)['building_id'] != id)
        .toList();
    await prefs.setString(_buildingsKey, jsonEncode(list));
    await prefs.setString(_unitsKey, jsonEncode(units));
    await prefs.setString(_buildingMaterialsKey, jsonEncode(bm));
    await prefs.setString(_buildingCutlistKey, jsonEncode(bc));
  }

  Future<List<ProjectStockModel>> getProjectStock(int projectId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_projectStockKey)!) as List)
        .where((e) => (e as Map)['project_id'] == projectId)
        .toList();
    return list
        .map(
          (m) => ProjectStockModel.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList()
      ..sort((a, b) => a.materialName.compareTo(b.materialName));
  }

  Future<int> addProjectStock(ProjectStockModel s) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectStockKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'project_id': s.projectId,
      'material_name': s.materialName,
      'quantity': s.quantity,
      'unit': s.unit,
    });
    await prefs.setString(_projectStockKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateProjectStock(ProjectStockModel s) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectStockKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == s.id) {
        list[i] = {
          'id': s.id,
          'project_id': s.projectId,
          'material_name': s.materialName,
          'quantity': s.quantity,
          'unit': s.unit,
        };
        break;
      }
    }
    await prefs.setString(_projectStockKey, jsonEncode(list));
  }

  Future<void> deleteProjectStock(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_projectStockKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_projectStockKey, jsonEncode(list));
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
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectStockLedgerKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.insert(0, {
      'id': nextId,
      'project_id': projectId,
      'material_name': materialName,
      'unit': unit,
      'quantity_delta': quantityDelta,
      'type': type,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'user_id': userId,
      'user_name': userName,
    });
    await prefs.setString(_projectStockLedgerKey, jsonEncode(list));
  }

  Future<List<ProjectStockLedgerModel>> getStockLedger(
    int projectId,
    String materialName,
  ) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectStockLedgerKey)!) as List;
    final filtered = list
        .where(
          (e) =>
              (e as Map)['project_id'] == projectId &&
              (e)['material_name'] == materialName,
        )
        .toList();
    return filtered
        .map(
          (m) => ProjectStockLedgerModel.fromMap(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// خصم رقم الكمية فقط؛ المطابقة بالمشروع + اسم الخامة (الوحدة ثابتة).
  Future<bool> deductProjectStock(
    int projectId,
    String materialName,
    String unit,
    double quantity,
    String engineerName,
    DateTime reportDate,
  ) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_projectStockKey)!) as List;
    final idx = list.indexWhere(
      (e) =>
          (e as Map)['project_id'] == projectId &&
          e['material_name'] == materialName,
    );
    if (idx < 0) return false;
    final row = Map<String, dynamic>.from(list[idx] as Map);
    final current =
        double.tryParse(
          (row['quantity'] as String).replaceAll(RegExp(r'[^\d.]'), ''),
        ) ??
        0;
    final newQty = current - quantity;
    row['quantity'] = newQty.toStringAsFixed(2);
    list[idx] = row;
    await prefs.setString(_projectStockKey, jsonEncode(list));
    final stockUnit = row['unit'] as String? ?? unit;
    await addProjectStockLedgerEntry(
      projectId: projectId,
      materialName: materialName,
      unit: stockUnit,
      quantityDelta: -quantity,
      type: 'deduct_report',
      userName: engineerName,
      createdAt: reportDate,
    );
    return true;
  }

  Future<List<LocationMaterialModel>> getLocationMaterials(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_locationMaterialsKey)!) as List)
        .where(
          (e) =>
              (e as Map)['location_id'] == locationId &&
              ((e['phase'] ?? LocationMaterialModel.phaseFirstFix) ==
                  phase),
        )
        .toList();
    return list
        .map(
          (m) => LocationMaterialModel.fromMap(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList()
      ..sort((a, b) => a.materialName.compareTo(b.materialName));
  }

  Future<List<LocationMaterialModel>> getLocationMaterialsForProject(
    int projectId,
  ) async {
    final locations = await getProjectLocations(projectId);
    final locationIds = locations.map((e) => e.id).toSet();
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_locationMaterialsKey)!) as List)
        .where((e) => locationIds.contains((e as Map)['location_id']))
        .toList();
    return list
        .map(
          (m) => LocationMaterialModel.fromMap(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList()
      ..sort((a, b) {
        final byLocation = a.locationId.compareTo(b.locationId);
        if (byLocation != 0) return byLocation;
        final byPhase = a.phase.compareTo(b.phase);
        if (byPhase != 0) return byPhase;
        return a.materialName.compareTo(b.materialName);
      });
  }

  Future<int> addLocationMaterial(LocationMaterialModel m) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_locationMaterialsKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'location_id': m.locationId,
      'phase': m.phase,
      'material_name': m.materialName,
      'quantity': m.quantity,
      'unit': m.unit,
    });
    await prefs.setString(_locationMaterialsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateLocationMaterial(LocationMaterialModel m) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_locationMaterialsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == m.id) {
        list[i] = {
          'id': m.id,
          'location_id': m.locationId,
          'phase': m.phase,
          'material_name': m.materialName,
          'quantity': m.quantity,
          'unit': m.unit,
        };
        break;
      }
    }
    await prefs.setString(_locationMaterialsKey, jsonEncode(list));
  }

  Future<void> deleteLocationMaterial(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_locationMaterialsKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_locationMaterialsKey, jsonEncode(list));
  }

  Future<LocationWithdrawalModel?> getLocationWithdrawal(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_locationWithdrawalKey)!) as List;
    final found = list
        .where(
          (e) =>
              (e as Map)['location_id'] == locationId &&
              ((e['phase'] ?? LocationMaterialModel.phaseFirstFix) == phase),
        )
        .toList();
    if (found.isEmpty) return null;
    return LocationWithdrawalModel.fromMap(
      Map<String, dynamic>.from(found.first as Map),
    );
  }

  Future<List<LocationWithdrawalModel>> getLocationWithdrawalsForProject(
    int projectId,
  ) async {
    final locations = await getProjectLocations(projectId);
    final locationIds = locations.map((e) => e.id).toSet();
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_locationWithdrawalKey)!) as List;
    return list
        .where((e) => locationIds.contains((e as Map)['location_id']))
        .map(
          (e) => LocationWithdrawalModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList()
      ..sort((a, b) {
        final byLocation = a.locationId.compareTo(b.locationId);
        if (byLocation != 0) return byLocation;
        return a.phase.compareTo(b.phase);
      });
  }

  Future<void> createLocationWithdrawal({
    required int locationId,
    String phase = LocationMaterialModel.phaseFirstFix,
    required int userId,
    required String userName,
    String? disbursementPermitImagesJson,
    String? deliveryPermitImagesJson,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final plocs = jsonDecode(prefs.getString(_projectLocationsKey)!) as List;
    final locMap = plocs.cast<Map?>().firstWhere(
      (e) => e != null && (e as Map)['id'] == locationId,
      orElse: () => null,
    );
    if (locMap == null) throw Exception('الموقع غير موجود');
    final projectId = (locMap as Map)['project_id'] as int;
    final materials = await getLocationMaterials(locationId, phase: phase);
    final stockList = jsonDecode(prefs.getString(_projectStockKey)!) as List;
    final stockModels = stockList
        .map(
          (e) => ProjectStockModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .where((s) => s.projectId == projectId)
        .toList();
    if (!hasSufficientStockForWithdrawal(
      locationMaterials: materials,
      projectStock: stockModels,
    )) {
      throw Exception(withdrawalInsufficientStockMessage);
    }
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    for (final m in materials) {
      final qty =
          double.tryParse(m.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      if (qty <= 0) continue;
      final unit = m.unit.isEmpty ? 'وحدة' : m.unit;
      final idx = stockList.indexWhere(
        (e) =>
            (e as Map)['project_id'] == projectId &&
            e['material_name'] == m.materialName,
      );
      if (idx >= 0) {
        final row = Map<String, dynamic>.from(stockList[idx] as Map);
        final current =
            double.tryParse(
              (row['quantity'] as String).replaceAll(RegExp(r'[^\d.]'), ''),
            ) ??
            0;
        row['quantity'] = (current - qty).toStringAsFixed(2);
        stockList[idx] = row;
        await addProjectStockLedgerEntry(
          projectId: projectId,
          materialName: m.materialName,
          unit: row['unit'] as String? ?? unit,
          quantityDelta: -qty,
          type: 'withdraw_location',
          userName: userName,
          createdAt: now,
          userId: userId,
        );
      }
    }
    await prefs.setString(_projectStockKey, jsonEncode(stockList));
    final withdrawals =
        jsonDecode(prefs.getString(_locationWithdrawalKey)!) as List;
    if (withdrawals.any(
      (e) =>
          (e as Map)['location_id'] == locationId &&
          ((e['phase'] ?? LocationMaterialModel.phaseFirstFix) == phase),
    ))
      throw Exception('تم سحب الخامات من هذا المكان مسبقاً');
    final nextId = withdrawals.isEmpty
        ? 1
        : (withdrawals
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    withdrawals.add({
      'id': nextId,
      'location_id': locationId,
      'phase': phase,
      'user_id': userId,
      'user_name': userName,
      'created_at': nowStr,
      'disbursement_permit_images_json': disbursementPermitImagesJson,
      'delivery_permit_images_json': deliveryPermitImagesJson,
    });
    await prefs.setString(_locationWithdrawalKey, jsonEncode(withdrawals));
  }

  /// إلغاء سحب الخامات واسترجاع رصيد المشروع (مسؤول التطبيق).
  Future<void> deleteLocationWithdrawal(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    await _initData();
    final prefs = await _prefs;
    final withdrawalList =
        jsonDecode(prefs.getString(_locationWithdrawalKey)!) as List;
    final found = withdrawalList
        .cast<Map?>()
        .where(
          (e) =>
              e != null &&
              (e as Map)['location_id'] == locationId &&
              (((e)['phase'] ?? LocationMaterialModel.phaseFirstFix) == phase),
        )
        .toList();
    if (found.isEmpty) return;
    final w = Map<String, dynamic>.from(found.first as Map);
    final withdrawal = LocationWithdrawalModel.fromMap(w);

    final plocs = jsonDecode(prefs.getString(_projectLocationsKey)!) as List;
    final locMap = plocs.cast<Map?>().firstWhere(
      (e) => e != null && (e as Map)['id'] == locationId,
      orElse: () => null,
    );
    if (locMap == null) throw Exception('الموقع غير موجود');
    final projectId = (locMap as Map)['project_id'] as int;

    final ledgerRaw =
        jsonDecode(prefs.getString(_projectStockLedgerKey)!) as List;
    bool ledgerMatches(Map<String, dynamic> row) {
      if (row['project_id'] != projectId) return false;
      if (row['type'] != 'withdraw_location') return false;
      final uid = row['user_id'];
      final uidInt = uid is int ? uid : int.tryParse(uid?.toString() ?? '');
      if (uidInt != withdrawal.userId) return false;
      final entryTime = DateTime.tryParse(row['created_at'].toString());
      if (entryTime == null) return false;
      return entryTime.difference(withdrawal.createdAt).inMilliseconds.abs() <=
          2000;
    }

    final toRemoveIds = <int>{};
    final stockList = jsonDecode(prefs.getString(_projectStockKey)!) as List;

    for (final e in ledgerRaw) {
      final row = Map<String, dynamic>.from(e as Map);
      if (!ledgerMatches(row)) continue;
      toRemoveIds.add(row['id'] as int);
      final delta = (row['quantity_delta'] as num?)?.toDouble() ?? 0;
      if (delta >= 0) continue;
      final addBack = -delta;
      final materialName = row['material_name'] as String;
      final idx = stockList.indexWhere(
        (s) =>
            (s as Map)['project_id'] == projectId &&
            s['material_name'] == materialName,
      );
      if (idx >= 0) {
        final stockRow = Map<String, dynamic>.from(stockList[idx] as Map);
        final current =
            double.tryParse(
              (stockRow['quantity'] as String).replaceAll(
                RegExp(r'[^\d.]'),
                '',
              ),
            ) ??
            0;
        stockRow['quantity'] = (current + addBack).toStringAsFixed(2);
        stockList[idx] = stockRow;
      } else {
        final unit = (row['unit'] as String?)?.isNotEmpty == true
            ? row['unit'] as String
            : 'وحدة';
        final nextStockId = stockList.isEmpty
            ? 1
            : (stockList
                      .map((x) => (x as Map)['id'] as int)
                      .reduce((a, b) => a > b ? a : b) +
                  1);
        stockList.add({
          'id': nextStockId,
          'project_id': projectId,
          'material_name': materialName,
          'quantity': addBack.toStringAsFixed(2),
          'unit': unit,
        });
      }
    }

    final newLedger = ledgerRaw
        .where((e) => !toRemoveIds.contains((e as Map)['id'] as int))
        .toList();
    final newWithdrawals = withdrawalList
        .where(
          (e) =>
              (e as Map)['location_id'] != locationId ||
              (((e)['phase'] ?? LocationMaterialModel.phaseFirstFix) != phase),
        )
        .toList();

    await prefs.setString(_projectStockKey, jsonEncode(stockList));
    await prefs.setString(_projectStockLedgerKey, jsonEncode(newLedger));
    await prefs.setString(_locationWithdrawalKey, jsonEncode(newWithdrawals));
  }

  Future<List<UnitModel>> getUnits(int buildingId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_unitsKey)!) as List)
        .where((e) => (e as Map)['building_id'] == buildingId)
        .toList();
    return list
        .map((m) => UnitModel.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addUnit(UnitModel u) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_unitsKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'building_id': u.buildingId,
      'name': u.name,
      'model': u.model,
      'image_path': u.imagePath,
    });
    await prefs.setString(_unitsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> updateUnit(UnitModel u) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_unitsKey)!) as List;
    for (var i = 0; i < list.length; i++) {
      if ((list[i] as Map)['id'] == u.id) {
        list[i] = {
          'id': u.id,
          'building_id': u.buildingId,
          'name': u.name,
          'model': u.model,
          'image_path': u.imagePath,
        };
        break;
      }
    }
    await prefs.setString(_unitsKey, jsonEncode(list));
  }

  Future<void> deleteUnit(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_unitsKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_unitsKey, jsonEncode(list));
  }

  Future<List<BuildingMaterialModel>> getBuildingMaterials(
    int buildingId,
  ) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List)
        .where((e) => (e as Map)['building_id'] == buildingId)
        .toList();
    return list
        .map(
          (m) => BuildingMaterialModel.fromMap(
            Map<String, dynamic>.from(m as Map),
          ),
        )
        .toList()
      ..sort((a, b) => a.materialName.compareTo(b.materialName));
  }

  Future<int> addBuildingMaterial(BuildingMaterialModel m) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
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
    final list = (jsonDecode(prefs.getString(_buildingMaterialsKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_buildingMaterialsKey, jsonEncode(list));
  }

  Future<List<BuildingCutlistModel>> getBuildingCutlists(int buildingId) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingCutlistKey)!) as List)
        .where((e) => (e as Map)['building_id'] == buildingId)
        .toList();
    return list
        .map(
          (m) =>
              BuildingCutlistModel.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList();
  }

  Future<int> addBuildingCutlist(BuildingCutlistModel c) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_buildingCutlistKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    list.add({
      'id': nextId,
      'building_id': c.buildingId,
      'image_path': c.imagePath,
    });
    await prefs.setString(_buildingCutlistKey, jsonEncode(list));
    return nextId;
  }

  Future<void> deleteBuildingCutlist(int id) async {
    await _initData();
    final prefs = await _prefs;
    final list = (jsonDecode(prefs.getString(_buildingCutlistKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_buildingCutlistKey, jsonEncode(list));
  }

  Future<List<SupervisorModel>> getSupervisors() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_supervisorsKey)!) as List;
    return list
        .map(
          (m) => SupervisorModel.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addSupervisor(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_supervisorsKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
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
    final list = (jsonDecode(prefs.getString(_supervisorsKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_supervisorsKey, jsonEncode(list));
  }

  Future<List<ContractorModel>> getContractors() async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_contractorsKey)!) as List;
    return list
        .map(
          (m) => ContractorModel.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addContractor(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_contractorsKey)!) as List;
    final nextId = list.isEmpty
        ? 1
        : (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
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
    final list = (jsonDecode(prefs.getString(_contractorsKey)!) as List)
        .where((e) => (e as Map)['id'] != id)
        .toList();
    await prefs.setString(_contractorsKey, jsonEncode(list));
  }

  Future<int> addMaterial(String name) async {
    await _initData();
    final prefs = await _prefs;
    final list = jsonDecode(prefs.getString(_materialsKey)!) as List;
    if (list.isNotEmpty && list[0] is Map) {
      final nextId =
          (list
              .map((e) => (e as Map)['id'] as int)
              .reduce((a, b) => a > b ? a : b)) +
          1;
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

  Future<List<WorkPhaseModel>> getWorkPhases() async {
    return const [
      WorkPhaseModel(id: 1, name: 'تركيب اكسسوارات'),
      WorkPhaseModel(id: 2, name: 'تقطيع WPC'),
      WorkPhaseModel(id: 3, name: 'تركيب WPC'),
      WorkPhaseModel(id: 4, name: 'معالجة'),
      WorkPhaseModel(id: 5, name: 'دهان'),
      WorkPhaseModel(id: 6, name: 'تشوين'),
      WorkPhaseModel(id: 7, name: 'تركيب ارضيات'),
      WorkPhaseModel(id: 8, name: 'تركيب Q.round + وزر'),
    ];
  }

  Future<int> addDetailedReport(DetailedReportModel report) async {
    throw UnimplementedError(
      'التقرير المفصل يتطلب الاتصال بالخادم. يرجى ضبط config.json.',
    );
  }

  Future<void> updateDetailedReport(
    int reportId,
    DetailedReportModel report,
  ) async {
    throw UnimplementedError(
      'تعديل التقرير المفصل يتطلب الاتصال بالخادم. يرجى ضبط config.json.',
    );
  }

  Future<void> patchDetailedReportExpenses({
    required int reportId,
    required int userId,
    required List<ExpenseItem> expenses,
  }) async {
    throw UnimplementedError(
      'تعديل الماليات يتطلب الاتصال بالخادم. يرجى ضبط config.json.',
    );
  }

  Future<List<DetailedReportModel>> getDetailedReports({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? userId,
    int? projectId,
  }) async {
    return [];
  }

  Future<void> deleteDetailedReport(int id) async {
    throw UnimplementedError('حذف التقرير المفصل يتطلب الاتصال بالخادم.');
  }

  Future<List<LocationWithdrawalForPeriodModel>>
  getLocationWithdrawalsForPeriod({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    return [];
  }

  Future<List<IrMirUploadModel>> listIrMirUploads({
    required int projectId,
    String? kind,
    String? mirName,
    int? locationId,
    String? phase,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_irMirUploadsKey) ?? '[]';
    final list = jsonDecode(raw) as List<dynamic>;
    Iterable<Map<String, dynamic>> rows = list.map((e) => Map<String, dynamic>.from(e as Map)).where((m) {
      final pid = m['project_id'];
      final p = pid is int ? pid : int.tryParse(pid?.toString() ?? '');
      return p == projectId;
    });
    if (kind == IrMirUploadModel.kindMir || kind == IrMirUploadModel.kindIr) {
      rows = rows.where((m) => m['kind'] == kind);
    }
    if (mirName != null && mirName.trim().isNotEmpty) {
      final t = mirName.trim().toLowerCase();
      rows = rows.where(
        (m) => (m['mir_name']?.toString().trim().toLowerCase() ?? '') == t,
      );
    }
    if (locationId != null) {
      rows = rows.where((m) {
        final lid = m['location_id'];
        final l = lid == null ? null : (lid is int ? lid : int.tryParse(lid.toString()));
        return l == locationId;
      });
    }
    if (phase != null && phase.trim().isNotEmpty) {
      final p = phase.trim().toLowerCase();
      rows = rows.where(
        (m) => (m['phase']?.toString().trim().toLowerCase() ?? '') == p,
      );
    }
    final out = rows.map(IrMirUploadModel.fromMap).toList();
    out.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      if (c != 0) return c;
      return b.id.compareTo(a.id);
    });
    return out;
  }

  Future<int> addIrMirUpload({
    required int projectId,
    required int userId,
    required String userName,
    required String kind,
    String? mirName,
    int? locationId,
    String? phase,
    required String fileName,
    required String fileMime,
    required String fileData,
    String? notes,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_irMirUploadsKey) ?? '[]';
    final list = jsonDecode(raw) as List<dynamic>;
    var nextId = 1;
    if (list.isNotEmpty) {
      nextId = (list
                  .map((e) => (e as Map)['id'] as int)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    }
    list.add({
      'id': nextId,
      'project_id': projectId,
      'user_id': userId,
      'user_name': userName,
      'kind': kind,
      'mir_name': mirName,
      'location_id': locationId,
      'phase': phase,
      'file_name': fileName,
      'file_mime': fileMime,
      'file_data': fileData,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_irMirUploadsKey, jsonEncode(list));
    return nextId;
  }

  Future<void> deleteIrMirUpload(int id, {String? requesterEmail}) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_irMirUploadsKey) ?? '[]';
    final list = jsonDecode(raw) as List<dynamic>;
    final next = <dynamic>[];
    var found = false;
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final eid = m['id'] is int
          ? m['id'] as int
          : int.tryParse(m['id']?.toString() ?? '') ?? 0;
      if (eid == id) {
        found = true;
        continue;
      }
      next.add(e);
    }
    if (!found) throw Exception('المرفق غير موجود');
    await prefs.setString(_irMirUploadsKey, jsonEncode(next));
  }

  bool _includeMsSdAudit(String? requesterEmail) =>
      (requesterEmail ?? '').trim().toLowerCase() ==
      UserModel.primaryAppAdminEmail.toLowerCase();

  List<Map<String, dynamic>> _readMsSdRecordsRaw(SharedPreferences prefs) {
    final raw = prefs.getString(_msSdRecordsKey) ?? '[]';
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _writeMsSdRecordsRaw(
    SharedPreferences prefs,
    List<Map<String, dynamic>> list,
  ) async {
    await prefs.setString(_msSdRecordsKey, jsonEncode(list));
  }

  Future<List<MsSdRecordModel>> listMsSdRecords({
    required int projectId,
    required String kind,
    String? requesterEmail,
  }) async {
    final prefs = await _prefs;
    final includeAudit = _includeMsSdAudit(requesterEmail);
    final rows = _readMsSdRecordsRaw(prefs)
        .where(
          (m) =>
              (m['project_id'] == projectId || m['projectId'] == projectId) &&
              (m['kind']?.toString().toLowerCase() ?? '') == kind.toLowerCase(),
        )
        .toList();
    rows.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final c = db.compareTo(da);
      if (c != 0) return c;
      final ia = a['id'] is int
          ? a['id'] as int
          : int.tryParse(a['id']?.toString() ?? '') ?? 0;
      final ib = b['id'] is int
          ? b['id'] as int
          : int.tryParse(b['id']?.toString() ?? '') ?? 0;
      return ib.compareTo(ia);
    });
    return rows.map((m) {
      final map = Map<String, dynamic>.from(m);
      if (!includeAudit) {
        map.remove('user_id');
        map.remove('userId');
        map.remove('user_name');
        map.remove('userName');
        map.remove('created_at');
        map.remove('createdAt');
      }
      return MsSdRecordModel.fromMap(map);
    }).toList();
  }

  Future<int> addMsSdRecord({
    required int projectId,
    required int userId,
    required String userName,
    required String kind,
    required String recordName,
    String? notes,
    required List<Map<String, String>> attachments,
  }) async {
    final prefs = await _prefs;
    final list = _readMsSdRecordsRaw(prefs);
    var nextId = 1;
    if (list.isNotEmpty) {
      nextId = list
              .map(
                (e) => e['id'] is int
                    ? e['id'] as int
                    : int.tryParse(e['id']?.toString() ?? '') ?? 0,
              )
              .reduce((a, b) => a > b ? a : b) +
          1;
    }
    final createdAt = DateTime.now().toIso8601String();
    var nextAttId = 1;
    for (final rec in list) {
      final atts = rec['attachments'];
      if (atts is List) {
        for (final a in atts) {
          if (a is Map) {
            final id = a['id'] is int
                ? a['id'] as int
                : int.tryParse(a['id']?.toString() ?? '') ?? 0;
            if (id >= nextAttId) nextAttId = id + 1;
          }
        }
      }
    }
    final attOut = <Map<String, dynamic>>[];
    for (final att in attachments) {
      attOut.add({
        'id': nextAttId,
        'record_id': nextId,
        'file_name': att['fileName'],
        'file_mime': att['fileMime'],
        'file_data': att['fileData'],
        'created_at': createdAt,
      });
      nextAttId += 1;
    }
    list.add({
      'id': nextId,
      'project_id': projectId,
      'user_id': userId,
      'user_name': userName,
      'kind': kind,
      'record_name': recordName,
      'notes': notes,
      'created_at': createdAt,
      'attachments': attOut,
    });
    await _writeMsSdRecordsRaw(prefs, list);
    return nextId;
  }

  Future<void> updateMsSdRecord(
    int id, {
    required String requesterEmail,
    String? recordName,
    String? notes,
    List<int>? removeAttachmentIds,
    List<Map<String, String>>? addAttachments,
  }) async {
    if (!_includeMsSdAudit(requesterEmail)) {
      throw Exception('غير مصرح بتعديل السجل');
    }
    final prefs = await _prefs;
    final list = _readMsSdRecordsRaw(prefs);
    final idx = list.indexWhere((m) {
      final eid = m['id'] is int
          ? m['id'] as int
          : int.tryParse(m['id']?.toString() ?? '') ?? 0;
      return eid == id;
    });
    if (idx < 0) throw Exception('السجل غير موجود');
    final rec = Map<String, dynamic>.from(list[idx]);
    if (recordName != null) rec['record_name'] = recordName;
    if (notes != null) rec['notes'] = notes;
    final atts = (rec['attachments'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (removeAttachmentIds != null && removeAttachmentIds.isNotEmpty) {
      atts.removeWhere((a) {
        final aid = a['id'] is int
            ? a['id'] as int
            : int.tryParse(a['id']?.toString() ?? '') ?? 0;
        return removeAttachmentIds.contains(aid);
      });
    }
    if (addAttachments != null && addAttachments.isNotEmpty) {
      var nextAttId = 1;
      for (final a in atts) {
        final aid = a['id'] is int
            ? a['id'] as int
            : int.tryParse(a['id']?.toString() ?? '') ?? 0;
        if (aid >= nextAttId) nextAttId = aid + 1;
      }
      final now = DateTime.now().toIso8601String();
      for (final att in addAttachments) {
        atts.add({
          'id': nextAttId,
          'record_id': id,
          'file_name': att['fileName'],
          'file_mime': att['fileMime'],
          'file_data': att['fileData'],
          'created_at': now,
        });
        nextAttId += 1;
      }
    }
    if (atts.isEmpty) {
      throw Exception('يجب أن يبقى مرفق واحد على الأقل');
    }
    rec['attachments'] = atts;
    list[idx] = rec;
    await _writeMsSdRecordsRaw(prefs, list);
  }

  Future<void> deleteMsSdRecord(int id, {required String requesterEmail}) async {
    if (!_includeMsSdAudit(requesterEmail)) {
      throw Exception('غير مصرح بحذف السجل');
    }
    final prefs = await _prefs;
    final list = _readMsSdRecordsRaw(prefs);
    final next = list.where((m) {
      final eid = m['id'] is int
          ? m['id'] as int
          : int.tryParse(m['id']?.toString() ?? '') ?? 0;
      return eid != id;
    }).toList();
    if (next.length == list.length) throw Exception('السجل غير موجود');
    await _writeMsSdRecordsRaw(prefs, next);
  }

  List<Map<String, dynamic>> _readMosItpRecordsRaw(SharedPreferences prefs) {
    final raw = prefs.getString(_mosItpRecordsKey) ?? '[]';
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _writeMosItpRecordsRaw(
    SharedPreferences prefs,
    List<Map<String, dynamic>> list,
  ) async {
    await prefs.setString(_mosItpRecordsKey, jsonEncode(list));
  }

  Future<List<MosItpRecordModel>> listMosItpRecords({
    required int projectId,
    required String kind,
    String? requesterEmail,
  }) async {
    final prefs = await _prefs;
    final includeAudit = _includeMsSdAudit(requesterEmail);
    final rows = _readMosItpRecordsRaw(prefs)
        .where(
          (m) =>
              (m['project_id'] == projectId || m['projectId'] == projectId) &&
              (m['kind']?.toString().toLowerCase() ?? '') == kind.toLowerCase(),
        )
        .toList();
    rows.sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final c = db.compareTo(da);
      if (c != 0) return c;
      final ia = a['id'] is int
          ? a['id'] as int
          : int.tryParse(a['id']?.toString() ?? '') ?? 0;
      final ib = b['id'] is int
          ? b['id'] as int
          : int.tryParse(b['id']?.toString() ?? '') ?? 0;
      return ib.compareTo(ia);
    });
    return rows.map((m) {
      final map = Map<String, dynamic>.from(m);
      if (!includeAudit) {
        map.remove('user_id');
        map.remove('userId');
        map.remove('user_name');
        map.remove('userName');
        map.remove('created_at');
        map.remove('createdAt');
      }
      return MosItpRecordModel.fromMap(map);
    }).toList();
  }

  Future<int> addMosItpRecord({
    required int projectId,
    required int userId,
    required String userName,
    required String kind,
    required String recordName,
    String? notes,
    required List<Map<String, String>> attachments,
  }) async {
    final prefs = await _prefs;
    final list = _readMosItpRecordsRaw(prefs);
    var nextId = 1;
    if (list.isNotEmpty) {
      nextId = list
              .map(
                (e) => e['id'] is int
                    ? e['id'] as int
                    : int.tryParse(e['id']?.toString() ?? '') ?? 0,
              )
              .reduce((a, b) => a > b ? a : b) +
          1;
    }
    final createdAt = DateTime.now().toIso8601String();
    var nextAttId = 1;
    for (final rec in list) {
      final atts = rec['attachments'];
      if (atts is List) {
        for (final a in atts) {
          if (a is Map) {
            final id = a['id'] is int
                ? a['id'] as int
                : int.tryParse(a['id']?.toString() ?? '') ?? 0;
            if (id >= nextAttId) nextAttId = id + 1;
          }
        }
      }
    }
    final attOut = <Map<String, dynamic>>[];
    for (final att in attachments) {
      attOut.add({
        'id': nextAttId,
        'record_id': nextId,
        'file_name': att['fileName'],
        'file_mime': att['fileMime'],
        'file_data': att['fileData'],
        'created_at': createdAt,
      });
      nextAttId += 1;
    }
    list.add({
      'id': nextId,
      'project_id': projectId,
      'user_id': userId,
      'user_name': userName,
      'kind': kind,
      'record_name': recordName,
      'notes': notes,
      'created_at': createdAt,
      'attachments': attOut,
    });
    await _writeMosItpRecordsRaw(prefs, list);
    return nextId;
  }

  Future<void> updateMosItpRecord(
    int id, {
    required String requesterEmail,
    String? recordName,
    String? notes,
    List<int>? removeAttachmentIds,
    List<Map<String, String>>? addAttachments,
  }) async {
    if (!_includeMsSdAudit(requesterEmail)) {
      throw Exception('غير مصرح بتعديل السجل');
    }
    final prefs = await _prefs;
    final list = _readMosItpRecordsRaw(prefs);
    final idx = list.indexWhere((m) {
      final eid = m['id'] is int
          ? m['id'] as int
          : int.tryParse(m['id']?.toString() ?? '') ?? 0;
      return eid == id;
    });
    if (idx < 0) throw Exception('السجل غير موجود');
    final rec = Map<String, dynamic>.from(list[idx]);
    if (recordName != null) rec['record_name'] = recordName;
    if (notes != null) rec['notes'] = notes;
    final atts = (rec['attachments'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (removeAttachmentIds != null && removeAttachmentIds.isNotEmpty) {
      atts.removeWhere((a) {
        final aid = a['id'] is int
            ? a['id'] as int
            : int.tryParse(a['id']?.toString() ?? '') ?? 0;
        return removeAttachmentIds.contains(aid);
      });
    }
    if (addAttachments != null && addAttachments.isNotEmpty) {
      var nextAttId = 1;
      for (final a in atts) {
        final aid = a['id'] is int
            ? a['id'] as int
            : int.tryParse(a['id']?.toString() ?? '') ?? 0;
        if (aid >= nextAttId) nextAttId = aid + 1;
      }
      final now = DateTime.now().toIso8601String();
      for (final att in addAttachments) {
        atts.add({
          'id': nextAttId,
          'record_id': id,
          'file_name': att['fileName'],
          'file_mime': att['fileMime'],
          'file_data': att['fileData'],
          'created_at': now,
        });
        nextAttId += 1;
      }
    }
    if (atts.isEmpty) {
      throw Exception('يجب أن يبقى مرفق واحد على الأقل');
    }
    rec['attachments'] = atts;
    list[idx] = rec;
    await _writeMosItpRecordsRaw(prefs, list);
  }

  Future<void> deleteMosItpRecord(int id, {required String requesterEmail}) async {
    if (!_includeMsSdAudit(requesterEmail)) {
      throw Exception('غير مصرح بحذف السجل');
    }
    final prefs = await _prefs;
    final list = _readMosItpRecordsRaw(prefs);
    final next = list.where((m) {
      final eid = m['id'] is int
          ? m['id'] as int
          : int.tryParse(m['id']?.toString() ?? '') ?? 0;
      return eid != id;
    }).toList();
    if (next.length == list.length) throw Exception('السجل غير موجود');
    await _writeMosItpRecordsRaw(prefs, next);
  }

  Never _withdrawalRequestsUnsupported() {
    throw UnsupportedError(
      'طلبات سحب الخامات تتطلب الاتصال بخادم API (apiBaseUrl في الإعدادات).',
    );
  }

  Future<WithdrawalRequestModel> createWithdrawalRequest({
    required int projectId,
    required int locationId,
    required String phase,
    required int engineerUserId,
    required String engineerUserName,
    required String locationPathLabel,
  }) async {
    _withdrawalRequestsUnsupported();
  }

  Future<List<WithdrawalRequestModel>> getWithdrawalRequestsForEngineerProject({
    required int projectId,
    required int engineerUserId,
  }) async {
    _withdrawalRequestsUnsupported();
  }

  Future<WithdrawalRequestModel?> getOpenWithdrawalRequestForLocationPhase({
    required int locationId,
    required String phase,
  }) async {
    _withdrawalRequestsUnsupported();
  }

  Future<int> countPendingWithdrawalActionsForManager({
    required int userId,
    required String role,
  }) async {
    return 0;
  }

  Future<List<WithdrawalRequestModel>> listPendingWithdrawalActionsForManager({
    required int userId,
    required String role,
  }) async {
    return [];
  }

  Future<void> respondWithdrawalRequest({
    required int requestId,
    required int managerUserId,
    required bool approve,
    String? reason,
  }) async {
    _withdrawalRequestsUnsupported();
  }

  Future<void> fulfillWithdrawalRequest({
    required int requestId,
    required int engineerUserId,
  }) async {
    _withdrawalRequestsUnsupported();
  }

  /// حذف خطط العمل والهيكلة والمخازن والسحوبات والحضور في تخزين الويب.
  Future<Map<String, int>> purgeOperationalData() async {
    await _initData();
    final prefs = await _prefs;
    final keys = <String, String>{
      'attendance_records': _attendanceKey,
      'contractors': _contractorsKey,
      'projects': _projectsKey,
      'project_locations': _projectLocationsKey,
      'zones': _zonesKey,
      'buildings': _buildingsKey,
      'units': _unitsKey,
      'building_materials': _buildingMaterialsKey,
      'building_cutlist_images': _buildingCutlistKey,
      'project_stock': _projectStockKey,
      'project_stock_ledger': _projectStockLedgerKey,
      'location_materials': _locationMaterialsKey,
      'location_withdrawal': _locationWithdrawalKey,
      'ir_mir_uploads': _irMirUploadsKey,
    };
    final before = <String, int>{};
    for (final entry in keys.entries) {
      final raw = prefs.getString(entry.value) ?? '[]';
      final list = jsonDecode(raw) as List;
      before[entry.key] = list.length;
      await prefs.setString(entry.value, jsonEncode(<Map<String, dynamic>>[]));
    }
    return before;
  }

  Future<bool> checkReportsSysNameAvailable({
    required String name,
    int? excludeId,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<int> countPendingReportsSys(int userId) async => 0;

  Future<List<ReportsSysModel>> listReportsSysInbox({
    required int userId,
    required String tab,
    String? requesterEmail,
    String? searchQuery,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<ReportsSysModel> getReportsSysDetail(int reportId) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<Map<String, String>> getReportsSysAttachmentData({
    required int reportId,
    required int attachmentId,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<ReportsSysModel> createReportsSys({
    required int userId,
    required String reportName,
    required String reportType,
    required String summary,
    String? notes,
    int? sourceReportId,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<ReportsSysModel> updateReportsSys({
    required int reportId,
    required int userId,
    required String reportName,
    required String reportType,
    required String summary,
    String? notes,
    List<Map<String, dynamic>>? attachments,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<ReportsSysModel> submitReportsSys({
    required int reportId,
    required int userId,
    required int toUserId,
    String? comment,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<ReportsSysModel> respondReportsSys({
    required int reportId,
    required int userId,
    required String action,
    int? toUserId,
    String? comment,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');

  Future<ReportsSysModel> relaunchReportsSys({
    required int sourceReportId,
    required int userId,
    required String reportName,
  }) async =>
      throw UnsupportedError('Reports-SYS requires API mode');
}
