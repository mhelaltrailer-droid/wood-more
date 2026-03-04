import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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

/// خدمة قاعدة البيانات المحلية
class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wood_and_more.db');

    return openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    // جدول المشاريع
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // جدول سجلات الحضور
    await db.execute('''
      CREATE TABLE attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        type TEXT NOT NULL,
        date_time TEXT NOT NULL,
        location TEXT NOT NULL,
        project_id INTEGER,
        project_name TEXT,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // إدخال بيانات تجريبية
    await _seedData(db);
    await _createDailyReportsAndMaterials(db);
    await _createAdminTables(db);
    await _createStoreAndUnitsTables(db);
    await _createFinanceTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.delete('attendance_records');
      await db.delete('users');
      await _seedData(db);
    }
    if (oldVersion < 3) {
      await db.delete('projects');
      await _seedProjects(db);
    }
    if (oldVersion < 4) {
      await _createDailyReportsAndMaterials(db);
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE daily_reports ADD COLUMN executed_today TEXT NOT NULL DEFAULT \'\'');
      await db.delete('materials');
      await _seedMaterials(db);
    }
    if (oldVersion < 6) {
      await _createAdminTables(db);
      final existing = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM users WHERE email = 'mouhammedhelal@gmail.com'",
      ));
      if (existing == 0) {
        await db.insert('users', {'name': 'مسؤول التطبيق', 'email': 'mouhammedhelal@gmail.com', 'role': 'app_admin'});
      }
    }
    if (oldVersion < 7) {
      await _createStoreAndUnitsTables(db);
    }
    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE building_materials ADD COLUMN length TEXT DEFAULT \'\'');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE building_materials ADD COLUMN pieces_count TEXT DEFAULT \'\'');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE building_materials ADD COLUMN total_length TEXT DEFAULT \'\'');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE building_materials ADD COLUMN total_area TEXT DEFAULT \'\'');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE building_materials ADD COLUMN image_path TEXT');
      } catch (_) {}
    }
    if (oldVersion < 9) {
      await _createFinanceTables(db);
    }
  }

  Future<void> _createFinanceTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS engineer_balance (
        user_id INTEGER PRIMARY KEY,
        balance REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS engineer_custody (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _createStoreAndUnitsTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        material_name TEXT NOT NULL,
        quantity TEXT NOT NULL,
        unit TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        model TEXT NOT NULL,
        image_path TEXT,
        FOREIGN KEY (building_id) REFERENCES buildings (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS building_materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id INTEGER NOT NULL,
        material_name TEXT NOT NULL,
        quantity TEXT NOT NULL,
        unit TEXT NOT NULL,
        FOREIGN KEY (building_id) REFERENCES buildings (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS building_cutlist_images (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        building_id INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        FOREIGN KEY (building_id) REFERENCES buildings (id)
      )
    ''');
  }

  Future<void> _createDailyReportsAndMaterials(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        project_id INTEGER,
        project_name TEXT,
        report_datetime TEXT NOT NULL,
        work_place TEXT NOT NULL,
        work_report TEXT NOT NULL,
        executed_today TEXT NOT NULL DEFAULT '',
        supervisor_name TEXT,
        contractor_name TEXT,
        workers_count TEXT,
        tomorrow_plan TEXT NOT NULL,
        document_path TEXT,
        images_json TEXT,
        notes TEXT,
        materials_json TEXT NOT NULL,
        expenses_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM materials'));
    if (count == 0) await _seedMaterials(db);
  }

  Future<void> _seedMaterials(Database db) async {
    for (final name in defaultMaterialsList) {
      await db.insert('materials', {'name': name});
    }
  }

  Future<void> _seedData(Database db) async {
    // المستخدمون
    await db.insert('users', {'name': 'Hany', 'email': 'hany.samir1708@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Emam', 'email': 'amirelazab46@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Mansur', 'email': 'saedm0566@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Mahmud', 'email': 'mahmoudsiko630@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Abdhusseny', 'email': 'abdallaelhosseny1011@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Hamza', 'email': 'hamzamhamad704@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Gohary', 'email': 'mohamedelgohary371@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Amr', 'email': 'amrelshabrawy55@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Hassan', 'email': 'mouhammed.helal@gmail.com', 'role': 'site_engineer'});
    await db.insert('users', {'name': 'Helal', 'email': 'mouhamedhelal.cor@gmail.com', 'role': 'site_engineer_manager'});
    await db.insert('users', {'name': 'Shams', 'email': 'islam.shams2050@gmail.com', 'role': 'site_engineer_manager'});
    await db.insert('users', {'name': 'Abdrhman', 'email': 'AbdelrhmanEllaithy828@gmail.com', 'role': 'site_engineer_manager'});
    await db.insert('users', {'name': 'مسؤول التطبيق', 'email': 'mouhammedhelal@gmail.com', 'role': 'app_admin'});

    await _seedProjects(db);
  }

  Future<void> _createAdminTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS buildings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        zone_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        storage_info TEXT,
        model_details TEXT,
        cut_list TEXT,
        FOREIGN KEY (zone_id) REFERENCES zones (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supervisors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contractors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedProjects(Database db) async {
    final projects = [
      'UTC_Z5_CRC_F', 'Mivida 31_CRC_F', 'UTC_Z5_EMAAR Building C_F', 'Zed east_ORASCOM_F',
      'Belle Vie_El-Hazek_F', 'CAIRO GATE elain (02)_CRC_F', 'Cairo gate_ACC_W', 'Z1_EMAAR_F',
      'Community Center_CRC_W', 'Terrace Zayed_CRC_W', 'Silver Sands_REDCON_D', 'CAR SHADE_W&M_W',
      'OLD CITY_ORASCOM_W', 'Cairo gate-Eden_ATRUM_F', 'AUC Campus Expansion_Orascom_W&F',
      'UTC - 2 Villa- Link International_W', 'UTC - 2 Villa- Link International_F', 'City Gate_CCC_W',
      'cairo gate - locanda_INOVOO_F', 'Village West _ club_FIT-OUT_W', 'Village West _Villa_W',
      'Mivida gardens_Atrium_F', 'Village West_CRC_ F', 'Up Town Cairo _Z5 _EMAAR_W', 'Belle Vie _ EMAAR_W',
      'Village West _ CRC_ W', 'Wood&More(head office)',
    ];
    for (final name in projects) {
      await db.insert('projects', {'name': name});
    }
  }

  /// الحصول على مهندسي المواقع فقط (للقائمة المنسدلة في التقارير)
  Future<List<UserModel>> getSiteEngineers() async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['site_engineer'],
      orderBy: 'name',
    );
    return maps.map((m) => UserModel.fromMap(m)).toList();
  }

  /// الحصول على المستخدم بالبريد الإلكتروني
  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  /// الحصول على جميع المشاريع
  Future<List<ProjectModel>> getProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'name');
    return maps.map((m) => ProjectModel.fromMap(m)).toList();
  }

  /// إضافة سجل حضور
  Future<int> addAttendanceRecord(AttendanceRecordModel record) async {
    final db = await database;
    return db.insert('attendance_records', {
      'user_id': record.userId,
      'user_name': record.userName,
      'type': record.type,
      'date_time': record.dateTime.toIso8601String(),
      'location': record.location,
      'project_id': record.projectId,
      'project_name': record.projectName,
      'notes': record.notes,
    });
  }

  /// الحصول على جميع سجلات الحضور (للمدير)
  Future<List<AttendanceRecordModel>> getAllAttendanceRecords() async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      orderBy: 'date_time DESC',
    );
    return maps.map((m) => AttendanceRecordModel.fromMap(m)).toList();
  }

  /// الحصول على قائمة الخامات
  Future<List<String>> getMaterials() async {
    final db = await database;
    final maps = await db.query('materials', orderBy: 'name');
    return maps.map((m) => m['name'] as String).toList();
  }

  /// حفظ التقرير اليومي (ويتم خصم إجمالي بنود الماليات من رصيد المهندس)
  Future<int> addDailyReport(DailyReportData report) async {
    final db = await database;
    final rowId = await db.insert('daily_reports', {
      'user_id': report.userId,
      'user_name': report.userName,
      'project_id': report.projectId,
      'project_name': report.projectName,
      'report_datetime': report.reportDate.toIso8601String(),
      'work_place': report.workPlace,
      'work_report': report.workReport,
      'executed_today': report.executedToday,
      'supervisor_name': report.supervisorName,
      'contractor_name': report.contractorName,
      'workers_count': report.workersCount,
      'tomorrow_plan': report.tomorrowPlan,
      'document_path': report.documentPath,
      'images_json': jsonEncode(report.imagePaths),
      'notes': report.notes,
      'materials_json': jsonEncode(report.materials.map((m) => m.toJson()).toList()),
      'expenses_json': jsonEncode(report.expenses.map((e) => e.toJson()).toList()),
      'created_at': DateTime.now().toIso8601String(),
    });
    // خصم إجمالي بنود الماليات من رصيد المهندس
    double total = 0;
    for (final e in report.expenses) {
      total += double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    if (total > 0) {
      final current = await getEngineerBalance(report.userId);
      await setEngineerBalance(report.userId, current - total);
    }
    return rowId;
  }

  /// رصيد مهندس الموقع
  Future<double> getEngineerBalance(int userId) async {
    final db = await database;
    final rows = await db.query('engineer_balance', where: 'user_id = ?', whereArgs: [userId]);
    if (rows.isEmpty) return 0;
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  Future<void> setEngineerBalance(int userId, double balance) async {
    final db = await database;
    await db.insert(
      'engineer_balance',
      {'user_id': userId, 'balance': balance},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addCustody(int userId, double amount, String note) async {
    final db = await database;
    await db.insert('engineer_custody', {
      'user_id': userId,
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
      'note': note,
    });
    final current = await getEngineerBalance(userId);
    await setEngineerBalance(userId, current + amount);
  }

  Future<List<Map<String, dynamic>>> getCustodyRecords({int? userId}) async {
    final db = await database;
    final where = userId != null ? 'user_id = ?' : null;
    final whereArgs = userId != null ? [userId] : null;
    final rows = await db.query('engineer_custody', where: where, whereArgs: whereArgs, orderBy: 'created_at DESC');
    return rows.map((r) => {'id': r['id'], 'user_id': r['user_id'], 'amount': (r['amount'] as num).toDouble(), 'created_at': r['created_at'], 'note': r['note']}).toList();
  }

  /// الحصول على سجلات الحضور لمستخدم معين
  Future<List<AttendanceRecordModel>> getAttendanceRecordsByUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date_time DESC',
    );
    return maps.map((m) => AttendanceRecordModel.fromMap(m)).toList();
  }

  /// الحصول على التقارير اليومية حسب الفلتر (للمدير)
  Future<List<DailyReportData>> getDailyReports({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? userId,
    int? projectId,
  }) async {
    final db = await database;
    final fromStr = DateTime(dateFrom.year, dateFrom.month, dateFrom.day).toIso8601String();
    final toEnd = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59, 999).toIso8601String();
    final where = <String>['report_datetime >= ?', 'report_datetime <= ?'];
    final args = <dynamic>[fromStr, toEnd];
    if (userId != null) {
      where.add('user_id = ?');
      args.add(userId);
    }
    if (projectId != null) {
      where.add('project_id = ?');
      args.add(projectId);
    }
    final maps = await db.query(
      'daily_reports',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'report_datetime DESC',
    );
    return maps.map((m) => DailyReportData.fromDbMap(m)).toList();
  }

  // ——— إدارة المستخدمين (لوح التحكم) ———
  Future<List<UserModel>> getUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'name');
    return maps.map((m) => UserModel.fromMap(m)).toList();
  }

  Future<int> addUser(String name, String email, String role) async {
    final db = await database;
    return db.insert('users', {'name': name, 'email': email.trim().toLowerCase(), 'role': role});
  }

  Future<void> updateUser(int id, String name, String email, String role) async {
    final db = await database;
    await db.update('users', {'name': name, 'email': email.trim().toLowerCase(), 'role': role}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ——— إدارة المشاريع ———
  Future<int> addProject(String name) async {
    final db = await database;
    return db.insert('projects', {'name': name});
  }

  Future<void> updateProject(int id, String name) async {
    final db = await database;
    await db.update('projects', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProject(int id) async {
    final db = await database;
    await db.delete('project_stock', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('zones', where: 'project_id = ?', whereArgs: [id]);
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ——— المناطق (زون) ———
  Future<List<ZoneModel>> getZones(int projectId) async {
    final db = await database;
    final maps = await db.query('zones', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'name');
    return maps.map((m) => ZoneModel.fromMap(m)).toList();
  }

  Future<int> addZone(int projectId, String name) async {
    final db = await database;
    return db.insert('zones', {'project_id': projectId, 'name': name});
  }

  Future<void> updateZone(int id, String name) async {
    final db = await database;
    await db.update('zones', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteZone(int id) async {
    final db = await database;
    await db.delete('buildings', where: 'zone_id = ?', whereArgs: [id]);
    await db.delete('zones', where: 'id = ?', whereArgs: [id]);
  }

  // ——— المباني ———
  Future<List<BuildingModel>> getBuildings(int zoneId) async {
    final db = await database;
    final maps = await db.query('buildings', where: 'zone_id = ?', whereArgs: [zoneId], orderBy: 'name');
    return maps.map((m) => BuildingModel.fromMap(m)).toList();
  }

  Future<int> addBuilding(BuildingModel b) async {
    final db = await database;
    return db.insert('buildings', {
      'zone_id': b.zoneId,
      'name': b.name,
      'storage_info': b.storageInfo,
      'model_details': b.modelDetails,
      'cut_list': b.cutList,
    });
  }

  Future<void> updateBuilding(BuildingModel b) async {
    final db = await database;
    await db.update('buildings', {
      'name': b.name,
      'storage_info': b.storageInfo,
      'model_details': b.modelDetails,
      'cut_list': b.cutList,
    }, where: 'id = ?', whereArgs: [b.id]);
  }

  Future<void> deleteBuilding(int id) async {
    final db = await database;
    await db.delete('units', where: 'building_id = ?', whereArgs: [id]);
    await db.delete('building_materials', where: 'building_id = ?', whereArgs: [id]);
    await db.delete('building_cutlist_images', where: 'building_id = ?', whereArgs: [id]);
    await db.delete('buildings', where: 'id = ?', whereArgs: [id]);
  }

  // ——— مخزن المشروع (أرصدة الخامات) ———
  Future<List<ProjectStockModel>> getProjectStock(int projectId) async {
    final db = await database;
    final maps = await db.query('project_stock', where: 'project_id = ?', whereArgs: [projectId], orderBy: 'material_name');
    return maps.map((m) => ProjectStockModel.fromMap(m)).toList();
  }

  Future<int> addProjectStock(ProjectStockModel s) async {
    final db = await database;
    return db.insert('project_stock', {'project_id': s.projectId, 'material_name': s.materialName, 'quantity': s.quantity, 'unit': s.unit});
  }

  Future<void> updateProjectStock(ProjectStockModel s) async {
    final db = await database;
    await db.update('project_stock', {'material_name': s.materialName, 'quantity': s.quantity, 'unit': s.unit}, where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> deleteProjectStock(int id) async {
    final db = await database;
    await db.delete('project_stock', where: 'id = ?', whereArgs: [id]);
  }

  // ——— الوحدات (مبني → وحدات مثل Th1-M01) ———
  Future<List<UnitModel>> getUnits(int buildingId) async {
    final db = await database;
    final maps = await db.query('units', where: 'building_id = ?', whereArgs: [buildingId], orderBy: 'name');
    return maps.map((m) => UnitModel.fromMap(m)).toList();
  }

  Future<int> addUnit(UnitModel u) async {
    final db = await database;
    return db.insert('units', {'building_id': u.buildingId, 'name': u.name, 'model': u.model, 'image_path': u.imagePath});
  }

  Future<void> updateUnit(UnitModel u) async {
    final db = await database;
    await db.update('units', {'name': u.name, 'model': u.model, 'image_path': u.imagePath}, where: 'id = ?', whereArgs: [u.id]);
  }

  Future<void> deleteUnit(int id) async {
    final db = await database;
    await db.delete('units', where: 'id = ?', whereArgs: [id]);
  }

  // ——— تشوينات المبنى (خامات/كمية/وحدة لكل مبنى) ———
  Future<List<BuildingMaterialModel>> getBuildingMaterials(int buildingId) async {
    final db = await database;
    final maps = await db.query('building_materials', where: 'building_id = ?', whereArgs: [buildingId], orderBy: 'material_name');
    return maps.map((m) => BuildingMaterialModel.fromMap(m)).toList();
  }

  Future<int> addBuildingMaterial(BuildingMaterialModel m) async {
    final db = await database;
    return db.insert('building_materials', {
      'building_id': m.buildingId,
      'material_name': m.materialName,
      'quantity': '',
      'unit': '',
      'length': m.length,
      'pieces_count': m.piecesCount,
      'total_length': m.totalLength,
      'total_area': m.totalArea,
      'image_path': m.imagePath,
    });
  }

  Future<void> updateBuildingMaterial(BuildingMaterialModel m) async {
    final db = await database;
    await db.update('building_materials', {
      'material_name': m.materialName,
      'length': m.length,
      'pieces_count': m.piecesCount,
      'total_length': m.totalLength,
      'total_area': m.totalArea,
      'image_path': m.imagePath,
    }, where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> deleteBuildingMaterial(int id) async {
    final db = await database;
    await db.delete('building_materials', where: 'id = ?', whereArgs: [id]);
  }

  // ——— قطعيات المبنى (صور) ———
  Future<List<BuildingCutlistModel>> getBuildingCutlists(int buildingId) async {
    final db = await database;
    final maps = await db.query('building_cutlist_images', where: 'building_id = ?', whereArgs: [buildingId]);
    return maps.map((m) => BuildingCutlistModel.fromMap(m)).toList();
  }

  Future<int> addBuildingCutlist(BuildingCutlistModel c) async {
    final db = await database;
    return db.insert('building_cutlist_images', {'building_id': c.buildingId, 'image_path': c.imagePath});
  }

  Future<void> deleteBuildingCutlist(int id) async {
    final db = await database;
    await db.delete('building_cutlist_images', where: 'id = ?', whereArgs: [id]);
  }

  // ——— المشرفون ———
  Future<List<SupervisorModel>> getSupervisors() async {
    final db = await database;
    final maps = await db.query('supervisors', orderBy: 'name');
    return maps.map((m) => SupervisorModel.fromMap(m)).toList();
  }

  Future<int> addSupervisor(String name) async {
    final db = await database;
    return db.insert('supervisors', {'name': name});
  }

  Future<void> updateSupervisor(int id, String name) async {
    final db = await database;
    await db.update('supervisors', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSupervisor(int id) async {
    final db = await database;
    await db.delete('supervisors', where: 'id = ?', whereArgs: [id]);
  }

  // ——— المقاولون ———
  Future<List<ContractorModel>> getContractors() async {
    final db = await database;
    final maps = await db.query('contractors', orderBy: 'name');
    return maps.map((m) => ContractorModel.fromMap(m)).toList();
  }

  Future<int> addContractor(String name) async {
    final db = await database;
    return db.insert('contractors', {'name': name});
  }

  Future<void> updateContractor(int id, String name) async {
    final db = await database;
    await db.update('contractors', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteContractor(int id) async {
    final db = await database;
    await db.delete('contractors', where: 'id = ?', whereArgs: [id]);
  }

  // ——— الخامات (إضافة/تعديل/حذف) ———
  Future<int> addMaterial(String name) async {
    final db = await database;
    return db.insert('materials', {'name': name});
  }

  Future<void> updateMaterial(int id, String name) async {
    final db = await database;
    await db.update('materials', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMaterial(int id) async {
    final db = await database;
    await db.delete('materials', where: 'id = ?', whereArgs: [id]);
  }

  /// قائمة الخامات مع الـ id (للوحة التحكم)
  Future<List<Map<String, dynamic>>> getMaterialsWithIds() async {
    final db = await database;
    final maps = await db.query('materials', orderBy: 'name');
    return maps.map((m) => {'id': m['id'], 'name': m['name'] as String}).toList();
  }
}
