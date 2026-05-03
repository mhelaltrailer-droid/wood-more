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
import '../data/default_materials.dart';
import 'icon_visibility_service.dart';

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
      version: 22,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول المستخدمين (كلمة السر الافتراضية المؤقتة: 0000)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        role TEXT NOT NULL,
        password TEXT DEFAULT '0000'
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
    await _createSystemSettingsTable(db);
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
      await db.execute(
        'ALTER TABLE daily_reports ADD COLUMN executed_today TEXT NOT NULL DEFAULT \'\'',
      );
      await db.delete('materials');
      await _seedMaterials(db);
    }
    if (oldVersion < 6) {
      await _createAdminTables(db);
      final existing = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM users WHERE email = 'mouhammedhelal@gmail.com'",
        ),
      );
      if (existing == 0) {
        await db.insert('users', {
          'name': 'مسؤول التطبيق',
          'email': 'mouhammedhelal@gmail.com',
          'role': 'app_admin',
        });
      }
    }
    if (oldVersion < 7) {
      await _createStoreAndUnitsTables(db);
    }
    if (oldVersion < 8) {
      try {
        await db.execute(
          'ALTER TABLE building_materials ADD COLUMN length TEXT DEFAULT \'\'',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE building_materials ADD COLUMN pieces_count TEXT DEFAULT \'\'',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE building_materials ADD COLUMN total_length TEXT DEFAULT \'\'',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE building_materials ADD COLUMN total_area TEXT DEFAULT \'\'',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE building_materials ADD COLUMN image_path TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 9) {
      await _createFinanceTables(db);
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
          "ALTER TABLE users ADD COLUMN password TEXT DEFAULT '0000'",
        );
        await db.rawUpdate(
          "UPDATE users SET password = ? WHERE password IS NULL",
          ['0000'],
        );
      } catch (_) {}
    }
    if (oldVersion < 12) {
      try {
        await db.execute(
          'ALTER TABLE engineer_custody ADD COLUMN document_path TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 13) {
      final existing = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM users WHERE LOWER(email) = 'h@h.com'",
        ),
      );
      if (existing == 0) {
        await db.insert('users', {
          'name': 'Helal',
          'email': 'h@h.com',
          'role': 'app_admin',
          'password': '123',
        });
      }
    }
    if (oldVersion < 14) {
      final existing = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM users WHERE LOWER(email) = 'account@gmail.com'",
        ),
      );
      if (existing == 0) {
        await db.insert('users', {
          'name': 'account manager',
          'email': 'Account@gmail.com',
          'role': 'accountant',
          'password': '0000',
        });
      }
    }
    if (oldVersion < 15) {
      try {
        await db.execute(
          "ALTER TABLE engineer_custody ADD COLUMN movement_type TEXT DEFAULT 'custody'",
        );
      } catch (_) {}
    }
    if (oldVersion < 16) {
      try {
        await db.execute(
          'ALTER TABLE daily_reports ADD COLUMN contractors_json TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 17) {
      try {
        await db.execute(
          'ALTER TABLE detailed_reports ADD COLUMN project_name TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 18) {
      try {
        await db.execute(
          'ALTER TABLE detailed_reports ADD COLUMN expenses_json TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 21) {
      try {
        await db.execute(
          'ALTER TABLE detailed_reports ADD COLUMN attachments_json TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 22) {
      await _createSystemSettingsTable(db);
    }
    if (oldVersion < 20) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS detailed_report_lines_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            detailed_report_id INTEGER NOT NULL,
            contractor_id INTEGER,
            contractor_workers_count INTEGER NOT NULL DEFAULT 0,
            self_workers_count INTEGER NOT NULL DEFAULT 0,
            zone_id INTEGER,
            building_id INTEGER,
            location_id INTEGER,
            phase_id INTEGER NOT NULL,
            workers_count INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          INSERT INTO detailed_report_lines_new (id, detailed_report_id, contractor_id, contractor_workers_count, self_workers_count, zone_id, building_id, location_id, phase_id, workers_count)
          SELECT id, detailed_report_id, contractor_id, contractor_workers_count, self_workers_count, zone_id, building_id, location_id, phase_id, workers_count FROM detailed_report_lines
        ''');
        await db.execute('DROP TABLE detailed_report_lines');
        await db.execute(
          'ALTER TABLE detailed_report_lines_new RENAME TO detailed_report_lines',
        );
      } catch (_) {}
    }
    if (oldVersion < 19) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS location_materials (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
          material_name TEXT NOT NULL,
          quantity TEXT NOT NULL,
          unit TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS location_withdrawal (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          location_id INTEGER NOT NULL UNIQUE REFERENCES project_locations(id) ON DELETE CASCADE,
          user_id INTEGER NOT NULL REFERENCES users(id),
          user_name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          disbursement_permit_images_json TEXT,
          delivery_permit_images_json TEXT
        )
      ''');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_stock_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id INTEGER NOT NULL,
          material_name TEXT NOT NULL,
          unit TEXT NOT NULL,
          quantity_delta REAL NOT NULL,
          type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          user_id INTEGER,
          user_name TEXT NOT NULL,
          FOREIGN KEY (project_id) REFERENCES projects (id)
        )
      ''');
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
        document_path TEXT,
        movement_type TEXT DEFAULT 'custody',
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _createSystemSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.insert('app_settings', {
      'key': 'system_locked',
      'value': '0',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_stock_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        material_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity_delta REAL NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        user_id INTEGER,
        user_name TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id)
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
        contractors_json TEXT,
        tomorrow_plan TEXT NOT NULL,
        document_path TEXT,
        images_json TEXT,
        notes TEXT,
        materials_json TEXT NOT NULL,
        expenses_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM materials'),
    );
    if (count == 0) await _seedMaterials(db);
  }

  Future<void> _seedMaterials(Database db) async {
    for (final name in defaultMaterialsList) {
      await db.insert('materials', {'name': name});
    }
  }

  Future<void> _seedData(Database db) async {
    // المستخدمون
    await db.insert('users', {
      'name': 'Hany',
      'email': 'hany.samir1708@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Emam',
      'email': 'amirelazab46@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Mansur',
      'email': 'saedm0566@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Mahmud',
      'email': 'mahmoudsiko630@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Abdhusseny',
      'email': 'abdallaelhosseny1011@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Hamza',
      'email': 'hamzamhamad704@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Gohary',
      'email': 'mohamedelgohary371@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Amr',
      'email': 'amrelshabrawy55@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Hassan',
      'email': 'mouhammed.helal@gmail.com',
      'role': 'site_engineer',
    });
    await db.insert('users', {
      'name': 'Helal',
      'email': 'mouhamedhelal.cor@gmail.com',
      'role': 'site_engineer_manager',
    });
    await db.insert('users', {
      'name': 'Shams',
      'email': 'islam.shams2050@gmail.com',
      'role': 'site_engineer_manager',
    });
    await db.insert('users', {
      'name': 'Abdrhman',
      'email': 'AbdelrhmanEllaithy828@gmail.com',
      'role': 'site_engineer_manager',
    });
    await db.insert('users', {
      'name': 'مسؤول التطبيق',
      'email': 'mouhammedhelal@gmail.com',
      'role': 'app_admin',
    });
    await db.insert('users', {
      'name': 'Helal',
      'email': 'h@h.com',
      'role': 'app_admin',
      'password': '123',
    });
    await db.insert('users', {
      'name': 'account manager',
      'email': 'Account@gmail.com',
      'role': 'accountant',
      'password': '0000',
    });

    await _seedProjects(db);
  }

  Future<void> _createAdminTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        parent_id INTEGER REFERENCES project_locations (id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'folder' CHECK (type IN ('folder', 'work_site')),
        display_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_phases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS detailed_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        report_datetime TEXT NOT NULL,
        project_id INTEGER NOT NULL,
        project_name TEXT,
        supervisor_id INTEGER,
        created_at TEXT NOT NULL,
        summary TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS detailed_report_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        detailed_report_id INTEGER NOT NULL,
        contractor_id INTEGER,
        contractor_workers_count INTEGER NOT NULL DEFAULT 0,
        self_workers_count INTEGER NOT NULL DEFAULT 0,
        zone_id INTEGER,
        building_id INTEGER,
        location_id INTEGER,
        phase_id INTEGER NOT NULL,
        workers_count INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id INTEGER NOT NULL,
        material_name TEXT NOT NULL,
        quantity TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_withdrawal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id INTEGER NOT NULL UNIQUE,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        disbursement_permit_images_json TEXT,
        delivery_permit_images_json TEXT
      )
    ''');
    await _seedWorkPhases(db);
  }

  Future<void> _seedWorkPhases(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM work_phases'),
        ) ??
        0;
    if (count > 0) return;
    await db.insert('work_phases', {'name': 'تركيب اكسسوارات'});
    await db.insert('work_phases', {'name': 'تقطيع WPC'});
    await db.insert('work_phases', {'name': 'تركيب WPC'});
    await db.insert('work_phases', {'name': 'معالجة'});
    await db.insert('work_phases', {'name': 'دهان'});
    await db.insert('work_phases', {'name': 'تشوين'});
    await db.insert('work_phases', {'name': 'تركيب ارضيات'});
    await db.insert('work_phases', {'name': 'تركيب Q.round + وزر'});
  }

  Future<void> _seedProjects(Database db) async {
    final projects = [
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

  /// التحقق من تسجيل الدخول (بريد + كلمة سر)، كلمة السر الافتراضية المؤقتة: 0000
  Future<UserModel?> validateLogin(String email, String password) async {
    final db = await database;
    final emailNorm = email.trim().toLowerCase();
    final pwdNorm = password.trim();
    final maps = await db.rawQuery(
      'SELECT * FROM users WHERE LOWER(TRIM(email)) = ?',
      [emailNorm],
    );
    if (maps.isEmpty) return null;
    final row = maps.first;
    final stored = (row['password']?.toString() ?? '0000').trim();
    if (stored.isEmpty) return null;
    if (pwdNorm != stored) return null;
    return UserModel.fromMap(row);
  }

  Future<bool> isSystemLocked() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['system_locked'],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final value = (rows.first['value']?.toString() ?? '0').trim();
    return value == '1' || value.toLowerCase() == 'true';
  }

  Future<void> setSystemLocked(bool locked) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': 'system_locked',
      'value': locked ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Map<String, bool>>> getHomeIconsVisibilityConfig() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['home_icons_visibility'],
      limit: 1,
    );
    if (rows.isEmpty) return IconVisibilityService.normalizeAllConfig(null);
    final raw = rows.first['value']?.toString();
    if (raw == null || raw.trim().isEmpty)
      return IconVisibilityService.normalizeAllConfig(null);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return IconVisibilityService.normalizeAllConfig(decoded);
      }
      if (decoded is Map) {
        return IconVisibilityService.normalizeAllConfig(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (_) {}
    return IconVisibilityService.normalizeAllConfig(null);
  }

  Future<void> setHomeIconsVisibilityForRole(
    String role,
    Map<String, bool> roleConfig,
  ) async {
    final db = await database;
    final current = await getHomeIconsVisibilityConfig();
    current[role] = Map<String, bool>.from(roleConfig);
    await db.insert('app_settings', {
      'key': 'home_icons_visibility',
      'value': jsonEncode(current),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// الحصول على جميع المشاريع (بدون تكرار الاسم)
  Future<List<ProjectModel>> getProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'name');
    final list = maps.map((m) => ProjectModel.fromMap(m)).toList();
    return _deduplicateProjectsByName(list);
  }

  /// الحصول على جميع المشاريع كما هي (يشمل الأسماء المكررة).
  Future<List<ProjectModel>> getProjectsRaw() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'name, id');
    return maps.map((m) => ProjectModel.fromMap(m)).toList();
  }

  static List<ProjectModel> _deduplicateProjectsByName(
    List<ProjectModel> list,
  ) {
    final seen = <String>{};
    return list.where((p) => seen.add(p.name)).toList();
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

  /// حذف سجل حضور/انصراف (صلاحية مسؤول التطبيق فقط)
  Future<void> deleteAttendanceRecord(int id) async {
    final db = await database;
    await db.delete('attendance_records', where: 'id = ?', whereArgs: [id]);
  }

  /// الحصول على قائمة الخامات
  Future<List<String>> getMaterials() async {
    final db = await database;
    final maps = await db.query('materials', orderBy: 'name');
    return maps.map((m) => m['name'] as String).toList();
  }

  /// حفظ التقرير اليومي (ويتم خصم إجمالي بنود الماليات من رصيد المهندس، وخصم الخامات من مخزن المشروع)
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
      'contractors_json': report.contractors.isEmpty
          ? null
          : jsonEncode(report.contractors.map((c) => c.toJson()).toList()),
      'tomorrow_plan': report.tomorrowPlan,
      'document_path': report.documentPath,
      'images_json': jsonEncode(report.imagePaths),
      'notes': report.notes,
      'materials_json': jsonEncode(
        report.materials.map((m) => m.toJson()).toList(),
      ),
      'expenses_json': jsonEncode(
        report.expenses.map((e) => e.toJson()).toList(),
      ),
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
    return rowId;
  }

  /// حذف تقرير يومي (صلاحية مسؤول التطبيق فقط)
  Future<void> deleteDailyReport(int id) async {
    final db = await database;
    await db.delete('daily_reports', where: 'id = ?', whereArgs: [id]);
  }

  /// رصيد مهندس الموقع
  Future<double> getEngineerBalance(int userId) async {
    final db = await database;
    final rows = await db.query(
      'engineer_balance',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  Future<void> setEngineerBalance(int userId, double balance) async {
    final db = await database;
    await db.insert('engineer_balance', {
      'user_id': userId,
      'balance': balance,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addCustody(
    int userId,
    double amount,
    String note, [
    String? documentPath,
  ]) async {
    final db = await database;
    await db.insert('engineer_custody', {
      'user_id': userId,
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
      'note': note,
      'document_path': documentPath,
      'movement_type': 'custody',
    });
    final current = await getEngineerBalance(userId);
    await setEngineerBalance(userId, current - amount);
  }

  /// تسجيل حركة إضافة رصيد أو سحب رصيد فقط (بدون تغيير الرصيد - يتم من واجهة الماليات)
  Future<void> addBalanceMovement(
    int userId,
    double amount,
    String note,
    String movementType,
  ) async {
    final db = await database;
    await db.insert('engineer_custody', {
      'user_id': userId,
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
      'note': note,
      'document_path': null,
      'movement_type': movementType,
    });
  }

  Future<List<Map<String, dynamic>>> getCustodyRecords({int? userId}) async {
    final db = await database;
    final where = userId != null ? 'user_id = ?' : null;
    final whereArgs = userId != null ? [userId] : null;
    final rows = await db.query(
      'engineer_custody',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (r) => {
            'id': r['id'],
            'user_id': r['user_id'],
            'amount': (r['amount'] as num).toDouble(),
            'created_at': r['created_at'],
            'note': r['note'],
            'document_path': r['document_path'],
            'movement_type': r['movement_type'] as String? ?? 'custody',
          },
        )
        .toList();
  }

  /// الحصول على سجلات الحضور لمستخدم معين
  Future<List<AttendanceRecordModel>> getAttendanceRecordsByUser(
    int userId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'attendance_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date_time DESC',
    );
    return maps.map((m) => AttendanceRecordModel.fromMap(m)).toList();
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

  /// الحصول على التقارير اليومية حسب الفلتر (للمدير)
  Future<List<DailyReportData>> getDailyReports({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? userId,
    int? projectId,
  }) async {
    final db = await database;
    final fromStr = DateTime(
      dateFrom.year,
      dateFrom.month,
      dateFrom.day,
    ).toIso8601String();
    final toEnd = DateTime(
      dateTo.year,
      dateTo.month,
      dateTo.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();
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

  Future<int> addUser(
    String name,
    String email,
    String password,
    String role,
  ) async {
    final db = await database;
    final pwd = password.trim().isEmpty ? '0000' : password.trim();
    return db.insert('users', {
      'name': name,
      'email': email.trim().toLowerCase(),
      'role': role,
      'password': pwd,
    });
  }

  Future<void> updateUser(
    int id,
    String name,
    String email,
    String role, [
    String? password,
  ]) async {
    final db = await database;
    final data = <String, dynamic>{
      'name': name,
      'email': email.trim().toLowerCase(),
      'role': role,
    };
    if (password != null && password.trim().isNotEmpty) {
      data['password'] = password.trim();
    }
    await db.update('users', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ——— إدارة المشاريع ———
  Future<int> addProject(String name) async {
    final db = await database;
    final normalized = name.trim().toLowerCase();
    final existing = await db.query(
      'projects',
      columns: ['id'],
      where: 'LOWER(TRIM(name)) = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return db.insert('projects', {'name': name.trim()});
  }

  Future<void> updateProject(int id, String name) async {
    final db = await database;
    await db.update(
      'projects',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final maps = await db.query(
      'zones',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'name',
    );
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

  // ——— هيكل مواقع المشروع (project_locations) ———
  Future<List<ProjectLocationModel>> getProjectLocations(int projectId) async {
    final db = await database;
    final maps = await db.query(
      'project_locations',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'display_order, id',
    );
    return maps.map((m) => ProjectLocationModel.fromMap(m)).toList();
  }

  Future<int> addProjectLocation({
    required int projectId,
    int? parentId,
    required String name,
    required String type,
    int displayOrder = 0,
  }) async {
    final db = await database;
    return db.insert('project_locations', {
      'project_id': projectId,
      'parent_id': parentId,
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
    final db = await database;
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (displayOrder != null) data['display_order'] = displayOrder;
    if (data.isEmpty) return;
    await db.update(
      'project_locations',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProjectLocation(int id) async {
    final db = await database;
    final children = await db.query(
      'project_locations',
      where: 'parent_id = ?',
      whereArgs: [id],
    );
    for (final c in children) {
      await deleteProjectLocation(c['id'] as int);
    }
    await db.delete(
      'location_materials',
      where: 'location_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'location_withdrawal',
      where: 'location_id = ?',
      whereArgs: [id],
    );
    await db.delete('project_locations', where: 'id = ?', whereArgs: [id]);
  }

  // ——— هيكلة المخازن: خامات لكل موقع فرعي ———
  Future<List<LocationMaterialModel>> getLocationMaterials(
    int locationId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'location_materials',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'material_name',
    );
    return maps.map((m) => LocationMaterialModel.fromMap(m)).toList();
  }

  Future<int> addLocationMaterial(LocationMaterialModel m) async {
    final db = await database;
    return db.insert('location_materials', {
      'location_id': m.locationId,
      'material_name': m.materialName,
      'quantity': m.quantity,
      'unit': m.unit,
    });
  }

  Future<void> updateLocationMaterial(LocationMaterialModel m) async {
    final db = await database;
    await db.update(
      'location_materials',
      {'material_name': m.materialName, 'quantity': m.quantity, 'unit': m.unit},
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteLocationMaterial(int id) async {
    final db = await database;
    await db.delete('location_materials', where: 'id = ?', whereArgs: [id]);
  }

  Future<LocationWithdrawalModel?> getLocationWithdrawal(int locationId) async {
    final db = await database;
    final maps = await db.query(
      'location_withdrawal',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
    if (maps.isEmpty) return null;
    return LocationWithdrawalModel.fromMap(maps.first);
  }

  Future<void> createLocationWithdrawal({
    required int locationId,
    required int userId,
    required String userName,
    String? disbursementPermitImagesJson,
    String? deliveryPermitImagesJson,
  }) async {
    final db = await database;
    final locMaps = await db.query(
      'project_locations',
      where: 'id = ?',
      whereArgs: [locationId],
    );
    if (locMaps.isEmpty) throw Exception('الموقع غير موجود');
    final projectId = locMaps.first['project_id'] as int;
    final materials = await getLocationMaterials(locationId);
    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    for (final m in materials) {
      final qty =
          double.tryParse(m.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      if (qty <= 0) continue;
      final unit = m.unit.isEmpty ? 'وحدة' : m.unit;
      final list = await getProjectStock(projectId);
      final row = list.cast<ProjectStockModel?>().firstWhere(
        (r) => r!.materialName == m.materialName,
        orElse: () => null,
      );
      if (row != null) {
        final current =
            double.tryParse(row.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ??
            0;
        final newQty = current - qty;
        await updateProjectStock(
          ProjectStockModel(
            id: row.id,
            projectId: row.projectId,
            materialName: row.materialName,
            quantity: newQty.toStringAsFixed(2),
            unit: row.unit,
          ),
        );
        await addProjectStockLedgerEntry(
          projectId: projectId,
          materialName: m.materialName,
          unit: row.unit,
          quantityDelta: -qty,
          type: 'withdraw_location',
          userName: userName,
          createdAt: now,
          userId: userId,
        );
      }
    }
    await db.insert('location_withdrawal', {
      'location_id': locationId,
      'user_id': userId,
      'user_name': userName,
      'created_at': nowStr,
      'disbursement_permit_images_json': disbursementPermitImagesJson,
      'delivery_permit_images_json': deliveryPermitImagesJson,
    });
  }

  /// إلغاء سحب الخامات: حذف السجل واسترجاع أرصدة المشروع وحذف حركات withdraw_location المرتبطة.
  Future<void> deleteLocationWithdrawal(int locationId) async {
    final db = await database;
    final withdrawal = await getLocationWithdrawal(locationId);
    if (withdrawal == null) return;

    final locMaps = await db.query(
      'project_locations',
      where: 'id = ?',
      whereArgs: [locationId],
    );
    if (locMaps.isEmpty) throw Exception('الموقع غير موجود');
    final projectId = locMaps.first['project_id'] as int;

    final allLedgers = await db.query(
      'project_stock_ledger',
      where: 'project_id = ? AND type = ?',
      whereArgs: [projectId, 'withdraw_location'],
    );

    bool ledgerMatches(Map<String, dynamic> row) {
      final uid = row['user_id'];
      final uidInt = uid is int ? uid : int.tryParse(uid?.toString() ?? '');
      if (uidInt != withdrawal.userId) return false;
      final entryTime = DateTime.tryParse(row['created_at'].toString());
      if (entryTime == null) return false;
      return entryTime.difference(withdrawal.createdAt).inMilliseconds.abs() <=
          2000;
    }

    final ledgers = allLedgers.where(ledgerMatches).toList();

    for (final row in ledgers) {
      final delta = (row['quantity_delta'] as num?)?.toDouble() ?? 0;
      if (delta >= 0) continue;
      final addBack = -delta;
      final materialName = row['material_name'] as String;
      final list = await getProjectStock(projectId);
      final stockRow = list.cast<ProjectStockModel?>().firstWhere(
        (r) => r!.materialName == materialName,
        orElse: () => null,
      );
      if (stockRow != null) {
        final current =
            double.tryParse(
              stockRow.quantity.replaceAll(RegExp(r'[^\d.]'), ''),
            ) ??
            0;
        final newQty = current + addBack;
        await updateProjectStock(
          ProjectStockModel(
            id: stockRow.id,
            projectId: stockRow.projectId,
            materialName: stockRow.materialName,
            quantity: newQty.toStringAsFixed(2),
            unit: stockRow.unit,
          ),
        );
      } else {
        final unit = (row['unit'] as String?)?.isNotEmpty == true
            ? row['unit'] as String
            : 'وحدة';
        await addProjectStock(
          ProjectStockModel(
            id: 0,
            projectId: projectId,
            materialName: materialName,
            quantity: addBack.toStringAsFixed(2),
            unit: unit,
          ),
        );
      }
    }

    for (final row in ledgers) {
      await db.delete(
        'project_stock_ledger',
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    await db.delete(
      'location_withdrawal',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
  }

  // ——— المباني ———
  Future<List<BuildingModel>> getBuildings(int zoneId) async {
    final db = await database;
    final maps = await db.query(
      'buildings',
      where: 'zone_id = ?',
      whereArgs: [zoneId],
      orderBy: 'name',
    );
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
    await db.update(
      'buildings',
      {
        'name': b.name,
        'storage_info': b.storageInfo,
        'model_details': b.modelDetails,
        'cut_list': b.cutList,
      },
      where: 'id = ?',
      whereArgs: [b.id],
    );
  }

  Future<void> deleteBuilding(int id) async {
    final db = await database;
    await db.delete('units', where: 'building_id = ?', whereArgs: [id]);
    await db.delete(
      'building_materials',
      where: 'building_id = ?',
      whereArgs: [id],
    );
    await db.delete(
      'building_cutlist_images',
      where: 'building_id = ?',
      whereArgs: [id],
    );
    await db.delete('buildings', where: 'id = ?', whereArgs: [id]);
  }

  // ——— مخزن المشروع (أرصدة الخامات) ———
  Future<List<ProjectStockModel>> getProjectStock(int projectId) async {
    final db = await database;
    final maps = await db.query(
      'project_stock',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'material_name',
    );
    return maps.map((m) => ProjectStockModel.fromMap(m)).toList();
  }

  Future<int> addProjectStock(ProjectStockModel s) async {
    final db = await database;
    return db.insert('project_stock', {
      'project_id': s.projectId,
      'material_name': s.materialName,
      'quantity': s.quantity,
      'unit': s.unit,
    });
  }

  Future<void> updateProjectStock(ProjectStockModel s) async {
    final db = await database;
    await db.update(
      'project_stock',
      {'material_name': s.materialName, 'quantity': s.quantity, 'unit': s.unit},
      where: 'id = ?',
      whereArgs: [s.id],
    );
  }

  Future<void> deleteProjectStock(int id) async {
    final db = await database;
    await db.delete('project_stock', where: 'id = ?', whereArgs: [id]);
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
    final db = await database;
    await db.insert('project_stock_ledger', {
      'project_id': projectId,
      'material_name': materialName,
      'unit': unit,
      'quantity_delta': quantityDelta,
      'type': type,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'user_id': userId,
      'user_name': userName,
    });
  }

  Future<List<ProjectStockLedgerModel>> getStockLedger(
    int projectId,
    String materialName,
  ) async {
    final db = await database;
    final maps = await db.query(
      'project_stock_ledger',
      where: 'project_id = ? AND material_name = ?',
      whereArgs: [projectId, materialName],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => ProjectStockLedgerModel.fromMap(m)).toList();
  }

  /// خصم كمية من رصيد خامة في مخزن المشروع (عند حفظ التقرير اليومي). المطابقة باسم الخامة فقط، والخصم على رقم الكمية فقط (الوحدة ثابتة: متر / عود / متر مربع).
  Future<bool> deductProjectStock(
    int projectId,
    String materialName,
    String unit,
    double quantity,
    String engineerName,
    DateTime reportDate,
  ) async {
    final list = await getProjectStock(projectId);
    final row = list.cast<ProjectStockModel?>().firstWhere(
      (r) => r!.materialName == materialName,
      orElse: () => null,
    );
    if (row == null) return false;
    final current =
        double.tryParse(row.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final newQty = current - quantity;
    await updateProjectStock(
      ProjectStockModel(
        id: row.id,
        projectId: row.projectId,
        materialName: row.materialName,
        quantity: newQty.toStringAsFixed(2),
        unit: row.unit,
      ),
    );
    await addProjectStockLedgerEntry(
      projectId: projectId,
      materialName: materialName,
      unit: row.unit,
      quantityDelta: -quantity,
      type: 'deduct_report',
      userName: engineerName,
      createdAt: reportDate,
    );
    return true;
  }

  // ——— الوحدات (مبني → وحدات مثل Th1-M01) ———
  Future<List<UnitModel>> getUnits(int buildingId) async {
    final db = await database;
    final maps = await db.query(
      'units',
      where: 'building_id = ?',
      whereArgs: [buildingId],
      orderBy: 'name',
    );
    return maps.map((m) => UnitModel.fromMap(m)).toList();
  }

  Future<int> addUnit(UnitModel u) async {
    final db = await database;
    return db.insert('units', {
      'building_id': u.buildingId,
      'name': u.name,
      'model': u.model,
      'image_path': u.imagePath,
    });
  }

  Future<void> updateUnit(UnitModel u) async {
    final db = await database;
    await db.update(
      'units',
      {'name': u.name, 'model': u.model, 'image_path': u.imagePath},
      where: 'id = ?',
      whereArgs: [u.id],
    );
  }

  Future<void> deleteUnit(int id) async {
    final db = await database;
    await db.delete('units', where: 'id = ?', whereArgs: [id]);
  }

  // ——— تشوينات المبنى (خامات/كمية/وحدة لكل مبنى) ———
  Future<List<BuildingMaterialModel>> getBuildingMaterials(
    int buildingId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'building_materials',
      where: 'building_id = ?',
      whereArgs: [buildingId],
      orderBy: 'material_name',
    );
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
    await db.update(
      'building_materials',
      {
        'material_name': m.materialName,
        'length': m.length,
        'pieces_count': m.piecesCount,
        'total_length': m.totalLength,
        'total_area': m.totalArea,
        'image_path': m.imagePath,
      },
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteBuildingMaterial(int id) async {
    final db = await database;
    await db.delete('building_materials', where: 'id = ?', whereArgs: [id]);
  }

  // ——— قطعيات المبنى (صور) ———
  Future<List<BuildingCutlistModel>> getBuildingCutlists(int buildingId) async {
    final db = await database;
    final maps = await db.query(
      'building_cutlist_images',
      where: 'building_id = ?',
      whereArgs: [buildingId],
    );
    return maps.map((m) => BuildingCutlistModel.fromMap(m)).toList();
  }

  Future<int> addBuildingCutlist(BuildingCutlistModel c) async {
    final db = await database;
    return db.insert('building_cutlist_images', {
      'building_id': c.buildingId,
      'image_path': c.imagePath,
    });
  }

  Future<void> deleteBuildingCutlist(int id) async {
    final db = await database;
    await db.delete(
      'building_cutlist_images',
      where: 'id = ?',
      whereArgs: [id],
    );
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
    await db.update(
      'supervisors',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    await db.update(
      'contractors',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteContractor(int id) async {
    final db = await database;
    // فك الربط من سطور التقرير المفصل قبل الحذف لمنع فشل قيد المفتاح الخارجي
    await db.update(
      'detailed_report_lines',
      {'contractor_id': null},
      where: 'contractor_id = ?',
      whereArgs: [id],
    );
    await db.delete('contractors', where: 'id = ?', whereArgs: [id]);
  }

  // ——— الخامات (إضافة/تعديل/حذف) ———
  Future<int> addMaterial(String name) async {
    final db = await database;
    return db.insert('materials', {'name': name});
  }

  Future<void> updateMaterial(int id, String name) async {
    final db = await database;
    await db.update(
      'materials',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMaterial(int id) async {
    final db = await database;
    await db.delete('materials', where: 'id = ?', whereArgs: [id]);
  }

  /// قائمة الخامات مع الـ id (للوحة التحكم)
  Future<List<Map<String, dynamic>>> getMaterialsWithIds() async {
    final db = await database;
    final maps = await db.query('materials', orderBy: 'name');
    return maps
        .map((m) => {'id': m['id'], 'name': m['name'] as String})
        .toList();
  }

  Future<List<WorkPhaseModel>> getWorkPhases() async {
    final db = await database;
    final maps = await db.query('work_phases', orderBy: 'id');
    return maps
        .map((m) => WorkPhaseModel.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<int> addDetailedReport(DetailedReportModel report) async {
    final db = await database;
    final id = await db.insert('detailed_reports', {
      'user_id': report.userId,
      'user_name': report.userName,
      'report_datetime': report.reportDatetime.toIso8601String(),
      'project_id': report.projectId ?? 0,
      'project_name': report.projectName,
      'supervisor_id': report.supervisorId,
      'created_at': (report.createdAt ?? DateTime.now()).toIso8601String(),
      'summary': report.summary,
      'expenses_json': report.expenses.isEmpty
          ? null
          : jsonEncode(report.expenses.map((e) => e.toJson()).toList()),
      'attachments_json': report.attachments.isEmpty
          ? null
          : jsonEncode(report.attachments.map((e) => e.toJson()).toList()),
    });
    for (final line in report.lines) {
      await db.insert('detailed_report_lines', {
        'detailed_report_id': id,
        'contractor_id': line.contractorId,
        'contractor_workers_count': line.contractorWorkersCount,
        'self_workers_count': line.selfWorkersCount,
        'zone_id': line.zoneId,
        'building_id': line.buildingId,
        'location_id': line.locationId,
        'phase_id': line.phaseId,
        'workers_count': line.workersCount,
      });
    }
    // خصم إجمالي بنود الماليات من رصيد مهندس الموقع (مستخدم كاتب التقرير)
    double total = 0;
    for (final e in report.expenses) {
      total += double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    if (total > 0) {
      final current = await getEngineerBalance(report.userId);
      await setEngineerBalance(report.userId, current - total);
    }
    return id as int;
  }

  /// استبدال بيانات التقرير المفصّل وسطوره (بدون تغيير منطق الماليات هنا).
  Future<void> updateDetailedReport(
    int reportId,
    DetailedReportModel report,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'detailed_report_lines',
        where: 'detailed_report_id = ?',
        whereArgs: [reportId],
      );
      await txn.update(
        'detailed_reports',
        {
          'user_id': report.userId,
          'user_name': report.userName,
          'report_datetime': report.reportDatetime.toIso8601String(),
          'project_id': report.projectId ?? 0,
          'project_name': report.projectName,
          'supervisor_id': report.supervisorId,
          'summary': report.summary,
          'expenses_json': report.expenses.isEmpty
              ? null
              : jsonEncode(report.expenses.map((e) => e.toJson()).toList()),
          'attachments_json': report.attachments.isEmpty
              ? null
              : jsonEncode(report.attachments.map((e) => e.toJson()).toList()),
        },
        where: 'id = ?',
        whereArgs: [reportId],
      );
      for (final line in report.lines) {
        await txn.insert('detailed_report_lines', {
          'detailed_report_id': reportId,
          'contractor_id': line.contractorId,
          'contractor_workers_count': line.contractorWorkersCount,
          'self_workers_count': line.selfWorkersCount,
          'zone_id': line.zoneId,
          'building_id': line.buildingId,
          'location_id': line.locationId,
          'phase_id': line.phaseId,
          'workers_count': line.workersCount,
        });
      }
    });
  }

  /// تحديث بنود الماليات فقط (للتقارير المحفوظة مسبقاً دون صرف) مع تعديل رصيد المهندس بالفرق.
  Future<void> patchDetailedReportExpenses({
    required int reportId,
    required int userId,
    required List<ExpenseItem> expenses,
  }) async {
    final db = await database;
    final rows = await db.query(
      'detailed_reports',
      where: 'id = ?',
      whereArgs: [reportId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('التقرير غير موجود');
    }
    final uid = rows.first['user_id'];
    if (uid != userId) {
      throw Exception('لا يمكن تعديل تقرير لمستخدم آخر');
    }
    double oldTotal = 0;
    final oldJson = rows.first['expenses_json'] as String?;
    if (oldJson != null && oldJson.trim().isNotEmpty) {
      try {
        final oldList = jsonDecode(oldJson) as List<dynamic>?;
        if (oldList != null) {
          for (final e in oldList) {
            final m = Map<String, dynamic>.from(e as Map);
            oldTotal +=
                double.tryParse(
                  (m['amount'] ?? '').toString().replaceAll(
                    RegExp(r'[^\d.]'),
                    '',
                  ),
                ) ??
                0;
          }
        }
      } catch (_) {}
    }
    double newTotal = 0;
    for (final e in expenses) {
      newTotal +=
          double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    }
    final delta = newTotal - oldTotal;
    if (delta != 0) {
      final current = await getEngineerBalance(userId);
      await setEngineerBalance(userId, current - delta);
    }
    await db.update(
      'detailed_reports',
      {
        'expenses_json': expenses.isEmpty
            ? null
            : jsonEncode(expenses.map((e) => e.toJson()).toList()),
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  /// حذف تقرير مفصّل واسترجاع خصم الماليات من رصيد المهندس إن وُجد
  Future<void> deleteDetailedReport(int id) async {
    final db = await database;
    final rows = await db.query(
      'detailed_reports',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final userId = rows.first['user_id'] as int;
    final expJson = rows.first['expenses_json'] as String?;
    double total = 0;
    if (expJson != null && expJson.trim().isNotEmpty) {
      try {
        final expList = jsonDecode(expJson) as List<dynamic>?;
        if (expList != null) {
          for (final e in expList) {
            final m = Map<String, dynamic>.from(e as Map);
            total +=
                double.tryParse(
                  (m['amount'] ?? '').toString().replaceAll(
                    RegExp(r'[^\d.]'),
                    '',
                  ),
                ) ??
                0;
          }
        }
      } catch (_) {}
    }
    if (total > 0) {
      final current = await getEngineerBalance(userId);
      await setEngineerBalance(userId, current + total);
    }
    await db.delete(
      'detailed_report_lines',
      where: 'detailed_report_id = ?',
      whereArgs: [id],
    );
    await db.delete('detailed_reports', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DetailedReportModel>> getDetailedReports({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? userId,
    int? projectId,
  }) async {
    final db = await database;
    var where = '1=1';
    final args = <dynamic>[];
    final fromStr = DateTime(
      dateFrom.year,
      dateFrom.month,
      dateFrom.day,
    ).toIso8601String();
    final toStr = DateTime(
      dateTo.year,
      dateTo.month,
      dateTo.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();
    where += ' AND report_datetime >= ?';
    args.add(fromStr);
    where += ' AND report_datetime <= ?';
    args.add(toStr);
    if (userId != null) {
      where += ' AND user_id = ?';
      args.add(userId);
    }
    if (projectId != null) {
      where += ' AND project_id = ?';
      args.add(projectId);
    }
    final maps = await db.query(
      'detailed_reports',
      where: where,
      whereArgs: args,
      orderBy: 'report_datetime DESC',
    );
    final projectNames = <int, String>{};
    try {
      final projectRows = await db.query('projects', columns: ['id', 'name']);
      for (final r in projectRows) {
        final id = r['id'] as int;
        projectNames[id] = r['name'] as String;
      }
    } catch (_) {}
    final list = <DetailedReportModel>[];
    for (final row in maps) {
      final reportId = row['id'] as int;
      final lineMaps = await db.query(
        'detailed_report_lines',
        where: 'detailed_report_id = ?',
        whereArgs: [reportId],
        orderBy: 'id',
      );
      final lines = lineMaps
          .map(
            (l) => DetailedReportLineModel.fromMap({
              'id': l['id'],
              'contractor_id': l['contractor_id'],
              'contractor_workers_count': l['contractor_workers_count'],
              'self_workers_count': l['self_workers_count'],
              'zone_id': l['zone_id'],
              'building_id': l['building_id'],
              'location_id': l['location_id'],
              'phase_id': l['phase_id'],
              'workers_count': l['workers_count'],
            }),
          )
          .toList();
      final projectIdVal = row['project_id'];
      final int? pid = projectIdVal != null && (projectIdVal as int) != 0
          ? projectIdVal as int
          : null;
      final String? storedName = row['project_name']?.toString();
      final String? resolvedName =
          storedName ?? (pid != null ? projectNames[pid] : null);
      List<ExpenseItem> expenses = [];
      try {
        final expJson = row['expenses_json'] as String?;
        if (expJson != null && expJson.trim().isNotEmpty) {
          final expList = jsonDecode(expJson) as List<dynamic>?;
          if (expList != null) {
            expenses = expList
                .map(
                  (e) =>
                      ExpenseItem.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList();
          }
        }
      } catch (_) {}
      List<DetailedReportAttachment> attachments = [];
      try {
        final aj = row['attachments_json'] as String?;
        if (aj != null && aj.trim().isNotEmpty) {
          final al = jsonDecode(aj) as List<dynamic>?;
          if (al != null) {
            attachments = al
                .map(
                  (e) => DetailedReportAttachment.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .where((a) => a.data.isNotEmpty)
                .toList();
          }
        }
      } catch (_) {}
      list.add(
        DetailedReportModel(
          id: reportId,
          userId: row['user_id'] as int,
          userName: row['user_name'] as String,
          reportDatetime: DateTime.parse(row['report_datetime'] as String),
          projectId: pid,
          projectName: resolvedName,
          supervisorId: row['supervisor_id'] as int?,
          createdAt: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'] as String)
              : null,
          summary: row['summary']?.toString(),
          lines: lines,
          expenses: expenses,
          attachments: attachments,
        ),
      );
    }
    return list;
  }

  Future<List<LocationWithdrawalForPeriodModel>>
  getLocationWithdrawalsForPeriod({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
  }) async {
    final db = await database;
    final fromKey = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toKey = DateTime(dateTo.year, dateTo.month, dateTo.day);
    String sql = '''
      SELECT lw.location_id, lw.user_id, lw.user_name, lw.created_at, pl.project_id
      FROM location_withdrawal lw
      INNER JOIN project_locations pl ON pl.id = lw.location_id
    ''';
    final args = <dynamic>[];
    if (projectId != null) {
      sql += ' WHERE pl.project_id = ?';
      args.add(projectId);
    }
    final rows = await db.rawQuery(sql, args);
    final out = <LocationWithdrawalForPeriodModel>[];
    for (final row in rows) {
      final createdStr = row['created_at'] as String? ?? '';
      final dt = DateTime.tryParse(createdStr) ?? DateTime.now();
      final dOnly = DateTime(dt.year, dt.month, dt.day);
      if (dOnly.isBefore(fromKey) || dOnly.isAfter(toKey)) continue;
      final pid = row['project_id'] as int;
      final createdAtNorm = createdStr;
      final led = await db.query(
        'project_stock_ledger',
        where: 'project_id = ? AND type = ? AND created_at = ?',
        whereArgs: [pid, 'withdraw_location', createdAtNorm],
        orderBy: 'material_name',
      );
      final materials = led.map((l) {
        final q = (l['quantity_delta'] as num?)?.abs() ?? 0;
        return WithdrawalMaterialLine(
          materialName: l['material_name'] as String? ?? '',
          quantity: q.toString(),
          unit: l['unit'] as String? ?? '',
        );
      }).toList();
      out.add(
        LocationWithdrawalForPeriodModel(
          locationId: row['location_id'] as int,
          userId: row['user_id'] as int,
          userName: row['user_name'] as String? ?? '',
          createdAt: dt,
          projectId: pid,
          materials: materials,
        ),
      );
    }
    return out;
  }
}
