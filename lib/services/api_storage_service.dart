import 'dart:convert';
import 'dart:typed_data';

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
import '../models/notification_attachment_model.dart';
import '../models/notification_item_model.dart';
import '../models/shop_darwing_notification_model.dart';
import '../models/meeting_model.dart';
import '../models/meeting_notification_model.dart';
import '../models/ir_mir_upload_model.dart';
import '../models/ms_sd_record_model.dart';
import '../models/mos_itp_record_model.dart';
import '../models/withdrawal_request_model.dart';
import '../models/pending_postpone_fine_action_model.dart';
import '../models/postpone_fine_report_row_model.dart';
import '../models/material_withdrawal_report_row_model.dart';
import '../models/uploaded_file_report_row_model.dart';
import '../models/reports_sys_model.dart';
import '../models/shop_drawing_model.dart';
import '../models/app_release_info_model.dart';
import '../models/projects_dashboard_note_model.dart';
import '../models/projects_dashboard_sheet_model.dart';
import '../models/expense_statement_model.dart';
import 'home_icon_order_service.dart';
import 'icon_visibility_service.dart';
import 'withdrawal_stock_validation.dart';
import '../data/materials_display.dart';
import 'attendance_duplicate_guard.dart';

/// Storage implementation that uses the REST API (PostgreSQL backend).
class ApiStorageService {
  final String baseUrl;
  static const Duration _hotCounterCacheTtl = Duration(seconds: 20);
  final Map<String, ({DateTime at, int value})> _intCache = {};
  final Map<String, ({DateTime at, AppReleaseInfoModel value})> _appReleaseCache = {};

  ApiStorageService(this.baseUrl);

  String _path(String segment) =>
      baseUrl.endsWith('/') ? '$baseUrl$segment' : '$baseUrl/$segment';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Exception _apiHttpException(http.Response r, {String? path}) {
    final body = r.body.trim();
    final htmlRouteMissing = body.contains('<pre>Cannot GET') ||
        body.contains('<pre>Cannot POST') ||
        body.contains('<pre>Cannot PATCH') ||
        body.contains('<pre>Cannot DELETE');
    final isHtml = body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        htmlRouteMissing;
    final p = path ?? '';
    if (r.statusCode == 404 && isHtml) {
      if (p.contains('ms-sd') || p.contains('mos-itp')) {
        return Exception(
          'الخادم على Render لا يتضمن مسارات MS-SD / MoS-ITP بعد (404).\n'
          'يجب نشر آخر نسخة من backend/server.js على خدمة wood-more-api ثم إعادة المحاولة.',
        );
      }
      if (p.startsWith('reports/')) {
        return Exception(
          'الخادم لا يتضمن مسارات تقارير السحب والمرفقات بعد (404).\n'
          'يجب نشر آخر نسخة من backend على الخادم ثم إعادة المحاولة.',
        );
      }
      if (p.contains('shop-drawing')) {
        return Exception(
          'الخادم لا يتضمن مسارات Shop-Drawing & PO بعد (404).\n'
          'للتجربة محلياً: شغّل backend (node server.js) واضبط web/config.json على http://localhost:3000\n'
          'أو انشر آخر نسخة من backend على Render.',
        );
      }
      return Exception(
        'المسار غير موجود على الخادم (404)${p.isNotEmpty ? ': $p' : ''}',
      );
    }
    if (isHtml) {
      return Exception('خطأ من الخادم (${r.statusCode}). تحقق من نشر API محدّث.');
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return Exception(decoded['error'].toString());
      }
    } catch (_) {}
    return Exception(body.isNotEmpty ? body : 'HTTP ${r.statusCode}');
  }

  Future<http.Response> _httpGet(Uri uri, {int attempts = 3}) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        return await http.get(uri);
      } catch (error) {
        lastError = error;
        if (attempt + 1 >= attempts) break;
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('request failed');
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final uri = Uri.parse(_path(path));
    final r = await _httpGet(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    return r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _getList(String path) async {
    final uri = Uri.parse(_path(path));
    final r = await _httpGet(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    final decoded = jsonDecode(r.body);
    if (decoded == null) return [];
    return decoded is List ? decoded as List<dynamic> : [];
  }

  Future<List<dynamic>?> _tryGetList(String path) async {
    final uri = Uri.parse(_path(path));
    final r = await _httpGet(uri);
    if (r.statusCode == 400) return null;
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null) return const [];
    return decoded is List ? decoded as List<dynamic> : const [];
  }

  Future<List<T>> _boundedWait<T>(
    List<Future<T>> futures, {
    int batchSize = 6,
  }) async {
    if (futures.isEmpty) return const [];
    final out = <T>[];
    for (var i = 0; i < futures.length; i += batchSize) {
      final end = i + batchSize < futures.length ? i + batchSize : futures.length;
      out.addAll(await Future.wait(futures.sublist(i, end)));
    }
    return out;
  }

  int? _readCachedInt(String key) {
    final hit = _intCache[key];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > _hotCounterCacheTtl) {
      _intCache.remove(key);
      return null;
    }
    return hit.value;
  }

  int _storeCachedInt(String key, int value) {
    _intCache[key] = (at: DateTime.now(), value: value);
    return value;
  }

  AppReleaseInfoModel? _readCachedRelease(String key) {
    final hit = _appReleaseCache[key];
    if (hit == null) return null;
    if (DateTime.now().difference(hit.at) > _hotCounterCacheTtl) {
      _appReleaseCache.remove(key);
      return null;
    }
    return hit.value;
  }

  AppReleaseInfoModel _storeCachedRelease(String key, AppReleaseInfoModel value) {
    _appReleaseCache[key] = (at: DateTime.now(), value: value);
    return value;
  }

  Future<int> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_path(path));
    final r = await http.post(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    if (r.body.isEmpty) return 0;
    final decoded = jsonDecode(r.body);
    return decoded is int ? decoded : int.tryParse(decoded.toString()) ?? 0;
  }

  Future<void> _postVoid(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_path(path));
    final r = await http.post(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<void> _put(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_path(path));
    final r = await http.put(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<void> _delete(String path) async {
    final uri = Uri.parse(_path(path));
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final uri = Uri.parse(
      _path('users/by-email'),
    ).replace(queryParameters: {'email': email});
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null) return null;
    final m = decoded as Map<String, dynamic>;
    return UserModel.fromMap(m);
  }

  /// التحقق من تسجيل الدخول (بريد + كلمة سر) عبر API
  Future<UserModel?> validateLogin(String email, String password) async {
    final uri = Uri.parse(_path('auth/login'));
    final r = await http.post(
      uri,
      body: jsonEncode({'email': email.trim(), 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode == 401) return null;
    if (r.statusCode == 423) {
      throw Exception('System Locked for maintainance please try again later');
    }
    if (r.statusCode != 200) {
      var detail = 'تعذر الاتصال بالخادم (${r.statusCode})';
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['error'] != null) {
          detail = '$detail: ${decoded['error']}';
        }
      } catch (_) {}
      throw Exception(detail);
    }
    if (r.body.isEmpty) return null;
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! Map<String, dynamic>) return null;
    return UserModel.fromMap(decoded);
  }

  Future<bool> isSystemLocked() async {
    try {
      final data = await _get('system-lock');
      return data['locked'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setSystemLocked(
    bool locked, {
    String? requesterEmail,
  }) async {
    await _put('system-lock', {
      'locked': locked,
      if (requesterEmail != null)
        'requesterEmail': requesterEmail.trim().toLowerCase(),
    });
  }

  Future<Map<String, Map<String, bool>>> getHomeIconsVisibilityConfig() async {
    final uri = Uri.parse(_path('home-icons-visibility'));
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = r.body.isEmpty ? null : jsonDecode(r.body);
    if (decoded is Map<String, dynamic>)
      return IconVisibilityService.normalizeAllConfig(decoded);
    if (decoded is Map)
      return IconVisibilityService.normalizeAllConfig(
        Map<String, dynamic>.from(decoded),
      );
    return IconVisibilityService.normalizeAllConfig(null);
  }

  Future<void> setHomeIconsVisibilityForRole({
    required String requesterEmail,
    required String role,
    required Map<String, bool> roleConfig,
  }) async {
    await _put('home-icons-visibility/$role', {
      'requesterEmail': requesterEmail.trim().toLowerCase(),
      'icons': roleConfig,
    });
  }

  Future<List<String>> getUserHomeIconOrder(int userId) async {
    final uri = Uri.parse(_path('users/$userId/home-icon-order'));
    final r = await _httpGet(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = r.body.isEmpty ? null : jsonDecode(r.body);
    if (decoded is Map) {
      return sanitizeSavedHomeIconOrder(decoded['iconOrder'] as List<dynamic>?);
    }
    return const [];
  }

  Future<void> setUserHomeIconOrder({
    required int userId,
    required List<String> iconOrder,
  }) async {
    await _put('users/$userId/home-icon-order', {
      'requesterUserId': userId,
      'iconOrder': iconOrder,
    });
  }

  Future<List<UserModel>> getSiteEngineers() async {
    final list = await _getList('users/site-engineers');
    return list
        .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<UserModel>> getUsers({String? requesterEmail}) async {
    final path = (requesterEmail != null && requesterEmail.trim().isNotEmpty)
        ? 'users?requesterEmail=${Uri.encodeQueryComponent(requesterEmail.trim().toLowerCase())}'
        : 'users';
    final list = await _getList(path);
    return list
        .map((e) => UserModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> addUser(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final body = <String, dynamic>{'name': name, 'email': email, 'role': role};
    if (password.trim().isNotEmpty) body['password'] = password.trim();
    return _post('users', body);
  }

  Future<void> updateUser(
    int id,
    String name,
    String email,
    String role, [
    String? password,
    String? requesterEmail,
  ]) async {
    final body = <String, dynamic>{'name': name, 'email': email, 'role': role};
    if (password != null && password.trim().isNotEmpty)
      body['password'] = password.trim();
    if (requesterEmail != null && requesterEmail.trim().isNotEmpty) {
      body['requesterEmail'] = requesterEmail.trim().toLowerCase();
    }
    await _put('users/$id', body);
  }

  Future<void> deleteUser(int id, {String? requesterEmail}) async {
    if (requesterEmail != null && requesterEmail.trim().isNotEmpty) {
      final uri = Uri.parse(_path('users/$id')).replace(
        queryParameters: {
          'requesterEmail': requesterEmail.trim().toLowerCase(),
        },
      );
      final r = await http.delete(uri);
      if (r.statusCode >= 400) {
        throw Exception(_deleteUserErrorMessage(r));
      }
      return;
    }
    final uri = Uri.parse(_path('users/$id'));
    final r = await http.delete(uri);
    if (r.statusCode >= 400) {
      throw Exception(_deleteUserErrorMessage(r));
    }
  }

  String _deleteUserErrorMessage(http.Response r) {
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is Map) {
        final message = decoded['message']?.toString();
        if (message != null && message.trim().isNotEmpty) return message.trim();
        final error = decoded['error']?.toString();
        if (error != null && error.trim().isNotEmpty) return error.trim();
      }
    } catch (_) {}
    return r.body;
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
    }).toList()..sort((a, b) {
      final byName = a.name.compareTo(b.name);
      if (byName != 0) return byName;
      return a.id.compareTo(b.id);
    });
  }

  static List<ProjectModel> _deduplicateProjectsByName(
    List<ProjectModel> list,
  ) {
    final seen = <String>{};
    return list.where((p) => seen.add(p.name)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<int> addProject(String name, {String mainContractor = ''}) async {
    return _post('projects', {
      'name': name,
      'main_contractor': mainContractor,
    });
  }

  Future<void> updateProject(
    int id,
    String name, {
    String mainContractor = '',
  }) async {
    await _put('projects/$id', {
      'name': name,
      'main_contractor': mainContractor,
    });
  }

  /// رقم طلب تسلسلي لأذن الصرف/التسليم (مثل 001)
  Future<String> nextDisbursementNoteNumber() async {
    final r = await _postReturnMap('disbursement-notes/next-number', {});
    if (r['number'] != null) return r['number'].toString();
    if (r['id'] != null) return r['id'].toString().padLeft(3, '0');
    return '001';
  }

  Future<void> deleteProject(int id) async {
    await _delete('projects/$id');
  }

  Future<List<ZoneModel>> getZones(int projectId) async {
    final list = await _getList('zones?projectId=$projectId');
    return list
        .map((e) => ZoneModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
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
    return list
        .map(
          (e) =>
              ProjectLocationModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<int> addProjectLocation({
    required int projectId,
    int? parentId,
    required String name,
    required String type,
    int displayOrder = 0,
  }) async {
    return _post('project-locations', {
      'projectId': projectId,
      'parentId': parentId,
      'name': name,
      'type': type,
      'display_order': displayOrder,
    });
  }

  Future<void> updateProjectLocation(
    int id, {
    String? name,
    int? displayOrder,
  }) async {
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
    return _post('buildings', {
      'zoneId': b.zoneId,
      'name': b.name,
      'storageInfo': b.storageInfo,
      'modelDetails': b.modelDetails,
      'cutList': b.cutList,
    });
  }

  Future<void> updateBuilding(BuildingModel b) async {
    await _put('buildings/${b.id}', {
      'name': b.name,
      'storageInfo': b.storageInfo,
      'modelDetails': b.modelDetails,
      'cutList': b.cutList,
    });
  }

  Future<void> deleteBuilding(int id) async {
    await _delete('buildings/$id');
  }

  Future<int> addAttendanceRecord(AttendanceRecordModel record) async {
    final uri = Uri.parse(_path('attendance'));
    final body = jsonEncode({
      'userId': record.userId,
      'userName': record.userName,
      'type': record.type,
      'dateTime': record.dateTime.toIso8601String(),
      'calendarDate': attendanceLocalCalendarDateKey(record.dateTime),
      'location': record.location,
      'projectId': record.projectId,
      'projectName': record.projectName,
      'notes': record.notes,
    });
    final r = await http.post(
      uri,
      body: body,
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode == 409) {
      String msg =
          'تم التسجيل مسبقاً لهذا المشروع اليوم. لا داعي لإعادة التسجيل مرة أخرى.';
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is Map && decoded['error'] != null) {
          msg = decoded['error'].toString();
        }
      } catch (_) {}
      throw DuplicateAttendanceException(msg);
    }
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return 0;
    final decoded = jsonDecode(r.body);
    return decoded is int ? decoded : int.tryParse(decoded.toString()) ?? 0;
  }

  Future<List<AttendanceRecordModel>> getAllAttendanceRecords() async {
    final list = await _getList('attendance');
    return list
        .map(
          (e) => AttendanceRecordModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecordsByUser(
    int userId,
  ) async {
    final list = await _getList('attendance/by-user/$userId');
    return list
        .map(
          (e) => AttendanceRecordModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
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
    await _delete('attendance/$id');
  }

  Future<List<NotificationItemModel>> getNotificationsForUser(
    int userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final list = await _getList(
      'notifications?userId=$userId&limit=$limit&offset=$offset',
    );
    return list
        .map(
          (e) => NotificationItemModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// سرد مرفقات سجل مرتبط بإشعار (بيانات وصفية فقط، بدون بايتات).
  Future<NotificationAttachmentList> getNotificationAttachments({
    required int userId,
    required String source,
    required int recordId,
  }) async {
    final data = await _get(
      'attachments?userId=$userId&source=$source&recordId=$recordId',
    );
    return NotificationAttachmentList.fromMap(data);
  }

  /// جلب بايتات مرفق واحد عند فتحه فعلياً.
  Future<NotificationAttachmentFile> getNotificationAttachmentFile({
    required int userId,
    required String source,
    required int recordId,
    required String attachmentId,
  }) async {
    final data = await _get(
      'attachments/file?userId=$userId&source=$source&recordId=$recordId'
      '&attachmentId=${Uri.encodeQueryComponent(attachmentId)}',
    );
    return NotificationAttachmentFile.fromMap(data);
  }

  Future<int> getUnreadNotificationsCount(int userId) async {
    final cacheKey = 'notifications/unread-count:$userId';
    final cached = _readCachedInt(cacheKey);
    if (cached != null) return cached;
    final data = await _get('notifications/unread-count?userId=$userId');
    final value = data['count'];
    if (value is int) return _storeCachedInt(cacheKey, value);
    return _storeCachedInt(cacheKey, int.tryParse('${value ?? 0}') ?? 0);
  }

  Future<void> markNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    await _put('notifications/$notificationId/read', {'userId': userId});
  }

  Future<void> deleteNotification({
    required int notificationId,
    required int userId,
  }) async {
    final uri = Uri.parse(_path('notifications/$notificationId')).replace(
      queryParameters: {'userId': '$userId'},
    );
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<List<ShopDarwingNotificationModel>> getShopDarwingNotifications(
    int userId,
  ) async {
    final list = await _getList('shop-darwing-notification?userId=$userId');
    return list
        .map(
          (e) => ShopDarwingNotificationModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<int> getUnreadShopDarwingNotificationsCount(int userId) async {
    final cacheKey = 'shop-darwing-notification/unread-count:$userId';
    final cached = _readCachedInt(cacheKey);
    if (cached != null) return cached;
    final data = await _get(
      'shop-darwing-notification/unread-count?userId=$userId',
    );
    return _storeCachedInt(cacheKey, (data['count'] as num?)?.toInt() ?? 0);
  }

  Future<void> markShopDarwingNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    await _put('shop-darwing-notification/$notificationId/read', {
      'userId': userId,
    });
  }

  Future<void> deleteShopDarwingNotification({
    required int notificationId,
    required int userId,
  }) async {
    final uri = Uri.parse(
      _path('shop-darwing-notification/$notificationId'),
    ).replace(queryParameters: {'userId': '$userId'});
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  String _meetingsUnreadCacheKey(int userId) =>
      'meetings-notifications/unread-count:$userId';

  Future<List<MeetingModel>> getMeetings({
    required int userId,
    String? query,
  }) async {
    final q = (query ?? '').trim();
    final path = q.isEmpty
        ? 'meetings?userId=$userId'
        : 'meetings?userId=$userId&q=${Uri.encodeQueryComponent(q)}';
    final list = await _getList(path);
    return list
        .map((e) => MeetingModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MeetingModel> getMeetingDetail({
    required int userId,
    required int meetingId,
  }) async {
    final data = await _get('meetings/$meetingId?userId=$userId');
    return MeetingModel.fromMap(data);
  }

  Future<MeetingModel> createMeeting({
    required int userId,
    required String meetingNumber,
    required String subject,
    required String scheduledAt,
    required String fileName,
    required String mimeType,
    required String dataBase64,
    required int sizeBytes,
  }) async {
    final uri = Uri.parse(_path('meetings'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'meeting_number': meetingNumber,
        'subject': subject,
        'scheduled_at': scheduledAt,
        'file_name': fileName,
        'mime_type': mimeType,
        'data_base64': dataBase64,
        'size_bytes': sizeBytes,
      }),
    );
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'meetings');
    return MeetingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<MeetingModel> uploadMeetingFile({
    required int userId,
    required int meetingId,
    required String fileType,
    required String fileName,
    required String mimeType,
    required String dataBase64,
    required int sizeBytes,
  }) async {
    final uri = Uri.parse(_path('meetings/$meetingId/files/$fileType'));
    final r = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'file_name': fileName,
        'mime_type': mimeType,
        'data_base64': dataBase64,
        'size_bytes': sizeBytes,
      }),
    );
    if (r.statusCode >= 400) {
      throw _apiHttpException(r, path: 'meetings/$meetingId/files/$fileType');
    }
    return MeetingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<Map<String, String>> getMeetingFileData({
    required int userId,
    required int meetingId,
    required String fileType,
  }) async {
    final data = await _get(
      'meetings/$meetingId/files/$fileType?userId=$userId',
    );
    return {
      'file_name': (data['file_name'] ?? '').toString(),
      'mime_type': (data['mime_type'] ?? 'application/pdf').toString(),
      'data_base64': (data['data_base64'] ?? '').toString(),
    };
  }

  Future<MeetingModel> deleteMeetingFile({
    required int userId,
    required int meetingId,
    required String fileType,
  }) async {
    final uri = Uri.parse(_path('meetings/$meetingId/files/$fileType')).replace(
      queryParameters: {'userId': '$userId'},
    );
    final r = await http.delete(uri);
    if (r.statusCode >= 400) {
      throw _apiHttpException(r, path: 'meetings/$meetingId/files/$fileType');
    }
    return MeetingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<void> deleteMeeting({
    required int userId,
    required int meetingId,
  }) async {
    final uri = Uri.parse(_path('meetings/$meetingId')).replace(
      queryParameters: {'userId': '$userId'},
    );
    final r = await http.delete(uri);
    if (r.statusCode >= 400) {
      throw _apiHttpException(r, path: 'meetings/$meetingId');
    }
  }

  Future<List<MeetingNotificationModel>> getMeetingsNotifications(
    int userId,
  ) async {
    final list = await _getList('meetings-notifications?userId=$userId');
    return list
        .map(
          (e) => MeetingNotificationModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<int> getUnreadMeetingsNotificationsCount(int userId) async {
    final cacheKey = _meetingsUnreadCacheKey(userId);
    final cached = _readCachedInt(cacheKey);
    if (cached != null) return cached;
    final data = await _get('meetings-notifications/unread-count?userId=$userId');
    return _storeCachedInt(cacheKey, (data['count'] as num?)?.toInt() ?? 0);
  }

  Future<void> markAllMeetingsNotificationsRead(int userId) async {
    await _put('meetings-notifications/read-all', {'userId': userId});
    _intCache.remove(_meetingsUnreadCacheKey(userId));
  }

  Future<void> markMeetingsNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    await _put('meetings-notifications/$notificationId/read', {
      'userId': userId,
    });
    _intCache.remove(_meetingsUnreadCacheKey(userId));
  }

  Future<void> deleteMeetingsNotification({
    required int notificationId,
    required int userId,
  }) async {
    final uri = Uri.parse(_path('meetings-notifications/$notificationId'))
        .replace(queryParameters: {'userId': '$userId'});
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<List<String>> getMaterials() async {
    final list = await _getList('materials');
    return sortMaterialsForDisplay(list.map((e) => e as String));
  }

  Future<List<Map<String, dynamic>>> getMaterialsWithIds() async {
    final list = await _getList('materials/with-ids');
    return sortMaterialRowsForDisplay(
      list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
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
    final r = await http.post(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
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
      'dateFrom': DateTime(
        dateFrom.year,
        dateFrom.month,
        dateFrom.day,
      ).toIso8601String(),
      'dateTo': DateTime(
        dateTo.year,
        dateTo.month,
        dateTo.day,
        23,
        59,
        59,
        999,
      ).toIso8601String(),
    };
    if (userId != null) params['userId'] = userId.toString();
    if (projectId != null) params['projectId'] = projectId.toString();
    final uri = Uri.parse(
      _path('daily-reports'),
    ).replace(queryParameters: params);
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
    return (decoded is num)
        ? decoded.toDouble()
        : double.tryParse(decoded.toString()) ?? 0;
  }

  Future<void> setEngineerBalance(int userId, double balance) async {
    await _postVoid('engineer-balance', {'userId': userId, 'balance': balance});
  }

  Future<void> addCustody(
    int userId,
    double amount,
    String note, [
    String? documentPath,
  ]) async {
    await _postVoid('custody', {
      'userId': userId,
      'amount': amount,
      'note': note,
      if (documentPath != null && documentPath.trim().isNotEmpty)
        'documentPath': documentPath.trim(),
    });
  }

  /// إرسال تقرير عمليات مع صوره (الصور إلزامية).
  Future<int> createOperationReport({
    required int userId,
    required String userName,
    int? projectId,
    String? projectName,
    required String reportType,
    required String details,
    required List<String> images,
  }) async {
    return _post('operation-reports', {
      'userId': userId,
      'userName': userName,
      if (projectId != null && projectId > 0) 'projectId': projectId,
      if (projectName != null && projectName.trim().isNotEmpty)
        'projectName': projectName.trim(),
      'reportType': reportType,
      'details': details,
      'images': images,
    });
  }

  /// تسجيل حركة إضافة رصيد أو سحب رصيد فقط (الخادم قد يدعم balance-movement)
  Future<void> addBalanceMovement(
    int userId,
    double amount,
    String note,
    String movementType, {
    int? actorUserId,
    String? actorUserName,
    String? actorRole,
  }) async {
    try {
      await _postVoid('balance-movement', {
        'userId': userId,
        'amount': amount,
        'note': note,
        'movementType': movementType,
        if (actorUserId != null) 'actorUserId': actorUserId,
        if (actorUserName != null && actorUserName.trim().isNotEmpty)
          'actorUserName': actorUserName.trim(),
        if (actorRole != null && actorRole.trim().isNotEmpty)
          'actorRole': actorRole.trim(),
      });
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getCustodyRecords({int? userId}) async {
    final path = userId != null ? 'custody?userId=$userId' : 'custody';
    final list = await _getList(path);
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      if (!m.containsKey('movement_type') && m.containsKey('movementType'))
        m['movement_type'] = m['movementType'];
      m['movement_type'] ??= 'custody';
      return m;
    }).toList();
  }

  Future<List<SupervisorModel>> getSupervisors() async {
    final list = await _getList('supervisors');
    return list
        .map(
          (e) => SupervisorModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
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
    return list
        .map(
          (e) => ContractorModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
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
    return list
        .map(
          (e) => ProjectStockModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<int> addProjectStock(ProjectStockModel s) async {
    return _post('project-stock', {
      'projectId': s.projectId,
      'materialName': s.materialName,
      'quantity': s.quantity,
      'unit': s.unit,
    });
  }

  Future<void> updateProjectStock(ProjectStockModel s) async {
    await _put('project-stock/${s.id}', {
      'materialName': s.materialName,
      'quantity': s.quantity,
      'unit': s.unit,
    });
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

  Future<List<ProjectStockLedgerModel>> getStockLedger(
    int projectId,
    String materialName,
  ) async {
    final list = await _getList(
      'project-stock-ledger?projectId=$projectId&materialName=${Uri.encodeComponent(materialName)}',
    );
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      if (!m.containsKey('project_id') && m.containsKey('projectId'))
        m['project_id'] = m['projectId'];
      if (!m.containsKey('material_name') && m.containsKey('materialName'))
        m['material_name'] = m['materialName'];
      if (!m.containsKey('quantity_delta') && m.containsKey('quantityDelta'))
        m['quantity_delta'] = m['quantityDelta'];
      if (!m.containsKey('created_at') && m.containsKey('createdAt'))
        m['created_at'] = m['createdAt'];
      if (!m.containsKey('user_id') && m.containsKey('userId'))
        m['user_id'] = m['userId'];
      if (!m.containsKey('user_name') && m.containsKey('userName'))
        m['user_name'] = m['userName'];
      return ProjectStockLedgerModel.fromMap(m);
    }).toList();
  }

  Future<List<UnitModel>> getUnits(int buildingId) async {
    final list = await _getList('units?buildingId=$buildingId');
    return list
        .map((e) => UnitModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// هوية الرافع تُرسل مع صور الوحدات/الخامات/الـCutlists لتظهر في إشعار الرفع.
  Map<String, dynamic> _actorFields(int? actorUserId, String? actorUserName) => {
        if (actorUserId != null) 'userId': actorUserId,
        if (actorUserName != null && actorUserName.trim().isNotEmpty)
          'userName': actorUserName.trim(),
      };

  Future<int> addUnit(
    UnitModel u, {
    int? actorUserId,
    String? actorUserName,
  }) async {
    return _post('units', {
      'buildingId': u.buildingId,
      'name': u.name,
      'model': u.model,
      'imagePath': u.imagePath,
      ..._actorFields(actorUserId, actorUserName),
    });
  }

  Future<void> updateUnit(
    UnitModel u, {
    int? actorUserId,
    String? actorUserName,
  }) async {
    await _put('units/${u.id}', {
      'name': u.name,
      'model': u.model,
      'imagePath': u.imagePath,
      ..._actorFields(actorUserId, actorUserName),
    });
  }

  Future<void> deleteUnit(int id) async {
    await _delete('units/$id');
  }

  Future<List<BuildingMaterialModel>> getBuildingMaterials(
    int buildingId,
  ) async {
    final list = await _getList('building-materials?buildingId=$buildingId');
    return list
        .map(
          (e) => BuildingMaterialModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<int> addBuildingMaterial(
    BuildingMaterialModel m, {
    int? actorUserId,
    String? actorUserName,
  }) async {
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
      ..._actorFields(actorUserId, actorUserName),
    });
  }

  Future<void> updateBuildingMaterial(
    BuildingMaterialModel m, {
    int? actorUserId,
    String? actorUserName,
  }) async {
    await _put('building-materials/${m.id}', {
      'materialName': m.materialName,
      'length': m.length,
      'piecesCount': m.piecesCount,
      'totalLength': m.totalLength,
      'totalArea': m.totalArea,
      'imagePath': m.imagePath,
      ..._actorFields(actorUserId, actorUserName),
    });
  }

  Future<void> deleteBuildingMaterial(int id) async {
    await _delete('building-materials/$id');
  }

  Future<List<BuildingCutlistModel>> getBuildingCutlists(int buildingId) async {
    final list = await _getList('building-cutlists?buildingId=$buildingId');
    return list
        .map(
          (e) =>
              BuildingCutlistModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<int> addBuildingCutlist(
    BuildingCutlistModel c, {
    int? actorUserId,
    String? actorUserName,
  }) async {
    return _post('building-cutlists', {
      'buildingId': c.buildingId,
      'imagePath': c.imagePath,
      ..._actorFields(actorUserId, actorUserName),
    });
  }

  Future<void> deleteBuildingCutlist(int id) async {
    await _delete('building-cutlists/$id');
  }

  Future<List<WorkPhaseModel>> getWorkPhases() async {
    final list = await _getList('work-phases');
    return list
        .map((e) => WorkPhaseModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> addDetailedReport(DetailedReportModel report) async {
    final body = report.toJson();
    body['lines'] = report.lines.map((e) => e.toJson()).toList();
    body.addAll(report.executedTodaySummaryJsonEntries());
    return _post('detailed-reports', body);
  }

  /// استبدال رأس التقرير وسطور العمل بالكامل (تعديل خطة محفوظة).
  Future<void> updateDetailedReport(
    int reportId,
    DetailedReportModel report,
  ) async {
    final body = <String, dynamic>{
      'userId': report.userId,
      'userName': report.userName,
      'reportDatetime': report.reportDatetime.toIso8601String(),
      if (report.projectId != null) 'projectId': report.projectId,
      if (report.projectName != null && report.projectName!.trim().isNotEmpty)
        'projectName': report.projectName!.trim(),
      if (report.supervisorId != null) 'supervisorId': report.supervisorId,
      if (report.summary != null && report.summary!.trim().isNotEmpty)
        'summary': report.summary!.trim(),
      ...report.executedTodaySummaryJsonEntries(),
      'lines': report.lines.map((e) => e.toJson()).toList(),
      'expenses': report.expenses.map((e) => e.toJson()).toList(),
      'attachments': report.attachments.map((e) => e.toJson()).toList(),
    };
    await _put('detailed-reports/$reportId', body);
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
      'dateFrom': DateTime(
        dateFrom.year,
        dateFrom.month,
        dateFrom.day,
      ).toIso8601String(),
      'dateTo': DateTime(
        dateTo.year,
        dateTo.month,
        dateTo.day,
        23,
        59,
        59,
        999,
      ).toIso8601String(),
    };
    if (userId != null) params['userId'] = userId.toString();
    if (projectId != null) params['projectId'] = projectId.toString();
    final uri = Uri.parse(
      _path('detailed-reports'),
    ).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) =>
              DetailedReportModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// حذف تقرير مفصّل (صلاحية المسؤول المحدد في الواجهة فقط)
  Future<void> deleteDetailedReport(int id) async {
    await _delete('detailed-reports/$id');
  }

  // ——— هيكلة المخازن: خامات لكل موقع فرعي ———
  Future<List<LocationMaterialModel>> getLocationMaterials(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    final list = await _getList(
      'location-materials?locationId=$locationId&phase=${Uri.encodeQueryComponent(phase)}',
    );
    return list
        .map(
          (e) => LocationMaterialModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<LocationMaterialModel>> getLocationMaterialsForProject(
    int projectId,
  ) async {
    final bulk = await _tryGetList('location-materials?projectId=$projectId');
    if (bulk != null) {
      return bulk
          .map(
            (e) => LocationMaterialModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    final locations = await getProjectLocations(projectId);
    final futures = <Future<List<LocationMaterialModel>>>[];
    for (final location in locations) {
      for (final phase in LocationMaterialModel.phases) {
        futures.add(getLocationMaterials(location.id, phase: phase));
      }
    }
    final chunks = await _boundedWait(futures);
    return chunks.expand((materials) => materials).toList();
  }

  Future<int> addLocationMaterial(LocationMaterialModel m) async {
    return _post('location-materials', {
      'locationId': m.locationId,
      'phase': m.phase,
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
    String? engineerFineTarget,
  }) async {
    return _post('executed-plans', {
      'sourcePlanId': sourcePlanId,
      'userId': userId,
      'userName': userName,
      'projectId': plan.projectId,
      'projectName': plan.projectName,
      'planDate': DateTime(
        planDate.year,
        planDate.month,
        planDate.day,
      ).toIso8601String(),
      'status': status,
      'modificationSummary': modificationSummary,
      'postponeReasonKey': postponeReasonKey,
      'postponeReasonLabel': postponeReasonLabel,
      'postponeCustomReason': postponeCustomReason,
      'postponeNotes': postponeNotes,
      'postponeReopenDate': postponeReopenDate != null
          ? DateTime(
              postponeReopenDate.year,
              postponeReopenDate.month,
              postponeReopenDate.day,
            ).toIso8601String()
          : null,
      'engineerFineTarget': engineerFineTarget,
      'plan': plan.toJson(),
    });
  }

  Future<List<PendingPostponeFineActionModel>> listPendingSemPostponeFineActions({
    required int userId,
  }) async {
    final uri = Uri.parse(_path('executed-plans/pending-sem-fine-actions')).replace(
      queryParameters: {'userId': userId.toString()},
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! List) return [];
    return decoded
        .map((e) => PendingPostponeFineActionModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  Future<void> resolveSemPostponeFineResolution({
    required int executedPlanId,
    required int managerUserId,
    required String fineTarget,
    String? fineAmount,
    String? noFineReason,
  }) async {
    final uri = Uri.parse(_path('executed-plans/$executedPlanId/sem-fine-resolution'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'managerUserId': managerUserId,
        'fineTarget': fineTarget,
        if (fineAmount != null) 'fineAmount': fineAmount,
        if (noFineReason != null) 'noFineReason': noFineReason,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<List<PostponeFineReportRowModel>> getPostponeFinesReport({
    required int actorUserId,
    required DateTime dateFrom,
    required DateTime dateTo,
    int? engineerUserId,
    int? projectId,
    int? contractorId,
    String? reasonKey,
  }) async {
    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final qp = <String, String>{
      'actorUserId': actorUserId.toString(),
      'dateFrom': ymd(dateFrom),
      'dateTo': ymd(dateTo),
    };
    if (engineerUserId != null) {
      qp['engineerUserId'] = engineerUserId.toString();
    }
    if (projectId != null) qp['projectId'] = projectId.toString();
    if (contractorId != null) qp['contractorId'] = contractorId.toString();
    if (reasonKey != null && reasonKey.trim().isNotEmpty) {
      qp['reasonKey'] = reasonKey.trim();
    }
    final uri = Uri.parse(_path('executed-plans/postpone-fines-report')).replace(
      queryParameters: qp,
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! List) return [];
    return decoded
        .map(
          (e) => PostponeFineReportRowModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// تقرير سحب الخامات: المشاريع ومواقع العمل مع حالة الطلب/الإتمام والمرفقات.
  Future<List<MaterialWithdrawalReportRowModel>> getMaterialWithdrawalsReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
    int? engineerUserId,
    String? status,
  }) async {
    final qp = <String, String>{
      'dateFrom': _ymd(dateFrom),
      'dateTo': _ymd(dateTo),
    };
    if (projectId != null) qp['projectId'] = projectId.toString();
    if (engineerUserId != null) {
      qp['engineerUserId'] = engineerUserId.toString();
    }
    if (status != null && status.trim().isNotEmpty) qp['status'] = status.trim();
    const path = 'reports/material-withdrawals';
    final uri = Uri.parse(_path(path)).replace(queryParameters: qp);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! List) return [];
    return decoded
        .map(
          (e) => MaterialWithdrawalReportRowModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// تقرير الملفات المرفوعة حالياً (IR / MIR / MS / SD / MoS / ITP / أذون السحب...).
  Future<List<UploadedFileReportRowModel>> getUploadedFilesReport({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
    String? kind,
  }) async {
    final qp = <String, String>{
      'dateFrom': _ymd(dateFrom),
      'dateTo': _ymd(dateTo),
    };
    if (projectId != null) qp['projectId'] = projectId.toString();
    if (kind != null && kind.trim().isNotEmpty) qp['kind'] = kind.trim();
    const path = 'reports/uploaded-files';
    final uri = Uri.parse(_path(path)).replace(queryParameters: qp);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! List) return [];
    return decoded
        .map(
          (e) => UploadedFileReportRowModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>?> getLatestExecutedPlanStatus({
    required int sourcePlanId,
    required int userId,
  }) async {
    final uri = Uri.parse(_path('executed-plans/latest')).replace(
      queryParameters: {
        'sourcePlanId': sourcePlanId.toString(),
        'userId': userId.toString(),
      },
    );
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
    final uri = Uri.parse(_path('executed-plans/postponed-reopens')).replace(
      queryParameters: {
        'reopenDate': d.toIso8601String(),
        'userId': userId.toString(),
      },
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null || decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getContractorReportFromExecutedPlans({
    required String contractorName,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final fromD = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toD = DateTime(dateTo.year, dateTo.month, dateTo.day);
    final uri = Uri.parse(_path('executed-plans/contractor-report')).replace(
      queryParameters: {
        'contractorName': contractorName.trim(),
        'dateFrom': fromD.toIso8601String(),
        'dateTo': toD.toIso8601String(),
      },
    );
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
    final uri = Uri.parse(_path('executed-plans/daily-summary')).replace(
      queryParameters: {
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
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
      'dateFrom': DateTime(
        dateFrom.year,
        dateFrom.month,
        dateFrom.day,
      ).toIso8601String(),
      'dateTo': DateTime(
        dateTo.year,
        dateTo.month,
        dateTo.day,
        23,
        59,
        59,
        999,
      ).toIso8601String(),
      'requesterEmail': requesterEmail.trim().toLowerCase(),
    };
    if (userId != null) params['userId'] = userId.toString();
    if (actionType != null && actionType.trim().isNotEmpty)
      params['actionType'] = actionType.trim();
    final uri = Uri.parse(
      _path('activity-logs'),
    ).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => ActivityLogModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<LocationWithdrawalModel?> getLocationWithdrawal(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    final uri = Uri.parse(
      _path('location-withdrawal'),
    ).replace(
      queryParameters: {'locationId': locationId.toString(), 'phase': phase},
    );
    final r = await _httpGet(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final decoded = jsonDecode(r.body);
    if (decoded == null) return null;
    return LocationWithdrawalModel.fromMap(
      Map<String, dynamic>.from(decoded as Map),
    );
  }

  Future<List<LocationWithdrawalModel>> getLocationWithdrawalsForProject(
    int projectId,
  ) async {
    final bulk = await _tryGetList('location-withdrawal?projectId=$projectId');
    if (bulk != null) {
      return bulk
          .map(
            (e) => LocationWithdrawalModel.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
    }

    final locations = await getProjectLocations(projectId);
    final futures = <Future<LocationWithdrawalModel?>>[];
    for (final location in locations) {
      for (final phase in LocationMaterialModel.phases) {
        futures.add(getLocationWithdrawal(location.id, phase: phase));
      }
    }
    final rows = await _boundedWait(futures);
    return rows.whereType<LocationWithdrawalModel>().toList();
  }

  Future<void> createLocationWithdrawal({
    required int locationId,
    String phase = LocationMaterialModel.phaseFirstFix,
    required int userId,
    required String userName,
    String? disbursementPermitImagesJson,
    String? deliveryPermitImagesJson,
  }) async {
    final uri = Uri.parse(_path('location-withdrawal'));
    final body = {
      'locationId': locationId,
      'phase': phase,
      'userId': userId,
      'userName': userName,
      if (disbursementPermitImagesJson != null)
        'disbursementPermitImagesJson': disbursementPermitImagesJson,
      'deliveryPermitImagesJson': '[]',
    };
    final r = await http.post(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) {
      final err = r.body;
      if (err.contains('already_withdrawn')) {
        throw Exception('تم سحب الخامات من هذا المكان مسبقاً');
      }
      if (err.contains('insufficient_stock')) {
        throw Exception(withdrawalInsufficientStockMessage);
      }
      throw Exception(err);
    }
  }

  /// إلغاء سحب الخامات لموقع فرعي واسترجاع رصيد المخزن (مسؤول التطبيق).
  Future<void> deleteLocationWithdrawal(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    final uri = Uri.parse(
      _path('location-withdrawal'),
    ).replace(
      queryParameters: {'locationId': locationId.toString(), 'phase': phase},
    );
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  /// سحوبات خامات في الفترة (نفس تاريخ التقرير + مهندس + موقع فرعي للمطابقة في التقرير المجمع)
  Future<List<LocationWithdrawalForPeriodModel>>
  getLocationWithdrawalsForPeriod({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    final fromD = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toD = DateTime(dateTo.year, dateTo.month, dateTo.day);
    final params = <String, String>{
      'dateFrom':
          '${fromD.year.toString().padLeft(4, '0')}-${fromD.month.toString().padLeft(2, '0')}-${fromD.day.toString().padLeft(2, '0')}',
      'dateTo':
          '${toD.year.toString().padLeft(4, '0')}-${toD.month.toString().padLeft(2, '0')}-${toD.day.toString().padLeft(2, '0')}',
    };
    if (projectId != null) params['projectId'] = projectId.toString();
    final uri = Uri.parse(
      _path('location-withdrawals-for-period'),
    ).replace(queryParameters: params);
    final r = await http.get(uri);
    // خادم قديم بدون هذا المسار: نكمل التقرير المجمع مع عمود خامات = ---------
    if (r.statusCode == 404) return [];
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => LocationWithdrawalForPeriodModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<List<IrMirUploadModel>> listIrMirUploads({
    required int projectId,
    String? kind,
    String? mirName,
    int? locationId,
    String? phase,
  }) async {
    final params = <String, String>{'projectId': projectId.toString()};
    if (kind != null && kind.isNotEmpty) params['kind'] = kind;
    if (mirName != null && mirName.trim().isNotEmpty) {
      params['mirName'] = mirName.trim();
    }
    if (locationId != null) params['locationId'] = locationId.toString();
    if (phase != null && phase.trim().isNotEmpty) params['phase'] = phase.trim();
    final uri = Uri.parse(_path('ir-mir/uploads')).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => IrMirUploadModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
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
    return _post('ir-mir/uploads', {
      'projectId': projectId,
      'userId': userId,
      'userName': userName,
      'kind': kind,
      'mirName': mirName,
      'locationId': locationId,
      'phase': phase,
      'fileName': fileName,
      'fileMime': fileMime,
      'fileData': fileData,
      'notes': notes,
    });
  }

  Future<void> deleteIrMirUpload(int id, {required String requesterEmail}) async {
    final uri = Uri.parse(_path('ir-mir/uploads/$id')).replace(
      queryParameters: {
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
    final r = await http.delete(uri);
    if (r.statusCode == 403) {
      throw Exception('غير مصرح بحذف المرفقات');
    }
    if (r.statusCode == 404) {
      throw Exception('المرفق غير موجود');
    }
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<List<MsSdRecordModel>> listMsSdRecords({
    required int projectId,
    required String kind,
    String? requesterEmail,
  }) async {
    final params = <String, String>{
      'projectId': projectId.toString(),
      'kind': kind,
    };
    final email = requesterEmail?.trim();
    if (email != null && email.isNotEmpty) {
      params['requesterEmail'] = email.toLowerCase();
    }
    const path = 'ms-sd/records';
    final uri = Uri.parse(_path(path)).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => MsSdRecordModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
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
    return _post('ms-sd/records', {
      'projectId': projectId,
      'userId': userId,
      'userName': userName,
      'kind': kind,
      'recordName': recordName,
      'notes': notes,
      'attachments': attachments
          .map(
            (a) => {
              'fileName': a['fileName'],
              'fileMime': a['fileMime'],
              'fileData': a['fileData'],
            },
          )
          .toList(),
    });
  }

  Future<void> updateMsSdRecord(
    int id, {
    required String requesterEmail,
    String? recordName,
    String? notes,
    List<int>? removeAttachmentIds,
    List<Map<String, String>>? addAttachments,
  }) async {
    final uri = Uri.parse(_path('ms-sd/records/$id')).replace(
      queryParameters: {
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
    final body = <String, dynamic>{};
    if (recordName != null) body['recordName'] = recordName;
    if (notes != null) body['notes'] = notes;
    if (removeAttachmentIds != null && removeAttachmentIds.isNotEmpty) {
      body['removeAttachmentIds'] = removeAttachmentIds;
    }
    if (addAttachments != null && addAttachments.isNotEmpty) {
      body['addAttachments'] = addAttachments
          .map(
            (a) => {
              'fileName': a['fileName'],
              'fileMime': a['fileMime'],
              'fileData': a['fileData'],
            },
          )
          .toList();
    }
    final r = await http.patch(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode == 403) {
      throw Exception('غير مصرح بتعديل السجل');
    }
    if (r.statusCode == 404) {
      throw _apiHttpException(r, path: 'ms-sd/records/$id');
    }
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'ms-sd/records/$id');
  }

  Future<void> deleteMsSdRecord(int id, {required String requesterEmail}) async {
    final uri = Uri.parse(_path('ms-sd/records/$id')).replace(
      queryParameters: {
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
    final r = await http.delete(uri);
    if (r.statusCode == 403) {
      throw Exception('غير مصرح بحذف السجل');
    }
    if (r.statusCode == 404) {
      throw _apiHttpException(r, path: 'ms-sd/records/$id');
    }
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'ms-sd/records/$id');
  }

  Future<List<MosItpRecordModel>> listMosItpRecords({
    required int projectId,
    required String kind,
    String? requesterEmail,
  }) async {
    final params = <String, String>{
      'projectId': projectId.toString(),
      'kind': kind,
    };
    final email = requesterEmail?.trim();
    if (email != null && email.isNotEmpty) {
      params['requesterEmail'] = email.toLowerCase();
    }
    const path = 'mos-itp/records';
    final uri = Uri.parse(_path(path)).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => MosItpRecordModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
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
    return _post('mos-itp/records', {
      'projectId': projectId,
      'userId': userId,
      'userName': userName,
      'kind': kind,
      'recordName': recordName,
      'notes': notes,
      'attachments': attachments
          .map(
            (a) => {
              'fileName': a['fileName'],
              'fileMime': a['fileMime'],
              'fileData': a['fileData'],
            },
          )
          .toList(),
    });
  }

  Future<void> updateMosItpRecord(
    int id, {
    required String requesterEmail,
    String? recordName,
    String? notes,
    List<int>? removeAttachmentIds,
    List<Map<String, String>>? addAttachments,
  }) async {
    final uri = Uri.parse(_path('mos-itp/records/$id')).replace(
      queryParameters: {
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
    final body = <String, dynamic>{};
    if (recordName != null) body['recordName'] = recordName;
    if (notes != null) body['notes'] = notes;
    if (removeAttachmentIds != null && removeAttachmentIds.isNotEmpty) {
      body['removeAttachmentIds'] = removeAttachmentIds;
    }
    if (addAttachments != null && addAttachments.isNotEmpty) {
      body['addAttachments'] = addAttachments
          .map(
            (a) => {
              'fileName': a['fileName'],
              'fileMime': a['fileMime'],
              'fileData': a['fileData'],
            },
          )
          .toList();
    }
    final r = await http.patch(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode == 403) {
      throw Exception('غير مصرح بتعديل السجل');
    }
    if (r.statusCode == 404) {
      throw _apiHttpException(r, path: 'mos-itp/records/$id');
    }
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'mos-itp/records/$id');
  }

  Future<void> deleteMosItpRecord(int id, {required String requesterEmail}) async {
    final uri = Uri.parse(_path('mos-itp/records/$id')).replace(
      queryParameters: {
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
    final r = await http.delete(uri);
    if (r.statusCode == 403) {
      throw Exception('غير مصرح بحذف السجل');
    }
    if (r.statusCode == 404) {
      throw _apiHttpException(r, path: 'mos-itp/records/$id');
    }
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'mos-itp/records/$id');
  }

  Future<Map<String, dynamic>> _postReturnMap(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(_path(path));
    final r = await http.post(
      uri,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty) return {};
    final decoded = jsonDecode(r.body);
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<WithdrawalRequestModel> createWithdrawalRequest({
    required int projectId,
    required int locationId,
    required String phase,
    required int engineerUserId,
    required String engineerUserName,
    required String locationPathLabel,
  }) async {
    final m = await _postReturnMap('withdrawal-requests', {
      'projectId': projectId,
      'locationId': locationId,
      'phase': phase,
      'userId': engineerUserId,
      'userName': engineerUserName,
      'locationPathLabel': locationPathLabel,
    });
    return WithdrawalRequestModel.fromMap(m);
  }

  Future<WithdrawalRequestModel?> getWithdrawalRequestById(int id) async {
    final r = await http.get(Uri.parse(_path('withdrawal-requests/$id')));
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) throw Exception(r.body);
    final map = jsonDecode(r.body);
    if (map is! Map) return null;
    return WithdrawalRequestModel.fromMap(Map<String, dynamic>.from(map));
  }

  Future<List<WithdrawalRequestModel>> getWithdrawalRequestsForEngineerProject({
    required int projectId,
    required int engineerUserId,
  }) async {
    final uri = Uri.parse(_path('withdrawal-requests/for-engineer-project'))
        .replace(queryParameters: {
      'projectId': projectId.toString(),
      'engineerUserId': engineerUserId.toString(),
    });
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => WithdrawalRequestModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  /// طلبات سحب الخامات في الفترة (لتقرير متابعة خطة اليوم).
  Future<List<WithdrawalRequestModel>> getWithdrawalRequestsForPeriod({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
    int? engineerUserId,
  }) async {
    final fromD = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toD = DateTime(dateTo.year, dateTo.month, dateTo.day);
    final params = <String, String>{
      'dateFrom':
          '${fromD.year.toString().padLeft(4, '0')}-${fromD.month.toString().padLeft(2, '0')}-${fromD.day.toString().padLeft(2, '0')}',
      'dateTo':
          '${toD.year.toString().padLeft(4, '0')}-${toD.month.toString().padLeft(2, '0')}-${toD.day.toString().padLeft(2, '0')}',
    };
    if (projectId != null) params['projectId'] = projectId.toString();
    if (engineerUserId != null) {
      params['engineerUserId'] = engineerUserId.toString();
    }
    final uri = Uri.parse(
      _path('withdrawal-requests-for-period'),
    ).replace(queryParameters: params);
    final r = await http.get(uri);
    if (r.statusCode == 404) return [];
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => WithdrawalRequestModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<WithdrawalRequestModel?> getOpenWithdrawalRequestForLocationPhase({
    required int locationId,
    required String phase,
  }) async {
    final uri = Uri.parse(_path('withdrawal-requests/open')).replace(
      queryParameters: {
        'locationId': locationId.toString(),
        'phase': phase,
      },
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    if (r.body.isEmpty || r.body == 'null') return null;
    final decoded = jsonDecode(r.body);
    if (decoded == null) return null;
    return WithdrawalRequestModel.fromMap(
      Map<String, dynamic>.from(decoded as Map),
    );
  }

  Future<int> countPendingWithdrawalActionsForManager({
    required int userId,
    required String role,
  }) async {
    final cacheKey = 'withdrawal-requests/action-count:$userId:$role';
    final cached = _readCachedInt(cacheKey);
    if (cached != null) return cached;
    final uri =
        Uri.parse(_path('withdrawal-requests/action-count')).replace(
      queryParameters: {
        'userId': userId.toString(),
        'role': role,
      },
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final c = data['count'];
    if (c is int) return _storeCachedInt(cacheKey, c);
    return _storeCachedInt(cacheKey, int.tryParse(c?.toString() ?? '0') ?? 0);
  }

  Future<List<WithdrawalRequestModel>> listPendingWithdrawalActionsForManager({
    required int userId,
    required String role,
  }) async {
    final uri =
        Uri.parse(_path('withdrawal-requests/pending-actions')).replace(
      queryParameters: {
        'userId': userId.toString(),
        'role': role,
      },
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => WithdrawalRequestModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> respondWithdrawalRequest({
    required int requestId,
    required int managerUserId,
    required bool approve,
    String? reason,
  }) async {
    final uri = Uri.parse(_path('withdrawal-requests/$requestId/respond'));
    final r = await http.put(
      uri,
      body: jsonEncode({
        'userId': managerUserId,
        'decision': approve ? 'approve' : 'reject',
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<void> fulfillWithdrawalRequest({
    required int requestId,
    required int engineerUserId,
  }) async {
    final uri = Uri.parse(_path('withdrawal-requests/$requestId/fulfill'));
    final r = await http.put(
      uri,
      body: jsonEncode({'userId': engineerUserId}),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  // ——— Reports-SYS ———
  Future<bool> checkReportsSysNameAvailable({
    required String name,
    int? excludeId,
  }) async {
    final qp = <String, String>{'name': name};
    if (excludeId != null) qp['excludeId'] = excludeId.toString();
    final uri = Uri.parse(_path('reports-sys/check-name')).replace(
      queryParameters: qp,
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return data['available'] == true;
  }

  Future<int> countPendingReportsSys(int userId) async {
    final cacheKey = 'reports-sys/pending-count:$userId';
    final cached = _readCachedInt(cacheKey);
    if (cached != null) return cached;
    final uri = Uri.parse(_path('reports-sys/pending-count')).replace(
      queryParameters: {'userId': userId.toString()},
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return _storeCachedInt(
      cacheKey,
      int.tryParse(data['count']?.toString() ?? '0') ?? 0,
    );
  }

  Future<List<ReportsSysModel>> listReportsSysInbox({
    required int userId,
    required String tab,
    String? requesterEmail,
    String? searchQuery,
  }) async {
    final qp = <String, String>{
      'userId': userId.toString(),
      'tab': tab,
    };
    if (requesterEmail != null && requesterEmail.trim().isNotEmpty) {
      qp['requesterEmail'] = requesterEmail.trim();
    }
    final q = searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      qp['q'] = q;
    }
    final uri = Uri.parse(_path('reports-sys/inbox')).replace(
      queryParameters: qp,
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => ReportsSysModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ReportsSysModel> getReportsSysDetail(int reportId) async {
    final uri = Uri.parse(_path('reports-sys/$reportId'));
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    return ReportsSysModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<Map<String, String>> getReportsSysAttachmentData({
    required int reportId,
    required int attachmentId,
  }) async {
    final uri = Uri.parse(
      _path('reports-sys/$reportId/attachments/$attachmentId'),
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    return {
      'file_name': (data['file_name'] ?? '').toString(),
      'mime_type': (data['mime_type'] ?? '').toString(),
      'data_base64': (data['data_base64'] ?? '').toString(),
    };
  }

  Future<ReportsSysModel> createReportsSys({
    required int userId,
    required String reportName,
    required String reportType,
    required String summary,
    String? notes,
    int? sourceReportId,
    int? projectId,
    String? projectName,
  }) async {
    final uri = Uri.parse(_path('reports-sys'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'reportName': reportName,
        'reportType': reportType,
        'summary': summary,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (sourceReportId != null) 'sourceReportId': sourceReportId,
        if (projectId == ReportsSysModel.otherProjectId) ...{
          'projectId': ReportsSysModel.otherProjectId,
          if (projectName != null && projectName.isNotEmpty)
            'projectName': projectName,
        } else if (projectId != null) ...{
          'projectId': projectId,
        },
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ReportsSysModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ReportsSysModel> updateReportsSys({
    required int reportId,
    required int userId,
    required String reportName,
    required String reportType,
    required String summary,
    String? notes,
    int? projectId,
    String? projectName,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final uri = Uri.parse(_path('reports-sys/$reportId'));
    final r = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'reportName': reportName,
        'reportType': reportType,
        'summary': summary,
        if (notes != null) 'notes': notes,
        if (projectId == ReportsSysModel.otherProjectId) ...{
          'projectId': ReportsSysModel.otherProjectId,
          if (projectName != null && projectName.isNotEmpty)
            'projectName': projectName,
        } else if (projectId != null) ...{
          'projectId': projectId,
        },
        if (attachments != null) 'attachments': attachments,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ReportsSysModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ReportsSysModel> submitReportsSys({
    required int reportId,
    required int userId,
    required int toUserId,
    String? comment,
  }) async {
    final uri = Uri.parse(_path('reports-sys/$reportId/submit'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'toUserId': toUserId,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ReportsSysModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ReportsSysModel> respondReportsSys({
    required int reportId,
    required int userId,
    required String action,
    int? toUserId,
    String? comment,
  }) async {
    final uri = Uri.parse(_path('reports-sys/$reportId/respond'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'action': action,
        if (toUserId != null) 'toUserId': toUserId,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ReportsSysModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ReportsSysModel> relaunchReportsSys({
    required int sourceReportId,
    required int userId,
    required String reportName,
  }) async {
    final uri = Uri.parse(_path('reports-sys/$sourceReportId/relaunch'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'reportName': reportName,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ReportsSysModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<void> deleteReportsSys({
    required int reportId,
    required int userId,
    required String requesterEmail,
  }) async {
    final uri = Uri.parse(_path('reports-sys/$reportId')).replace(
      queryParameters: {
        'userId': userId.toString(),
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<int> getShopDrawingPendingCount(int userId) async {
    final data = await _get('shop-drawing/pending-count?userId=$userId');
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<ShopDrawingModel>> getShopDrawingInbox({
    required int userId,
    required String tab,
    required String documentType,
  }) async {
    final path = 'shop-drawing/inbox';
    final uri = Uri.parse(_path(path)).replace(
      queryParameters: {
        'userId': userId.toString(),
        'tab': tab,
        'documentType': documentType,
      },
    );
    final r = await _httpGet(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => ShopDrawingModel.fromMap(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<ShopDrawingModel> getShopDrawingDetail(int drawingId) async {
    final path = 'shop-drawing/$drawingId';
    final r = await _httpGet(Uri.parse(_path(path)));
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    return ShopDrawingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<Map<String, String>> getShopDrawingAttachmentData({
    required int drawingId,
    required int attachmentId,
  }) async {
    final path = 'shop-drawing/$drawingId/attachments/$attachmentId';
    final uri = Uri.parse(_path(path));
    final r = await _httpGet(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
    final data = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    return {
      'file_name': (data['file_name'] ?? '').toString(),
      'mime_type': (data['mime_type'] ?? '').toString(),
      'data_base64': (data['data_base64'] ?? '').toString(),
    };
  }

  Future<ShopDrawingModel> createShopDrawing({
    required int userId,
    int? projectId,
    String? projectName,
    String? notes,
    required List<Map<String, dynamic>> attachments,
    required String documentType,
    String? externalUrl,
    bool contentSd = false,
    bool contentQs = false,
    bool contentDashboard = false,
  }) async {
    final uri = Uri.parse(_path('shop-drawing'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        if (projectId != null) 'projectId': projectId,
        if (projectName != null && projectName.isNotEmpty)
          'projectName': projectName,
        'documentType': documentType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'attachments': attachments,
        if (externalUrl != null && externalUrl.isNotEmpty)
          'externalUrl': externalUrl,
        'contentSd': contentSd,
        'contentQs': contentQs,
        'contentDashboard': contentDashboard,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ShopDrawingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ShopDrawingModel> updateShopDrawing({
    required int drawingId,
    required int userId,
    int? projectId,
    String? projectName,
    String? notes,
    required List<Map<String, dynamic>> attachments,
    String? externalUrl,
    bool contentSd = false,
    bool contentQs = false,
    bool contentDashboard = false,
  }) async {
    final uri = Uri.parse(_path('shop-drawing/$drawingId'));
    final r = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        if (projectId != null) 'projectId': projectId,
        if (projectName != null && projectName.isNotEmpty)
          'projectName': projectName,
        if (notes != null) 'notes': notes,
        'attachments': attachments,
        'externalUrl': externalUrl,
        'contentSd': contentSd,
        'contentQs': contentQs,
        'contentDashboard': contentDashboard,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ShopDrawingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ShopDrawingModel> pmApproveShopDrawing({
    required int drawingId,
    required int userId,
  }) async {
    final uri = Uri.parse(_path('shop-drawing/$drawingId/pm-approve'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ShopDrawingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ShopDrawingModel> pmReturnShopDrawing({
    required int drawingId,
    required int userId,
    required String reason,
  }) async {
    final uri = Uri.parse(_path('shop-drawing/$drawingId/pm-return'));
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'reason': reason}),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ShopDrawingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ShopDrawingModel> omApproveShopDrawing({
    required int drawingId,
    required int userId,
    String? omNotes,
  }) async {
    final uri = Uri.parse(_path('shop-drawing/$drawingId/om-approve'));
    final trimmed = omNotes?.trim();
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        if (trimmed != null && trimmed.isNotEmpty) 'omNotes': trimmed,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ShopDrawingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ShopDrawingModel> updateShopDrawingOmNotes({
    required int drawingId,
    required int userId,
    String? omNotes,
  }) async {
    final uri = Uri.parse(_path('shop-drawing/$drawingId/om-notes'));
    final trimmed = omNotes?.trim();
    final r = await http.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'omNotes': trimmed ?? '',
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ShopDrawingModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<void> deleteShopDrawing({
    required int drawingId,
    required int userId,
  }) async {
    final uri = Uri.parse(_path('shop-drawing/$drawingId')).replace(
      queryParameters: {'userId': userId.toString()},
    );
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<List<ShopDarwingNotificationModel>> getShopDrawingModuleNotifications(
    int userId, {
    required String documentType,
  }) async {
    final list = await _getList(
      'shop-drawing/module-notifications?userId=$userId&documentType=$documentType',
    );
    return list
        .map(
          (e) => ShopDarwingNotificationModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<int> getUnreadShopDrawingModuleNotificationsCount(
    int userId, {
    required String documentType,
  }) async {
    final cacheKey =
        'shop-drawing/module-notifications/unread-count:$userId:$documentType';
    final cached = _readCachedInt(cacheKey);
    if (cached != null) return cached;
    final data = await _get(
      'shop-drawing/module-notifications/unread-count?userId=$userId&documentType=$documentType',
    );
    return _storeCachedInt(cacheKey, (data['count'] as num?)?.toInt() ?? 0);
  }

  Future<void> markShopDrawingModuleNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    await _put('shop-drawing/module-notifications/$notificationId/read', {
      'userId': userId,
    });
  }

  Future<AppReleaseInfoModel> getAppReleaseLatest(int userId) async {
    final cacheKey = 'app-release/latest:$userId';
    final cached = _readCachedRelease(cacheKey);
    if (cached != null) return cached;
    try {
      final data = await _get('app-release/latest?userId=$userId');
      return _storeCachedRelease(cacheKey, AppReleaseInfoModel.fromMap(data));
    } catch (_) {
      return _storeCachedRelease(cacheKey, AppReleaseInfoModel.none());
    }
  }

  Future<bool> hasAppReleaseUpdate(int userId) async {
    final info = await getAppReleaseLatest(userId);
    return info.hasUpdate;
  }

  String _normalizeBase64(String value) {
    var data = value.trim();
    if (data.startsWith('data:')) {
      final comma = data.indexOf(',');
      if (comma >= 0) data = data.substring(comma + 1);
    }
    return data.replaceAll(RegExp(r'\s+'), '');
  }

  Future<AppReleaseDownloadResult> downloadAppReleaseChunked(
    int userId, {
    void Function(int receivedBytes, int totalBytes)? onProgress,
  }) async {
    final infoData = await _get('app-release/download-info?userId=$userId');
    final info = AppReleaseDownloadInfoModel.fromMap(infoData);
    if (!info.hasRelease || info.totalChunks <= 0) {
      throw Exception('No release available');
    }

    final buffer = BytesBuilder(copy: false);
    var received = 0;

    for (var chunkIndex = 0; chunkIndex < info.totalChunks; chunkIndex++) {
      final uri = Uri.parse(
        _path(
          'app-release/download-chunk?userId=$userId&chunkIndex=$chunkIndex',
        ),
      );
      final response = await http.get(uri).timeout(const Duration(minutes: 3));
      if (response.statusCode >= 400) {
        throw _apiHttpException(response, path: 'app-release/download-chunk');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      var chunkData = decoded['chunkData'] as String? ?? '';
      chunkData = _normalizeBase64(chunkData);
      if (chunkData.isEmpty) {
        throw Exception('Empty chunk $chunkIndex');
      }
      final chunkBytes = base64Decode(_normalizeBase64(chunkData));
      buffer.add(chunkBytes);
      received += chunkBytes.length;
      onProgress?.call(received, info.sizeBytes);
    }

    return AppReleaseDownloadResult(
      fileName: info.fileName,
      bytes: buffer.toBytes(),
    );
  }

  Future<String> _encodeBase64WithProgress(
    List<int> bytes,
    void Function(double fraction)? onEncodeProgress,
  ) async {
    const chunkSize = 1024 * 1024 * 3;
    final sb = StringBuffer();
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = i + chunkSize < bytes.length ? i + chunkSize : bytes.length;
      sb.write(base64Encode(bytes.sublist(i, end)));
      onEncodeProgress?.call(end / bytes.length);
      await Future<void>.delayed(Duration.zero);
    }
    return sb.toString();
  }

  /// Uploads an app release in small base64 chunks so large APKs transfer
  /// reliably (avoids a single huge request) and report real progress.
  Future<void> uploadAppRelease({
    required String requesterEmail,
    required String versionLabel,
    required String fileName,
    required List<int> fileBytes,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    final email = requesterEmail.trim().toLowerCase();

    // Encoding phase: 0 -> 0.1
    final fileDataBase64 = await _encodeBase64WithProgress(
      fileBytes,
      (fraction) => onProgress?.call(fraction * 0.1),
    );

    final uploadId =
        '${DateTime.now().millisecondsSinceEpoch}_${fileBytes.length}';

    // Split the base64 STRING into fixed-size pieces (string concatenation on
    // the server reproduces the exact original base64).
    const chunkChars = 3 * 1024 * 1024; // ~3MB per request
    final totalChunks = (fileDataBase64.length / chunkChars).ceil();

    Future<Map<String, dynamic>> post(
      String path,
      Map<String, dynamic> body,
    ) async {
      final r = await http
          .post(
            Uri.parse(_path(path)),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(minutes: 5));
      if (r.statusCode >= 400) throw _apiHttpException(r, path: path);
      return r.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(r.body) as Map<String, dynamic>;
    }

    await post('app-release/upload-init', {
      'requesterEmail': email,
      'uploadId': uploadId,
    });

    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkChars;
      final end =
          start + chunkChars < fileDataBase64.length
              ? start + chunkChars
              : fileDataBase64.length;
      await post('app-release/upload-chunk', {
        'requesterEmail': email,
        'uploadId': uploadId,
        'chunkIndex': i,
        'chunkData': fileDataBase64.substring(start, end),
      });
      onProgress?.call(0.1 + (0.9 * (i + 1) / totalChunks));
    }

    await post('app-release/upload-finalize', {
      'requesterEmail': email,
      'uploadId': uploadId,
      'versionLabel': versionLabel.trim(),
      'fileName': fileName.trim(),
      'totalChunks': totalChunks,
    });

    onProgress?.call(1);
  }

  Future<ProjectsDashboardSheetModel?> getProjectsDashboardSheet({
    required int userId,
    bool includeData = false,
    String variant = 'webdav',
  }) async {
    final uri = Uri.parse(_path('projects-dashboard/sheet')).replace(
      queryParameters: {
        'userId': userId.toString(),
        'includeData': includeData.toString(),
        'variant': variant,
      },
    );
    final r = await http.get(uri);
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) throw Exception(r.body);
    return ProjectsDashboardSheetModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  String projectsDashboardSheetDownloadUrl({
    required int userId,
    String variant = 'webdav',
  }) {
    final uri = Uri.parse(_path('projects-dashboard/sheet/download')).replace(
      queryParameters: {
        'userId': userId.toString(),
        'variant': variant,
      },
    );
    return uri.toString();
  }

  Future<Map<String, dynamic>> createProjectsDashboardWebdavToken({
    required int userId,
    String variant = 'webdav',
  }) async {
    final r = await http.post(
      Uri.parse(_path('projects-dashboard/webdav/token')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'variant': variant,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  Future<void> saveProjectsDashboardSheet({
    required int userId,
    required String userName,
    String? fileName,
    String? fileMime,
    String? fileData,
    List<List<String>>? rowsJson,
    String? sheetName,
    String variant = 'webdav',
  }) async {
    final body = <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'variant': variant,
    };
    if (fileName != null) body['fileName'] = fileName;
    if (fileMime != null) body['fileMime'] = fileMime;
    if (fileData != null) body['fileData'] = fileData;
    if (rowsJson != null) body['rowsJson'] = rowsJson;
    if (sheetName != null) body['sheetName'] = sheetName;

    final r = await http.put(
      Uri.parse(_path('projects-dashboard/sheet')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode == 403) {
      final body = r.body;
      if (body.contains('initial_upload_technical_office_only')) {
        throw Exception('رفع الشيت لأول مرة من المكتب الفني فقط');
      }
      throw Exception('غير مصرح');
    }
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  Future<List<ProjectsDashboardNoteModel>> listProjectsDashboardNotes({
    required int userId,
    required String authorRole,
    String variant = 'webdav',
  }) async {
    final uri = Uri.parse(_path('projects-dashboard/notes')).replace(
      queryParameters: {
        'userId': userId.toString(),
        'authorRole': authorRole,
        'variant': variant,
      },
    );
    final r = await http.get(uri);
    if (r.statusCode >= 400) throw Exception(r.body);
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map(
          (e) => ProjectsDashboardNoteModel.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<ProjectsDashboardNoteModel?> getLatestProjectsDashboardNote({
    required int userId,
    required String authorRole,
    String variant = 'webdav',
  }) async {
    final uri = Uri.parse(_path('projects-dashboard/notes/latest')).replace(
      queryParameters: {
        'userId': userId.toString(),
        'authorRole': authorRole,
        'variant': variant,
      },
    );
    final r = await http.get(uri);
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) throw Exception(r.body);
    return ProjectsDashboardNoteModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<ProjectsDashboardNoteModel> addProjectsDashboardNote({
    required int userId,
    required String userName,
    required String body,
    String variant = 'webdav',
  }) async {
    final r = await http.post(
      Uri.parse(_path('projects-dashboard/notes')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'userName': userName,
        'body': body.trim(),
        'variant': variant,
      }),
    );
    if (r.statusCode >= 400) throw Exception(r.body);
    return ProjectsDashboardNoteModel.fromMap(
      Map<String, dynamic>.from(jsonDecode(r.body) as Map),
    );
  }

  Future<void> deleteProjectsDashboardNote({
    required int noteId,
    required String requesterEmail,
  }) async {
    final uri = Uri.parse(_path('projects-dashboard/notes/$noteId')).replace(
      queryParameters: {
        'requesterEmail': requesterEmail.trim().toLowerCase(),
      },
    );
    final r = await http.delete(uri);
    if (r.statusCode == 403) throw Exception('غير مصرح بحذف الملاحظة');
    if (r.statusCode == 404) throw Exception('الملاحظة غير موجودة');
    if (r.statusCode >= 400) throw Exception(r.body);
  }

  /// إنشاء بيانات صرف (بنود منفردة). [autoApprove]=true لمدير المشروعات (خصم فوري).
  Future<List<int>> createExpenseStatements({
    required int userId,
    int? projectId,
    String? projectName,
    required List<ExpenseItem> expenses,
    bool autoApprove = false,
  }) async {
    final uri = Uri.parse(_path('expense-statements'));
    final r = await http.post(
      uri,
      body: jsonEncode({
        'userId': userId,
        if (projectId != null) 'projectId': projectId,
        if (projectName != null && projectName.trim().isNotEmpty)
          'projectName': projectName.trim(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'autoApprove': autoApprove,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'expense-statements');
    final data = r.body.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    final ids = data['ids'];
    if (ids is List) {
      return ids
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList();
    }
    return const [];
  }

  Future<List<ExpenseStatementModel>> getExpenseStatements({
    List<String>? statuses,
  }) async {
    final qp = <String, String>{};
    if (statuses != null && statuses.isNotEmpty) {
      qp['status'] = statuses.join(',');
    }
    final uri = Uri.parse(_path('expense-statements')).replace(queryParameters: qp.isEmpty ? null : qp);
    final r = await _httpGet(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'expense-statements');
    final decoded = jsonDecode(r.body);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => ExpenseStatementModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> respondExpenseStatement({
    required int statementId,
    required int actorUserId,
    required bool approve,
    String? reason,
  }) async {
    await _put('expense-statements/$statementId/respond', {
      'userId': actorUserId,
      'decision': approve ? 'approve' : 'reject',
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> deleteExpenseStatement({
    required int statementId,
    required int actorUserId,
  }) async {
    final uri = Uri.parse(_path('expense-statements/$statementId')).replace(
      queryParameters: {'userId': actorUserId.toString()},
    );
    final r = await http.delete(uri);
    if (r.statusCode >= 400) throw _apiHttpException(r, path: 'expense-statements/$statementId');
  }
}
