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
import '../models/notification_item_model.dart';
import '../models/shop_darwing_notification_model.dart';
import '../models/ir_mir_upload_model.dart';
import '../models/ms_sd_record_model.dart';
import '../models/mos_itp_record_model.dart';
import '../models/withdrawal_request_model.dart';
import '../models/reports_sys_model.dart';
import '../models/expense_statement_model.dart';
import '../data/default_materials.dart';
import '../data/materials_display.dart';
import 'home_icon_order_service.dart';
import 'icon_visibility_service.dart';
import 'withdrawal_stock_validation.dart';
import 'attendance_duplicate_guard.dart';

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
      version: 42,
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
        name TEXT NOT NULL,
        main_contractor TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE disbursement_note_seq (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL
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
        calendar_date TEXT,
        location TEXT NOT NULL,
        project_id INTEGER,
        project_name TEXT,
        notes TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    await _createNotificationsTable(db);
    await _createShopDarwingNotificationsTable(db);

    // إدخال بيانات تجريبية
    await _seedData(db);
    await _createDailyReportsAndMaterials(db);
    await _createAdminTables(db);
    await _createStoreAndUnitsTables(db);
    await _createFinanceTables(db);
    await _createSystemSettingsTable(db);
    await _createUserHomeIconOrderTable(db);
    await _createExpenseStatementsTable(db);
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
    if (oldVersion < 23) {
      await _createNotificationsTable(db);
    }
    if (oldVersion < 25) {
      try {
        await db.execute(
          "ALTER TABLE location_materials ADD COLUMN phase TEXT NOT NULL DEFAULT 'first_fix'",
        );
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS location_withdrawal_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
            phase TEXT NOT NULL DEFAULT 'first_fix',
            user_id INTEGER NOT NULL REFERENCES users(id),
            user_name TEXT NOT NULL,
            created_at TEXT NOT NULL,
            disbursement_permit_images_json TEXT,
            delivery_permit_images_json TEXT,
            UNIQUE(location_id, phase)
          )
        ''');
        await db.execute('''
          INSERT INTO location_withdrawal_new (
            id, location_id, phase, user_id, user_name, created_at,
            disbursement_permit_images_json, delivery_permit_images_json
          )
          SELECT id, location_id, 'first_fix', user_id, user_name, created_at,
                 disbursement_permit_images_json, delivery_permit_images_json
          FROM location_withdrawal
        ''');
        await db.execute('DROP TABLE location_withdrawal');
        await db.execute(
          'ALTER TABLE location_withdrawal_new RENAME TO location_withdrawal',
        );
      } catch (_) {}
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
          phase TEXT NOT NULL DEFAULT 'first_fix',
          material_name TEXT NOT NULL,
          quantity TEXT NOT NULL,
          unit TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS location_withdrawal (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
          phase TEXT NOT NULL DEFAULT 'first_fix',
          user_id INTEGER NOT NULL REFERENCES users(id),
          user_name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          disbursement_permit_images_json TEXT,
          delivery_permit_images_json TEXT,
          UNIQUE(location_id, phase)
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
    if (oldVersion < 26) {
      await _createIrMirUploadsTable(db);
    }
    if (oldVersion < 27) {
      await _createWithdrawalRequestsTable(db);
    }
    if (oldVersion < 28) {
      await _createUserHomeIconOrderTable(db);
    }
    if (oldVersion < 29) {
      await _trimMaterialsCatalog(db);
    }
    if (oldVersion < 30) {
      await _trimMaterialsCatalog(db);
    }
    if (oldVersion < 31) {
      await db.execute(
        'ALTER TABLE attendance_records ADD COLUMN calendar_date TEXT',
      );
    }
    if (oldVersion < 32) {
      try {
        await db.execute(
          'ALTER TABLE detailed_reports ADD COLUMN executed_today_summary TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 33) {
      try {
        await db.execute(
          'ALTER TABLE detailed_report_lines ADD COLUMN manual_work_location TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 34) {
      await _createMsSdTables(db);
    }
    if (oldVersion < 35) {
      await _createMosItpTables(db);
    }
    if (oldVersion < 36) {
      await _createShopDarwingNotificationsTable(db);
    }
    if (oldVersion < 37) {
      try {
        await db.execute(
          'ALTER TABLE notifications ADD COLUMN withdrawal_request_id INTEGER',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE notifications ADD COLUMN action_taken_at TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 38) {
      await _createExpenseStatementsTable(db);
    }
    if (oldVersion < 39) {
      for (final column in const [
        'actor_user_id INTEGER',
        'actor_user_name TEXT',
        'actor_role TEXT',
      ]) {
        try {
          await db.execute('ALTER TABLE engineer_custody ADD COLUMN $column');
        } catch (_) {}
      }
    }
    if (oldVersion < 40) {
      try {
        await db.execute('DROP TABLE IF EXISTS private_chat_messages');
      } catch (_) {}
    }
    if (oldVersion < 41) {
      try {
        await db.execute(
          "ALTER TABLE projects ADD COLUMN main_contractor TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS disbursement_note_seq (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 42) {
      try {
        await db.update(
          'location_withdrawal',
          {'delivery_permit_images_json': '[]'},
        );
      } catch (_) {}
    }
  }

  Future<void> _createExpenseStatementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_statements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        submitter_user_id INTEGER NOT NULL,
        submitter_user_name TEXT NOT NULL,
        submitter_role TEXT NOT NULL DEFAULT '',
        balance_user_id INTEGER NOT NULL,
        project_id INTEGER,
        project_name TEXT,
        description TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL DEFAULT 0,
        image_path TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        rejection_reason TEXT,
        responded_by_user_id INTEGER,
        responded_by_user_name TEXT,
        responded_at TEXT,
        created_at TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'engineer',
        FOREIGN KEY (submitter_user_id) REFERENCES users (id),
        FOREIGN KEY (balance_user_id) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _trimMaterialsCatalog(Database db) async {
    if (defaultMaterialsList.isEmpty) return;
    final placeholders = List.filled(defaultMaterialsList.length, '?').join(',');
    await db.delete(
      'materials',
      where: 'name NOT IN ($placeholders)',
      whereArgs: defaultMaterialsList,
    );
    for (final name in defaultMaterialsList) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM materials WHERE name = ?',
          [name],
        ),
      );
      if (count == 0) {
        await db.insert('materials', {'name': name});
      }
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
        actor_user_id INTEGER,
        actor_user_name TEXT,
        actor_role TEXT,
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

  Future<void> _createUserHomeIconOrderTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_home_icon_order (
        user_id INTEGER PRIMARY KEY,
        icon_order_json TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipient_user_id INTEGER NOT NULL,
        recipient_role TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        event_type TEXT NOT NULL,
        actor_user_id INTEGER,
        actor_user_name TEXT,
        project_name TEXT,
        created_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        read_at TEXT,
        withdrawal_request_id INTEGER,
        action_taken_at TEXT
      )
    ''');
  }

  Future<void> _createShopDarwingNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_darwing_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipient_user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        read_at TEXT
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
        phase TEXT NOT NULL DEFAULT 'first_fix',
        material_name TEXT NOT NULL,
        quantity TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS location_withdrawal (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id INTEGER NOT NULL,
        phase TEXT NOT NULL DEFAULT 'first_fix',
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        disbursement_permit_images_json TEXT,
        delivery_permit_images_json TEXT,
        UNIQUE(location_id, phase)
      )
    ''');
    await _createWithdrawalRequestsTable(db);
    await _createIrMirUploadsTable(db);
    await _createMsSdTables(db);
    await _createMosItpTables(db);
    await _seedWorkPhases(db);
  }

  Future<void> _createMosItpTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mos_itp_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        kind TEXT NOT NULL,
        record_name TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mos_itp_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_mime TEXT NOT NULL,
        file_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (record_id) REFERENCES mos_itp_records (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createMsSdTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_sd_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        kind TEXT NOT NULL,
        record_name TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ms_sd_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        file_name TEXT NOT NULL,
        file_mime TEXT NOT NULL,
        file_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (record_id) REFERENCES ms_sd_records (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createWithdrawalRequestsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS withdrawal_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        location_id INTEGER NOT NULL,
        phase TEXT NOT NULL DEFAULT 'first_fix',
        engineer_user_id INTEGER NOT NULL,
        engineer_user_name TEXT NOT NULL,
        location_path_label TEXT NOT NULL DEFAULT '',
        sem_status TEXT NOT NULL DEFAULT 'pending',
        om_status TEXT NOT NULL DEFAULT 'pending',
        sem_reason TEXT,
        om_reason TEXT,
        sem_responded_at TEXT,
        om_responded_at TEXT,
        overall_status TEXT NOT NULL DEFAULT 'pending',
        fulfilled_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        FOREIGN KEY (location_id) REFERENCES project_locations (id),
        FOREIGN KEY (engineer_user_id) REFERENCES users (id)
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_withdrawal_req_active
      ON withdrawal_requests(location_id, phase)
      WHERE fulfilled_at IS NULL AND overall_status IN ('pending', 'approved')
    ''');
  }

  Future<void> _createIrMirUploadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ir_mir_uploads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        kind TEXT NOT NULL,
        mir_name TEXT,
        location_id INTEGER,
        phase TEXT,
        file_name TEXT NOT NULL,
        file_mime TEXT NOT NULL,
        file_data TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (location_id) REFERENCES project_locations (id)
      )
    ''');
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

  Future<void> setSystemLocked(
    bool locked, {
    String? requesterEmail,
  }) async {
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

  Future<List<String>> getUserHomeIconOrder(int userId) async {
    final db = await database;
    final rows = await db.query(
      'user_home_icon_order',
      columns: ['icon_order_json'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    final raw = rows.first['icon_order_json']?.toString();
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
    final db = await database;
    await db.insert('user_home_icon_order', {
      'user_id': userId,
      'icon_order_json': jsonEncode(iconOrder),
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

    final cal = attendanceLocalCalendarDateKey(record.dateTime);
    final id = await db.insert('attendance_records', {
      'user_id': record.userId,
      'user_name': record.userName,
      'type': record.type,
      'date_time': record.dateTime.toIso8601String(),
      'calendar_date': cal,
      'location': record.location,
      'project_id': record.projectId,
      'project_name': record.projectName,
      'notes': record.notes,
    });
    await _notifySiteEngineerManagersOnAttendance(db, record);
    return id;
  }

  Future<void> _notifySiteEngineerManagersOnAttendance(
    Database db,
    AttendanceRecordModel record,
  ) async {
    final recipients = await db.query(
      'users',
      columns: ['id', 'role'],
      where: 'role IN (?, ?, ?, ?)',
      whereArgs: [
        'site_engineer_manager',
        'projects_manager',
        'operation_manager',
        'app_admin',
      ],
    );
    if (recipients.isEmpty) return;
    final isCheckIn = record.type == 'check_in';
    final actionLabel = isCheckIn ? 'الحضور' : 'الانصراف';
    final projectName = (record.projectName ?? '').trim().isEmpty
        ? 'بدون مشروع'
        : record.projectName!.trim();
    final body =
        'قام "${record.userName}" بتسجيل $actionLabel بمشروع "$projectName"';
    final now = DateTime.now().toIso8601String();
    for (final recipient in recipients) {
      await db.insert('notifications', {
        'recipient_user_id': recipient['id'],
        'recipient_role': recipient['role'],
        'title': 'تنبيه حضور/انصراف',
        'body': body,
        'event_type': 'attendance_${record.type}',
        'actor_user_id': record.userId,
        'actor_user_name': record.userName,
        'project_name': record.projectName,
        'created_at': now,
        'is_read': 0,
      });
    }
  }

  Future<List<NotificationItemModel>> getNotificationsForUser(int userId) async {
    final db = await database;
    final maps = await db.query(
      'notifications',
      where: 'recipient_user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => NotificationItemModel.fromMap(m)).toList();
  }

  Future<int> getUnreadNotificationsCount(int userId) async {
    final db = await database;
    final v = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM notifications WHERE recipient_user_id = ? AND is_read = 0',
        [userId],
      ),
    );
    return v ?? 0;
  }

  Future<void> markNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    final db = await database;
    await db.update(
      'notifications',
      {'is_read': 1, 'read_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND recipient_user_id = ?',
      whereArgs: [notificationId, userId],
    );
  }

  Future<void> deleteNotification({
    required int notificationId,
    required int userId,
  }) async {
    final db = await database;
    final rows = await db.query(
      'notifications',
      columns: ['withdrawal_request_id', 'action_taken_at'],
      where: 'id = ? AND recipient_user_id = ?',
      whereArgs: [notificationId, userId],
    );
    if (rows.isEmpty) return;
    final wrId = rows.first['withdrawal_request_id'];
    final actionAt = rows.first['action_taken_at'];
    if (wrId != null && (actionAt == null || actionAt.toString().isEmpty)) {
      throw Exception('action_required_before_delete');
    }
    await db.delete(
      'notifications',
      where: 'id = ? AND recipient_user_id = ?',
      whereArgs: [notificationId, userId],
    );
  }

  Future<List<ShopDarwingNotificationModel>> getShopDarwingNotifications(
    int userId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'shop_darwing_notifications',
      where: 'recipient_user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => ShopDarwingNotificationModel.fromMap(m)).toList();
  }

  Future<int> getUnreadShopDarwingNotificationsCount(int userId) async {
    final db = await database;
    final v = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM shop_darwing_notifications WHERE recipient_user_id = ? AND is_read = 0',
        [userId],
      ),
    );
    return v ?? 0;
  }

  Future<void> markShopDarwingNotificationRead({
    required int notificationId,
    required int userId,
  }) async {
    final db = await database;
    await db.update(
      'shop_darwing_notifications',
      {'is_read': 1, 'read_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND recipient_user_id = ?',
      whereArgs: [notificationId, userId],
    );
  }

  Future<void> deleteShopDarwingNotification({
    required int notificationId,
    required int userId,
  }) async {
    final db = await database;
    await db.delete(
      'shop_darwing_notifications',
      where: 'id = ? AND recipient_user_id = ?',
      whereArgs: [notificationId, userId],
    );
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
    return sortMaterialsForDisplay(
      maps.map((m) => m['name'] as String),
    );
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

  /// عارض مرفقات الإشعارات يعمل على الخادم فقط.
  Future<Never> getNotificationAttachments({
    required int userId,
    required String source,
    required int recordId,
  }) async {
    throw Exception('عرض المرفقات يتطلب الاتصال بالخادم');
  }

  Future<Never> getNotificationAttachmentFile({
    required int userId,
    required String source,
    required int recordId,
    required String attachmentId,
  }) async {
    throw Exception('عرض المرفقات يتطلب الاتصال بالخادم');
  }

  /// تقارير العمليات تُحفظ على الخادم فقط (تحتاج صوراً وإشعارات).
  Future<int> createOperationReport({
    required int userId,
    required String userName,
    int? projectId,
    String? projectName,
    required String reportType,
    required String details,
    required List<String> images,
  }) async {
    throw Exception('إرسال تقارير العمليات يتطلب الاتصال بالخادم');
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
    String movementType, {
    int? actorUserId,
    String? actorUserName,
    String? actorRole,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('engineer_custody', {
      'user_id': userId,
      'amount': amount,
      'created_at': now,
      'note': note,
      'document_path': null,
      'movement_type': movementType,
      'actor_user_id': actorUserId,
      'actor_user_name': actorUserName?.trim(),
      'actor_role': actorRole?.trim(),
    });
    final users = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (users.isEmpty) return;
    if ((users.first['role'] ?? '').toString() != 'site_engineer') return;
    final isAdd = movementType == 'add_balance';
    final by = (actorUserName != null && actorUserName.trim().isNotEmpty)
        ? ' من طرف ${actorUserName.trim()}'
        : '';
    await db.insert('notifications', {
      'recipient_user_id': userId,
      'recipient_role': 'site_engineer',
      'title': isAdd ? 'إضافة رصيد' : 'سحب رصيد',
      'body': isAdd
          ? 'تم إضافة مبلغ ${amount.toStringAsFixed(2)} إلى رصيدك$by.'
          : 'تم سحب مبلغ ${amount.toStringAsFixed(2)} من رصيدك$by.',
      'event_type': isAdd ? 'balance_added' : 'balance_withdrawn',
      'actor_user_id': actorUserId,
      'actor_user_name': actorUserName,
      'project_name': null,
      'created_at': now,
      'is_read': 0,
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
            'actor_user_id': r['actor_user_id'],
            'actor_user_name': r['actor_user_name'],
            'actor_role': r['actor_role'],
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

  Future<void> deleteUser(int id, {String? requesterEmail}) async {
    final db = await database;
    await db.transaction((txn) async {
      final reportRows = await txn.query(
        'detailed_reports',
        columns: ['id'],
        where: 'user_id = ?',
        whereArgs: [id],
      );
      for (final row in reportRows) {
        await txn.delete(
          'detailed_report_lines',
          where: 'detailed_report_id = ?',
          whereArgs: [row['id']],
        );
      }
      for (final table in [
        'withdrawal_requests',
        'location_withdrawal',
        'ir_mir_uploads',
        'notifications',
        'user_home_icon_order',
        'engineer_custody',
        'engineer_balance',
        'daily_reports',
        'attendance_records',
        'detailed_reports',
      ]) {
        final col = table == 'withdrawal_requests' ? 'engineer_user_id' : 'user_id';
        await txn.delete(table, where: '$col = ?', whereArgs: [id]);
      }
      await txn.update(
        'project_stock_ledger',
        {'user_id': null},
        where: 'user_id = ?',
        whereArgs: [id],
      );
      await txn.delete('users', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ——— إدارة المشاريع ———
  Future<int> addProject(String name, {String mainContractor = ''}) async {
    final db = await database;
    final normalized = name.trim().toLowerCase();
    final existing = await db.query(
      'projects',
      columns: ['id'],
      where: 'LOWER(TRIM(name)) = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      if (mainContractor.trim().isNotEmpty) {
        await db.update(
          'projects',
          {'main_contractor': mainContractor.trim()},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      return id;
    }
    return db.insert('projects', {
      'name': name.trim(),
      'main_contractor': mainContractor.trim(),
    });
  }

  Future<void> updateProject(
    int id,
    String name, {
    String mainContractor = '',
  }) async {
    final db = await database;
    await db.update(
      'projects',
      {'name': name, 'main_contractor': mainContractor.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> nextDisbursementNoteNumber() async {
    final db = await database;
    final id = await db.insert('disbursement_note_seq', {
      'created_at': DateTime.now().toIso8601String(),
    });
    return id.toString().padLeft(3, '0');
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
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    final db = await database;
    final maps = await db.query(
      'location_materials',
      where: 'location_id = ? AND phase = ?',
      whereArgs: [locationId, phase],
      orderBy: 'material_name',
    );
    return maps.map((m) => LocationMaterialModel.fromMap(m)).toList();
  }

  Future<List<LocationMaterialModel>> getLocationMaterialsForProject(
    int projectId,
  ) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT lm.id, lm.location_id, lm.phase, lm.material_name, lm.quantity, lm.unit
      FROM location_materials lm
      INNER JOIN project_locations pl ON pl.id = lm.location_id
      WHERE pl.project_id = ?
      ORDER BY lm.location_id, lm.phase, lm.material_name
      ''',
      [projectId],
    );
    return maps.map((m) => LocationMaterialModel.fromMap(m)).toList();
  }

  Future<int> addLocationMaterial(LocationMaterialModel m) async {
    final db = await database;
    return db.insert('location_materials', {
      'location_id': m.locationId,
      'phase': m.phase,
      'material_name': m.materialName,
      'quantity': m.quantity,
      'unit': m.unit,
    });
  }

  Future<void> updateLocationMaterial(LocationMaterialModel m) async {
    final db = await database;
    await db.update(
      'location_materials',
      {
        'phase': m.phase,
        'material_name': m.materialName,
        'quantity': m.quantity,
        'unit': m.unit,
      },
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteLocationMaterial(int id) async {
    final db = await database;
    await db.delete('location_materials', where: 'id = ?', whereArgs: [id]);
  }

  Future<LocationWithdrawalModel?> getLocationWithdrawal(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    final db = await database;
    final maps = await db.query(
      'location_withdrawal',
      where: 'location_id = ? AND phase = ?',
      whereArgs: [locationId, phase],
    );
    if (maps.isEmpty) return null;
    return LocationWithdrawalModel.fromMap(maps.first);
  }

  Future<List<LocationWithdrawalModel>> getLocationWithdrawalsForProject(
    int projectId,
  ) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT lw.id, lw.location_id, lw.phase, lw.user_id, lw.user_name, lw.created_at,
             lw.disbursement_permit_images_json, lw.delivery_permit_images_json
      FROM location_withdrawal lw
      INNER JOIN project_locations pl ON pl.id = lw.location_id
      WHERE pl.project_id = ?
      ORDER BY lw.location_id, lw.phase
      ''',
      [projectId],
    );
    return maps.map((m) => LocationWithdrawalModel.fromMap(m)).toList();
  }

  Future<void> createLocationWithdrawal({
    required int locationId,
    String phase = LocationMaterialModel.phaseFirstFix,
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
    final materials = await getLocationMaterials(locationId, phase: phase);
    final stockList = await getProjectStock(projectId);
    if (!hasSufficientStockForWithdrawal(
      locationMaterials: materials,
      projectStock: stockList,
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
      'phase': phase,
      'user_id': userId,
      'user_name': userName,
      'created_at': nowStr,
      'disbursement_permit_images_json': disbursementPermitImagesJson,
      'delivery_permit_images_json': '[]',
    });
    await db.update(
      'withdrawal_requests',
      {
        'fulfilled_at': nowStr,
        'updated_at': nowStr,
      },
      where:
          'location_id = ? AND phase = ? AND engineer_user_id = ? AND overall_status = ? AND fulfilled_at IS NULL',
      whereArgs: [
        locationId,
        phase,
        userId,
        WithdrawalRequestModel.statusApproved,
      ],
    );
    final p = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    final projectName = p.isNotEmpty ? (p.first['name'] as String? ?? '') : '';
    if (await _userRole(db, userId) == 'site_engineer') {
      await _notifyAppAdmins(
        db,
        title: 'إتمام سحب خامات',
        body:
            'قام "$userName" بإتمام سحب خامات من موقع فرعي — مشروع "${projectName.isEmpty ? 'غير محدد' : projectName}" — مرحلة: $phase',
        eventType: 'material_withdrawal_completed',
        actorUserId: userId,
        actorUserName: userName,
        projectName: projectName.isEmpty ? null : projectName,
      );
    }
    final hasPermitDocs =
        disbursementPermitImagesJson != null &&
            disbursementPermitImagesJson.trim().isNotEmpty &&
            disbursementPermitImagesJson.trim() != '[]';
    if (hasPermitDocs) {
      await _notifyAppAdmins(
        db,
        title: 'مرفقات سحب خامات',
        body:
            'قام "$userName" بإرفاق أذن الصرف &التسليم مع سحب الخامات — مشروع "${projectName.isEmpty ? 'غير محدد' : projectName}"',
        eventType: 'withdrawal_permit_upload',
        actorUserId: userId,
        actorUserName: userName,
        projectName: projectName.isEmpty ? null : projectName,
      );
    }
  }

  /// إلغاء سحب الخامات: حذف السجل واسترجاع أرصدة المشروع وحذف حركات withdraw_location المرتبطة.
  Future<void> deleteLocationWithdrawal(
    int locationId, {
    String phase = LocationMaterialModel.phaseFirstFix,
  }) async {
    final db = await database;
    final withdrawal = await getLocationWithdrawal(locationId, phase: phase);
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
      where: 'location_id = ? AND phase = ?',
      whereArgs: [locationId, phase],
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

  /// `actorUserId` / `actorUserName` تُستخدمان فقط في وضع الـAPI (إشعار رفع الصورة).
  Future<int> addUnit(
    UnitModel u, {
    int? actorUserId,
    String? actorUserName,
  }) async {
    final db = await database;
    return db.insert('units', {
      'building_id': u.buildingId,
      'name': u.name,
      'model': u.model,
      'image_path': u.imagePath,
    });
  }

  Future<void> updateUnit(
    UnitModel u, {
    int? actorUserId,
    String? actorUserName,
  }) async {
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

  Future<int> addBuildingMaterial(
    BuildingMaterialModel m, {
    int? actorUserId,
    String? actorUserName,
  }) async {
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

  Future<void> updateBuildingMaterial(
    BuildingMaterialModel m, {
    int? actorUserId,
    String? actorUserName,
  }) async {
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

  Future<int> addBuildingCutlist(
    BuildingCutlistModel c, {
    int? actorUserId,
    String? actorUserName,
  }) async {
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
    return sortMaterialRowsForDisplay(
      maps
          .map((m) => {'id': m['id'], 'name': m['name'] as String})
          .toList(),
    );
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
      'executed_today_summary': report.executedTodaySummary,
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
        'manual_work_location': line.manualWorkLocation,
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
    await _notifyAppAdminsWorkPlanSaved(db, report: report, isUpdate: false);
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
          'executed_today_summary': report.executedTodaySummary,
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
          'manual_work_location': line.manualWorkLocation,
          'phase_id': line.phaseId,
          'workers_count': line.workersCount,
        });
      }
    });
    await _notifyAppAdminsWorkPlanSaved(db, report: report, isUpdate: true);
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
    final userName = rows.first['user_name'] as String? ?? '';
    final projectName = rows.first['project_name'] as String?;
    if (await _userRole(db, userId) == 'site_engineer') {
      await _notifyAppAdmins(
        db,
        title: 'تحديث ماليات التقرير',
        body: 'قام "$userName" بتحديث بنود الصرف في التقرير المفصل #$reportId',
        eventType: 'detailed_report_expenses_updated',
        actorUserId: userId,
        actorUserName: userName,
        projectName: projectName,
      );
    }
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
      final lineMaps = await db.rawQuery(
        '''
        SELECT l.id, l.contractor_id, c.name AS contractor_name,
               l.contractor_workers_count, l.self_workers_count, l.zone_id,
               l.building_id, l.location_id, l.manual_work_location, l.phase_id,
               l.workers_count
        FROM detailed_report_lines l
        LEFT JOIN contractors c ON c.id = l.contractor_id
        WHERE l.detailed_report_id = ?
        ORDER BY l.id
        ''',
        [reportId],
      );
      final lines = lineMaps
          .map(
            (l) => DetailedReportLineModel.fromMap({
              'id': l['id'],
              'contractor_id': l['contractor_id'],
              'contractor_name': l['contractor_name'],
              'contractor_workers_count': l['contractor_workers_count'],
              'self_workers_count': l['self_workers_count'],
              'zone_id': l['zone_id'],
              'building_id': l['building_id'],
              'location_id': l['location_id'],
              'manual_work_location': l['manual_work_location'],
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
          executedTodaySummary: row['executed_today_summary']?.toString(),
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

  Future<List<IrMirUploadModel>> listIrMirUploads({
    required int projectId,
    String? kind,
    String? mirName,
    int? locationId,
    String? phase,
  }) async {
    final db = await database;
    final where = <String>['project_id = ?'];
    final args = <dynamic>[projectId];
    if (kind == IrMirUploadModel.kindMir || kind == IrMirUploadModel.kindIr) {
      where.add('kind = ?');
      args.add(kind);
    }
    if (mirName != null && mirName.trim().isNotEmpty) {
      where.add('LOWER(TRIM(mir_name)) = LOWER(TRIM(?))');
      args.add(mirName.trim());
    }
    if (locationId != null) {
      where.add('location_id = ?');
      args.add(locationId);
    }
    if (phase != null && phase.trim().isNotEmpty) {
      where.add('LOWER(TRIM(COALESCE(phase, \'\'))) = LOWER(TRIM(?))');
      args.add(phase.trim());
    }
    final maps = await db.query(
      'ir_mir_uploads',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
    );
    return maps.map((m) => IrMirUploadModel.fromMap(m)).toList();
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
    final db = await database;
    final uploadId = await db.insert('ir_mir_uploads', {
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
    final p = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    final projName = p.isNotEmpty ? (p.first['name'] as String? ?? '') : '';
    final kindLabel = kind == IrMirUploadModel.kindMir ? 'MIR' : 'IR';
    final extra = kind == IrMirUploadModel.kindMir && mirName != null
        ? ' — اسم $kindLabel: $mirName'
        : kind == IrMirUploadModel.kindIr && phase != null
        ? ' — مرحلة: $phase'
        : '';
    await _notifyAppAdmins(
      db,
      title: 'رفع مستند $kindLabel',
      body:
          'قام "$userName" برفع ملف "$fileName" ($kindLabel) — مشروع "${projName.isEmpty ? 'غير محدد' : projName}"$extra\n'
          'رقم المرفق: $uploadId',
      eventType: kind == IrMirUploadModel.kindMir ? 'mir_upload' : 'ir_upload',
      actorUserId: userId,
      actorUserName: userName,
      projectName: projName.isEmpty ? null : projName,
    );
    return uploadId as int;
  }

  /// حذف مرفق IR/MIR محلياً. التحقق من صلاحية المسؤول يتم في الواجهة.
  Future<void> deleteIrMirUpload(int id, {String? requesterEmail}) async {
    final db = await database;
    final n = await db.delete(
      'ir_mir_uploads',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (n == 0) throw Exception('المرفق غير موجود');
  }

  bool _includeMsSdAudit(String? requesterEmail) =>
      (requesterEmail ?? '').trim().toLowerCase() ==
      UserModel.primaryAppAdminEmail.toLowerCase();

  Future<List<MsSdRecordModel>> listMsSdRecords({
    required int projectId,
    required String kind,
    String? requesterEmail,
  }) async {
    final db = await database;
    final includeAudit = _includeMsSdAudit(requesterEmail);
    final recMaps = await db.query(
      'ms_sd_records',
      where: 'project_id = ? AND kind = ?',
      whereArgs: [projectId, kind],
      orderBy: 'created_at DESC, id DESC',
    );
    final out = <MsSdRecordModel>[];
    for (final rec in recMaps) {
      final recordId = rec['id'] as int;
      final attMaps = await db.query(
        'ms_sd_attachments',
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'id ASC',
      );
      final attachments = attMaps
          .map((m) => MsSdAttachmentModel.fromMap(m))
          .toList();
      out.add(
        MsSdRecordModel(
          id: recordId,
          projectId: rec['project_id'] as int,
          userId: includeAudit ? rec['user_id'] as int? : null,
          userName: includeAudit ? rec['user_name'] as String? : null,
          kind: rec['kind'] as String,
          recordName: rec['record_name'] as String,
          notes: rec['notes'] as String?,
          createdAt: includeAudit
              ? DateTime.tryParse(rec['created_at'] as String? ?? '')
              : null,
          attachments: attachments,
        ),
      );
    }
    return out;
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
    final db = await database;
    final createdAt = DateTime.now().toIso8601String();
    final recordId = await db.insert('ms_sd_records', {
      'project_id': projectId,
      'user_id': userId,
      'user_name': userName,
      'kind': kind,
      'record_name': recordName,
      'notes': notes,
      'created_at': createdAt,
    });
    for (final att in attachments) {
      await db.insert('ms_sd_attachments', {
        'record_id': recordId,
        'file_name': att['fileName'],
        'file_mime': att['fileMime'],
        'file_data': att['fileData'],
        'created_at': createdAt,
      });
    }
    final p = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    final projName = p.isNotEmpty ? (p.first['name'] as String? ?? '') : '';
    final kindLabel = kind == MsSdRecordModel.kindSd ? 'SD' : 'MS';
    await _notifyAppAdmins(
      db,
      title: 'رفع $kindLabel جديد',
      body:
          'قام "$userName" بإضافة "$recordName" ($kindLabel) — مشروع "${projName.isEmpty ? 'غير محدد' : projName}"\n'
          'رقم السجل: $recordId',
      eventType: kind == MsSdRecordModel.kindSd ? 'sd_upload' : 'ms_upload',
      actorUserId: userId,
      actorUserName: userName,
      projectName: projName.isEmpty ? null : projName,
    );
    return recordId as int;
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
    final db = await database;
    final existing = await db.query(
      'ms_sd_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) throw Exception('السجل غير موجود');

    final values = <String, Object?>{};
    if (recordName != null) values['record_name'] = recordName;
    if (notes != null) values['notes'] = notes;
    if (values.isNotEmpty) {
      await db.update('ms_sd_records', values, where: 'id = ?', whereArgs: [id]);
    }

    if (removeAttachmentIds != null) {
      for (final attId in removeAttachmentIds) {
        await db.delete(
          'ms_sd_attachments',
          where: 'id = ? AND record_id = ?',
          whereArgs: [attId, id],
        );
      }
    }

    final now = DateTime.now().toIso8601String();
    if (addAttachments != null) {
      for (final att in addAttachments) {
        await db.insert('ms_sd_attachments', {
          'record_id': id,
          'file_name': att['fileName'],
          'file_mime': att['fileMime'],
          'file_data': att['fileData'],
          'created_at': now,
        });
      }
    }

    final remain = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ms_sd_attachments WHERE record_id = ?',
        [id],
      ),
    );
    if ((remain ?? 0) == 0) {
      throw Exception('يجب أن يبقى مرفق واحد على الأقل');
    }
  }

  Future<void> deleteMsSdRecord(int id, {required String requesterEmail}) async {
    if (!_includeMsSdAudit(requesterEmail)) {
      throw Exception('غير مصرح بحذف السجل');
    }
    final db = await database;
    await db.delete(
      'ms_sd_attachments',
      where: 'record_id = ?',
      whereArgs: [id],
    );
    final n = await db.delete(
      'ms_sd_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (n == 0) throw Exception('السجل غير موجود');
  }

  bool _includeMosItpAudit(String? requesterEmail) =>
      (requesterEmail ?? '').trim().toLowerCase() ==
      UserModel.primaryAppAdminEmail.toLowerCase();

  Future<List<MosItpRecordModel>> listMosItpRecords({
    required int projectId,
    required String kind,
    String? requesterEmail,
  }) async {
    final db = await database;
    final includeAudit = _includeMosItpAudit(requesterEmail);
    final recMaps = await db.query(
      'mos_itp_records',
      where: 'project_id = ? AND kind = ?',
      whereArgs: [projectId, kind],
      orderBy: 'created_at DESC, id DESC',
    );
    final out = <MosItpRecordModel>[];
    for (final rec in recMaps) {
      final recordId = rec['id'] as int;
      final attMaps = await db.query(
        'mos_itp_attachments',
        where: 'record_id = ?',
        whereArgs: [recordId],
        orderBy: 'id ASC',
      );
      final attachments = attMaps
          .map((m) => MosItpAttachmentModel.fromMap(m))
          .toList();
      out.add(
        MosItpRecordModel(
          id: recordId,
          projectId: rec['project_id'] as int,
          userId: includeAudit ? rec['user_id'] as int? : null,
          userName: includeAudit ? rec['user_name'] as String? : null,
          kind: rec['kind'] as String,
          recordName: rec['record_name'] as String,
          notes: rec['notes'] as String?,
          createdAt: includeAudit
              ? DateTime.tryParse(rec['created_at'] as String? ?? '')
              : null,
          attachments: attachments,
        ),
      );
    }
    return out;
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
    final db = await database;
    final createdAt = DateTime.now().toIso8601String();
    final recordId = await db.insert('mos_itp_records', {
      'project_id': projectId,
      'user_id': userId,
      'user_name': userName,
      'kind': kind,
      'record_name': recordName,
      'notes': notes,
      'created_at': createdAt,
    });
    for (final att in attachments) {
      await db.insert('mos_itp_attachments', {
        'record_id': recordId,
        'file_name': att['fileName'],
        'file_mime': att['fileMime'],
        'file_data': att['fileData'],
        'created_at': createdAt,
      });
    }
    final p = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    final projName = p.isNotEmpty ? (p.first['name'] as String? ?? '') : '';
    final kindLabel = kind == MosItpRecordModel.kindItp ? 'ITP' : 'MoS';
    await _notifyAppAdmins(
      db,
      title: 'رفع $kindLabel جديد',
      body:
          'قام "$userName" بإضافة "$recordName" ($kindLabel) — مشروع "${projName.isEmpty ? 'غير محدد' : projName}"\n'
          'رقم السجل: $recordId',
      eventType: kind == MosItpRecordModel.kindItp ? 'itp_upload' : 'mos_upload',
      actorUserId: userId,
      actorUserName: userName,
      projectName: projName.isEmpty ? null : projName,
    );
    return recordId as int;
  }

  Future<void> updateMosItpRecord(
    int id, {
    required String requesterEmail,
    String? recordName,
    String? notes,
    List<int>? removeAttachmentIds,
    List<Map<String, String>>? addAttachments,
  }) async {
    if (!_includeMosItpAudit(requesterEmail)) {
      throw Exception('غير مصرح بتعديل السجل');
    }
    final db = await database;
    final existing = await db.query(
      'mos_itp_records',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) throw Exception('السجل غير موجود');

    final values = <String, Object?>{};
    if (recordName != null) values['record_name'] = recordName;
    if (notes != null) values['notes'] = notes;
    if (values.isNotEmpty) {
      await db.update('mos_itp_records', values, where: 'id = ?', whereArgs: [id]);
    }

    if (removeAttachmentIds != null) {
      for (final attId in removeAttachmentIds) {
        await db.delete(
          'mos_itp_attachments',
          where: 'id = ? AND record_id = ?',
          whereArgs: [attId, id],
        );
      }
    }

    final now = DateTime.now().toIso8601String();
    if (addAttachments != null) {
      for (final att in addAttachments) {
        await db.insert('mos_itp_attachments', {
          'record_id': id,
          'file_name': att['fileName'],
          'file_mime': att['fileMime'],
          'file_data': att['fileData'],
          'created_at': now,
        });
      }
    }

    final remain = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM mos_itp_attachments WHERE record_id = ?',
        [id],
      ),
    );
    if ((remain ?? 0) == 0) {
      throw Exception('يجب أن يبقى مرفق واحد على الأقل');
    }
  }

  Future<void> deleteMosItpRecord(int id, {required String requesterEmail}) async {
    if (!_includeMosItpAudit(requesterEmail)) {
      throw Exception('غير مصرح بحذف السجل');
    }
    final db = await database;
    await db.delete(
      'mos_itp_attachments',
      where: 'record_id = ?',
      whereArgs: [id],
    );
    final n = await db.delete(
      'mos_itp_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (n == 0) throw Exception('السجل غير موجود');
  }

  Future<void> _notifyAppAdmins(
    Database db, {
    required String title,
    required String body,
    required String eventType,
    int? actorUserId,
    String? actorUserName,
    String? projectName,
  }) async {
    await _wrNotifyRoles(
      db,
      ['app_admin'],
      title: title,
      body: body,
      eventType: eventType,
      actorUserId: actorUserId,
      actorUserName: actorUserName,
      projectName: projectName,
    );
  }

  Future<String?> _userRole(Database db, int userId) async {
    final u = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (u.isEmpty) return null;
    return u.first['role'] as String?;
  }

  String _planDayLabel(DateTime reportDatetime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final rd = DateTime(
      reportDatetime.year,
      reportDatetime.month,
      reportDatetime.day,
    );
    if (rd == tomorrow) return 'خطة عمل الغد';
    if (rd == today) return 'خطة عمل اليوم';
    return 'خطة عمل (${rd.toIso8601String().substring(0, 10)})';
  }

  Future<void> _notifyAppAdminsWorkPlanSaved(
    Database db, {
    required DetailedReportModel report,
    required bool isUpdate,
  }) async {
    final role = await _userRole(db, report.userId);
    if (role != 'site_engineer') return;
    final planLabel = _planDayLabel(report.reportDatetime);
    final proj = (report.projectName ?? '').trim().isEmpty
        ? 'غير محدد'
        : report.projectName!.trim();
    final action = isUpdate ? 'عدّل' : 'حفظ';
    try {
      await _notifyAppAdmins(
        db,
        title: 'تنبيه — $planLabel',
        body:
            'قام "${report.userName}" ب$action $planLabel بمشروع "$proj"\n'
            'تاريخ الخطة: ${report.reportDatetime.toIso8601String().substring(0, 10)}',
        eventType: isUpdate
            ? (planLabel.contains('الغد')
                ? 'tomorrow_work_plan_updated'
                : 'today_work_plan_updated')
            : (planLabel.contains('الغد')
                ? 'tomorrow_work_plan_created'
                : 'today_work_plan_saved'),
        actorUserId: report.userId,
        actorUserName: report.userName,
        projectName: report.projectName,
      );
      if (report.attachments.isNotEmpty) {
        await _notifyAppAdmins(
          db,
          title: 'رفع مرفقات مع خطة العمل',
          body:
              'قام "${report.userName}" بإرفاق مستند/صورة مع $planLabel — مشروع "$proj"',
          eventType: 'work_plan_attachment',
          actorUserId: report.userId,
          actorUserName: report.userName,
          projectName: report.projectName,
        );
      }
    } catch (_) {}
  }

  Future<void> _wrNotifyRoles(
    Database db,
    List<String> roles, {
    required String title,
    required String body,
    required String eventType,
    int? actorUserId,
    String? actorUserName,
    String? projectName,
    int? withdrawalRequestId,
    String? actionTakenAt,
  }) async {
    if (roles.isEmpty) return;
    final placeholders = List.filled(roles.length, '?').join(',');
    final users = await db.rawQuery(
      'SELECT id, role FROM users WHERE role IN ($placeholders)',
      roles,
    );
    final now = DateTime.now().toIso8601String();
    for (final u in users) {
      await db.insert('notifications', {
        'recipient_user_id': u['id'],
        'recipient_role': u['role'],
        'title': title,
        'body': body,
        'event_type': eventType,
        'actor_user_id': actorUserId,
        'actor_user_name': actorUserName,
        'project_name': projectName,
        'created_at': now,
        'is_read': 0,
        'withdrawal_request_id': withdrawalRequestId,
        'action_taken_at': actionTakenAt,
      });
    }
  }

  String _wrBuildSemNewRequestBody(
    String engName,
    String projectName,
    String pathLabel,
    int requestId,
    String createdAtIso,
  ) {
    return 'طلب من "$engName" — مشروع "$projectName" — موقع: ${pathLabel.isEmpty ? '—' : pathLabel}\n'
        'رقم الطلب: $requestId\n'
        'تاريخ ووقت الإرسال: ${_formatWithdrawalSubmittedAt(createdAtIso)}';
  }

  String _wrBuildOmRequestBody(
    String engName,
    String projectName,
    String pathLabel,
    int requestId,
    String createdAtIso,
    String semApprovedAtIso,
  ) {
    return 'قام المهندس "$engName"\n'
        'بطلب سحب — مشروع "$projectName" — موقع: ${pathLabel.isEmpty ? '—' : pathLabel}\n'
        'رقم الطلب: $requestId\n'
        'تاريخ ووقت الإرسال: ${_formatWithdrawalSubmittedAt(createdAtIso)}\n\n'
        'وافق مدير المشروعات على الطلب — ${_formatWithdrawalSubmittedAt(semApprovedAtIso)}';
  }

  Future<void> _wrAppendAndMarkActionTaken(
    Database db, {
    required int withdrawalRequestId,
    required String recipientRole,
    required String appendLine,
  }) async {
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'notifications',
      where:
          'withdrawal_request_id = ? AND recipient_role = ? AND action_taken_at IS NULL',
      whereArgs: [withdrawalRequestId, recipientRole],
    );
    for (final row in rows) {
      final body = '${row['body']}\n$appendLine';
      await db.update(
        'notifications',
        {'body': body, 'action_taken_at': now},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _wrAppendToWithdrawalNotification(
    Database db, {
    required int withdrawalRequestId,
    required String recipientRole,
    required String appendLine,
  }) async {
    final rows = await db.query(
      'notifications',
      where: 'withdrawal_request_id = ? AND recipient_role = ?',
      whereArgs: [withdrawalRequestId, recipientRole],
    );
    for (final row in rows) {
      final body = '${row['body']}\n$appendLine';
      await db.update(
        'notifications',
        {'body': body},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _wrNotifyUser(
    Database db,
    int recipientUserId, {
    required String title,
    required String body,
    required String eventType,
    int? actorUserId,
    String? actorUserName,
    String? projectName,
    int? withdrawalRequestId,
  }) async {
    final u = await db.query('users', where: 'id = ?', whereArgs: [recipientUserId]);
    if (u.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await db.insert('notifications', {
      'recipient_user_id': recipientUserId,
      'recipient_role': u.first['role'],
      'title': title,
      'body': body,
      'event_type': eventType,
      'actor_user_id': actorUserId,
      'actor_user_name': actorUserName,
      'project_name': projectName,
      'created_at': now,
      'is_read': 0,
      'withdrawal_request_id': withdrawalRequestId,
      // إشعار المهندس ليس بانتظار قرار منه، فيُختم فوراً ليبقى قابلاً للحذف.
      'action_taken_at': withdrawalRequestId == null ? null : now,
    });
  }

  WithdrawalRequestModel _wrFromRow(Map<String, dynamic> m) =>
      WithdrawalRequestModel.fromMap(Map<String, dynamic>.from(m));

  String _formatWithdrawalSubmittedAt(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    final hour = local.hour;
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final amPm = hour >= 12 ? 'م' : 'ص';
    return '${local.year.toString().padLeft(4, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${h12.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} $amPm';
  }

  Future<WithdrawalRequestModel?> getWithdrawalRequestById(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT wr.*, p.name AS project_name FROM withdrawal_requests wr '
      'LEFT JOIN projects p ON p.id = wr.project_id WHERE wr.id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _wrFromRow(Map<String, dynamic>.from(rows.first));
  }

  Future<List<WithdrawalRequestModel>> getWithdrawalRequestsForEngineerProject({
    required int projectId,
    required int engineerUserId,
  }) async {
    final db = await database;
    final maps = await db.query(
      'withdrawal_requests',
      where: 'project_id = ? AND engineer_user_id = ? AND fulfilled_at IS NULL',
      whereArgs: [projectId, engineerUserId],
      orderBy: 'id DESC',
    );
    return maps.map(_wrFromRow).toList();
  }

  Future<List<WithdrawalRequestModel>> getWithdrawalRequestsForPeriod({
    required DateTime dateFrom,
    required DateTime dateTo,
    int? projectId,
    int? engineerUserId,
  }) async {
    final db = await database;
    final fromKey = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final toKey = DateTime(dateTo.year, dateTo.month, dateTo.day);
    final maps = await db.query('withdrawal_requests', orderBy: 'id ASC');
    final projectNameById = <int, String>{};
    try {
      final projects = await db.query('projects', columns: ['id', 'name']);
      for (final p in projects) {
        final id = p['id'] is int
            ? p['id'] as int
            : int.tryParse(p['id']?.toString() ?? '') ?? 0;
        if (id > 0) {
          projectNameById[id] = (p['name']?.toString() ?? '').trim();
        }
      }
    } catch (_) {}
    final out = <WithdrawalRequestModel>[];
    for (final m in maps) {
      final createdStr = m['created_at']?.toString() ?? '';
      final dt = DateTime.tryParse(createdStr);
      if (dt == null) continue;
      final dOnly = DateTime(dt.year, dt.month, dt.day);
      if (dOnly.isBefore(fromKey) || dOnly.isAfter(toKey)) continue;
      final pid = m['project_id'] is int
          ? m['project_id'] as int
          : int.tryParse(m['project_id']?.toString() ?? '') ?? 0;
      if (projectId != null && pid != projectId) continue;
      final eid = m['engineer_user_id'] is int
          ? m['engineer_user_id'] as int
          : int.tryParse(m['engineer_user_id']?.toString() ?? '') ?? 0;
      if (engineerUserId != null && eid != engineerUserId) continue;
      final row = Map<String, dynamic>.from(m);
      row['project_name'] = projectNameById[pid];
      out.add(WithdrawalRequestModel.fromMap(row));
    }
    return out;
  }

  Future<WithdrawalRequestModel?> getOpenWithdrawalRequestForLocationPhase({
    required int locationId,
    required String phase,
  }) async {
    final db = await database;
    final maps = await db.query(
      'withdrawal_requests',
      where:
          'location_id = ? AND phase = ? AND fulfilled_at IS NULL AND overall_status IN (?, ?)',
      whereArgs: [
        locationId,
        phase,
        WithdrawalRequestModel.statusPending,
        WithdrawalRequestModel.statusApproved,
      ],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _wrFromRow(maps.first);
  }

  Future<WithdrawalRequestModel> createWithdrawalRequest({
    required int projectId,
    required int locationId,
    required String phase,
    required int engineerUserId,
    required String engineerUserName,
    required String locationPathLabel,
  }) async {
    final db = await database;
    final ex = await db.query(
      'withdrawal_requests',
      where:
          'location_id = ? AND phase = ? AND fulfilled_at IS NULL AND overall_status IN (?, ?)',
      whereArgs: [
        locationId,
        phase,
        WithdrawalRequestModel.statusPending,
        WithdrawalRequestModel.statusApproved,
      ],
    );
    if (ex.isNotEmpty) {
      final r = ex.first;
      if (r['engineer_user_id'] != engineerUserId) {
        throw Exception('existing_request_other_engineer');
      }
      if (r['overall_status'] == WithdrawalRequestModel.statusApproved) {
        throw Exception('already_approved_complete_flow');
      }
      return _wrFromRow(r);
    }
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('withdrawal_requests', {
      'project_id': projectId,
      'location_id': locationId,
      'phase': phase,
      'engineer_user_id': engineerUserId,
      'engineer_user_name': engineerUserName,
      'location_path_label': locationPathLabel,
      'sem_status': WithdrawalRequestModel.statusPending,
      'om_status': WithdrawalRequestModel.statusPending,
      'overall_status': WithdrawalRequestModel.statusPending,
      'created_at': now,
      'updated_at': now,
    });
    final p = await db.query('projects', where: 'id = ?', whereArgs: [projectId]);
    final projectName = p.isNotEmpty ? (p.first['name'] as String? ?? '') : '';
    final bodyN = _wrBuildSemNewRequestBody(
      engineerUserName,
      projectName,
      locationPathLabel,
      id,
      now,
    );
    await _wrNotifyRoles(
      db,
      ['site_engineer_manager', 'projects_manager'],
      title: 'طلب سحب خامات',
      body: bodyN,
      eventType: 'withdrawal_request_new',
      actorUserId: engineerUserId,
      actorUserName: engineerUserName,
      projectName: projectName.isEmpty ? null : projectName,
      withdrawalRequestId: id,
    );
    final row = await db.query('withdrawal_requests', where: 'id = ?', whereArgs: [id]);
    return _wrFromRow(row.first);
  }

  Future<int> countPendingWithdrawalActionsForManager({
    required int userId,
    required String role,
  }) async {
    final db = await database;
    final u = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (u.isEmpty || u.first['role'] != role) return 0;
    final clause = (role == 'site_engineer_manager' || role == 'projects_manager')
        ? "overall_status = 'pending' AND sem_status = 'pending' AND fulfilled_at IS NULL"
        : role == 'operation_manager'
        ? "overall_status = 'pending' AND om_status = 'pending' AND sem_status = 'approved' AND fulfilled_at IS NULL"
        : null;
    if (clause == null) return 0;
    final v = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) AS c FROM withdrawal_requests WHERE $clause'),
    );
    return v ?? 0;
  }

  Future<List<WithdrawalRequestModel>> listPendingWithdrawalActionsForManager({
    required int userId,
    required String role,
  }) async {
    final db = await database;
    final u = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (u.isEmpty || u.first['role'] != role) return [];
    final where = (role == 'site_engineer_manager' || role == 'projects_manager')
        ? "wr.sem_responded_at IS NOT NULL OR (wr.overall_status = 'pending' "
              "AND wr.sem_status = 'pending' AND wr.fulfilled_at IS NULL)"
        : role == 'operation_manager'
        ? "wr.om_responded_at IS NOT NULL OR (wr.overall_status = 'pending' "
              "AND wr.om_status = 'pending' AND wr.sem_status = 'approved' "
              "AND wr.fulfilled_at IS NULL)"
        : null;
    if (where == null) return [];
    final respondedAt = (role == 'site_engineer_manager' || role == 'projects_manager')
        ? 'wr.sem_responded_at'
        : 'wr.om_responded_at';
    final rows = await db.rawQuery(
      'SELECT wr.*, p.name AS project_name FROM withdrawal_requests wr '
      'INNER JOIN projects p ON p.id = wr.project_id WHERE $where '
      'ORDER BY COALESCE($respondedAt, wr.created_at) DESC, wr.id DESC',
    );
    return rows
        .map((e) => WithdrawalRequestModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> respondWithdrawalRequest({
    required int requestId,
    required int managerUserId,
    required bool approve,
    String? reason,
  }) async {
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw Exception('reason_required');
    }
    final db = await database;
    final actor = await db.query('users', where: 'id = ?', whereArgs: [managerUserId]);
    if (actor.isEmpty) throw Exception('user not found');
    final actorRole = actor.first['role'] as String? ?? '';
    if (actorRole != 'site_engineer_manager' &&
        actorRole != 'projects_manager' &&
        actorRole != 'operation_manager') {
      throw Exception('forbidden');
    }
    final rq = await db.query('withdrawal_requests', where: 'id = ?', whereArgs: [requestId]);
    if (rq.isEmpty) throw Exception('not found');
    final row = Map<String, dynamic>.from(rq.first);
    if (row['fulfilled_at'] != null) throw Exception('closed');
    if (row['overall_status'] == WithdrawalRequestModel.statusRejected) {
      throw Exception('closed');
    }
    if (row['overall_status'] == WithdrawalRequestModel.statusApproved) {
      throw Exception('already_approved');
    }
    final now = DateTime.now().toIso8601String();
    final pid = row['project_id'] as int;
    final p = await db.query('projects', where: 'id = ?', whereArgs: [pid]);
    final projectName = p.isNotEmpty ? (p.first['name'] as String? ?? '') : '';
    final pathLabel = (row['location_path_label'] as String?) ?? '';
    final engId = row['engineer_user_id'] as int;
    final engName = (row['engineer_user_name'] as String?) ?? '';
    final actorName = (actor.first['name'] as String?) ?? '';

    if (actorRole == 'site_engineer_manager' || actorRole == 'projects_manager') {
      if (row['sem_status'] != WithdrawalRequestModel.statusPending) {
        throw Exception('already_responded');
      }
      if (!approve) {
        await db.update(
          'withdrawal_requests',
          {
            'sem_status': WithdrawalRequestModel.statusRejected,
            'sem_reason': reason!.trim(),
            'sem_responded_at': now,
            'overall_status': WithdrawalRequestModel.statusRejected,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [requestId],
        );
        await _wrAppendAndMarkActionTaken(
          db,
          withdrawalRequestId: requestId,
          recipientRole: 'site_engineer_manager',
          appendLine:
              'تم رفض الطلب — ${_formatWithdrawalSubmittedAt(now)}\nالسبب: ${reason.trim()}',
        );
        await _wrNotifyUser(db, engId,
            title: 'رفض طلب سحب خامات',
            body: 'تم رفض طلبك بسبب: ${reason.trim()}',
            eventType: 'withdrawal_request_rejected',
            actorUserId: managerUserId,
            actorUserName: actorName,
            projectName: projectName.isEmpty ? null : projectName,
            withdrawalRequestId: requestId);
        return;
      }
      await db.update(
        'withdrawal_requests',
        {
          'sem_status': WithdrawalRequestModel.statusApproved,
          'sem_responded_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );
      await _wrAppendAndMarkActionTaken(
        db,
        withdrawalRequestId: requestId,
        recipientRole: 'site_engineer_manager',
        appendLine: 'تم الموافقة على الطلب — ${_formatWithdrawalSubmittedAt(now)}',
      );
      final createdAt = (row['created_at'] as String?) ?? now;
      final omBody = _wrBuildOmRequestBody(
        engName,
        projectName,
        pathLabel,
        requestId,
        createdAt,
        now,
      );
      await _wrNotifyRoles(
        db,
        ['operation_manager'],
        title: 'طلب سحب خامات',
        body: omBody,
        eventType: 'withdrawal_request_pending_om',
        actorUserId: engId,
        actorUserName: engName,
        projectName: projectName.isEmpty ? null : projectName,
        withdrawalRequestId: requestId,
      );
      return;
    }

    if (row['sem_status'] != WithdrawalRequestModel.statusApproved) {
      throw Exception('sem_approval_required');
    }
    if (row['om_status'] != WithdrawalRequestModel.statusPending) {
      throw Exception('already_responded');
    }
    if (!approve) {
      await db.update(
        'withdrawal_requests',
        {
          'om_status': WithdrawalRequestModel.statusRejected,
          'om_reason': reason!.trim(),
          'om_responded_at': now,
          'overall_status': WithdrawalRequestModel.statusRejected,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [requestId],
      );
      await _wrAppendAndMarkActionTaken(
        db,
        withdrawalRequestId: requestId,
        recipientRole: 'operation_manager',
        appendLine:
            'تم رفض الطلب — ${_formatWithdrawalSubmittedAt(now)}\nالسبب: ${reason.trim()}',
      );
      await _wrAppendToWithdrawalNotification(
        db,
        withdrawalRequestId: requestId,
        recipientRole: 'site_engineer_manager',
        appendLine:
            'رُفض من مدير العمليات — ${_formatWithdrawalSubmittedAt(now)}\nالسبب: ${reason.trim()}',
      );
      await _wrNotifyUser(db, engId,
          title: 'رفض طلب سحب خامات',
          body: 'تم رفض طلبك بسبب: ${reason.trim()}',
          eventType: 'withdrawal_request_rejected',
          actorUserId: managerUserId,
          actorUserName: actorName,
          projectName: projectName.isEmpty ? null : projectName,
          withdrawalRequestId: requestId);
      return;
    }
    await db.update(
      'withdrawal_requests',
      {
        'om_status': WithdrawalRequestModel.statusApproved,
        'om_responded_at': now,
        'overall_status': WithdrawalRequestModel.statusApproved,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );
    await _wrAppendAndMarkActionTaken(
      db,
      withdrawalRequestId: requestId,
      recipientRole: 'operation_manager',
      appendLine: 'تم الموافقة على الطلب — ${_formatWithdrawalSubmittedAt(now)}',
    );
    await _wrAppendToWithdrawalNotification(
      db,
      withdrawalRequestId: requestId,
      recipientRole: 'site_engineer_manager',
      appendLine:
          'وافق مدير العمليات على الطلب — ${_formatWithdrawalSubmittedAt(now)}',
    );
    await _wrNotifyUser(db, engId,
        title: 'تمت الموافقة على طلب سحب الخامات',
        body:
            'تمت الموافقة على طلب السحب — يمكنك إكمال عملية السحب وإرفاق '
            'الملفات المطلوبة (إذن الصرف وإذن التسليم).\n'
            'الموقع: ${pathLabel.isEmpty ? '—' : pathLabel} — مشروع "$projectName"',
        eventType: 'withdrawal_request_approved',
        actorUserId: managerUserId,
        actorUserName: actorName,
        projectName: projectName.isEmpty ? null : projectName,
        withdrawalRequestId: requestId);
  }

  Future<void> fulfillWithdrawalRequest({
    required int requestId,
    required int engineerUserId,
  }) async {
    final db = await database;
    final rq = await db.query('withdrawal_requests', where: 'id = ?', whereArgs: [requestId]);
    if (rq.isEmpty) throw Exception('not found');
    final row = rq.first;
    if (row['engineer_user_id'] != engineerUserId) throw Exception('forbidden');
    if (row['overall_status'] != WithdrawalRequestModel.statusApproved) {
      throw Exception('not_approved');
    }
    if (row['fulfilled_at'] != null) return;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'withdrawal_requests',
      {'fulfilled_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  /// حذف خطط العمل والهيكلة والمخازن والسحوبات والحضور محلياً (SQLite).
  Future<Map<String, int>> purgeOperationalData() async {
    final db = await database;
    const tables = <String>[
      'withdrawal_requests',
      'detailed_report_lines',
      'detailed_reports',
      'location_withdrawal',
      'location_materials',
      'ir_mir_uploads',
      'project_stock_ledger',
      'project_stock',
      'building_cutlist_images',
      'building_materials',
      'units',
      'buildings',
      'zones',
      'project_locations',
      'projects',
      'contractors',
      'attendance_records',
    ];
    final before = <String, int>{};
    for (final table in tables) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table'),
      );
      before[table] = count ?? 0;
    }
    await db.transaction((txn) async {
      for (final table in tables) {
        await txn.delete(table);
      }
    });
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

  Future<List<int>> createExpenseStatements({
    required int userId,
    int? projectId,
    String? projectName,
    required List<ExpenseItem> expenses,
    bool autoApprove = false,
  }) async {
    final db = await database;
    final users = await db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (users.isEmpty) throw Exception('user not found');
    final user = users.first;
    final items = expenses.where((e) {
      final a = double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return e.description.trim().isNotEmpty ||
          a != 0 ||
          (e.imagePath != null && e.imagePath!.trim().isNotEmpty);
    }).toList();
    if (items.isEmpty) {
      throw Exception('أضف بند صرف واحداً على الأقل');
    }
    if (!autoApprove &&
        projectId == null &&
        (projectName == null || projectName.trim().isEmpty)) {
      throw Exception('اختر المشروع');
    }
    final resolvedProjectId =
        (projectId != null && projectId > 0) ? projectId : null;
    final resolvedProjectName = projectName?.trim();
    final now = DateTime.now().toIso8601String();
    final status = autoApprove
        ? ExpenseStatementModel.statusApproved
        : ExpenseStatementModel.statusPending;
    final source = autoApprove ? 'manager_direct' : 'engineer';
    final ids = <int>[];
    for (final item in items) {
      final amount =
          double.tryParse(item.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final id = await db.insert('expense_statements', {
        'submitter_user_id': userId,
        'submitter_user_name': user['name'],
        'submitter_role': user['role'] ?? '',
        'balance_user_id': userId,
        'project_id': resolvedProjectId,
        'project_name':
            (resolvedProjectName != null && resolvedProjectName.isNotEmpty)
                ? resolvedProjectName
                : null,
        'description': item.description.trim(),
        'amount': amount,
        'image_path': item.imagePath,
        'status': status,
        'responded_by_user_id': autoApprove ? userId : null,
        'responded_by_user_name': autoApprove ? user['name'] : null,
        'responded_at': autoApprove ? now : null,
        'created_at': now,
        'source': source,
      });
      ids.add(id);
      if (autoApprove && amount > 0) {
        final current = await getEngineerBalance(userId);
        await setEngineerBalance(userId, current - amount);
      }
    }
    if (!autoApprove) {
      final approvers = await db.query(
        'users',
        where: 'LOWER(TRIM(email)) = ? OR role = ?',
        whereArgs: [ExpenseStatementModel.approverEmail, 'projects_manager'],
      );
      if (approvers.isNotEmpty) {
        final a = approvers.first;
        await db.insert('notifications', {
          'recipient_user_id': a['id'],
          'recipient_role': a['role'],
          'title': 'بيان صرف جديد بانتظار الاعتماد',
          'body':
              'قام "${user['name']}" بإرسال ${ids.length} بند صرف${projectName != null && projectName.isNotEmpty ? ' — مشروع "$projectName"' : ''} بانتظار اعتمادكم.',
          'event_type': 'expense_statement_submitted',
          'actor_user_id': userId,
          'actor_user_name': user['name'],
          'project_name': projectName,
          'created_at': now,
          'is_read': 0,
        });
      }
    }
    return ids;
  }

  Future<List<ExpenseStatementModel>> getExpenseStatements({
    List<String>? statuses,
  }) async {
    final db = await database;
    List<Map<String, Object?>> rows;
    if (statuses != null && statuses.isNotEmpty) {
      final placeholders = List.filled(statuses.length, '?').join(',');
      rows = await db.rawQuery(
        'SELECT * FROM expense_statements WHERE status IN ($placeholders) ORDER BY created_at DESC, id DESC',
        statuses,
      );
    } else {
      rows = await db.query(
        'expense_statements',
        orderBy: 'created_at DESC, id DESC',
      );
    }
    return rows
        .map((e) => ExpenseStatementModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> respondExpenseStatement({
    required int statementId,
    required int actorUserId,
    required bool approve,
    String? reason,
  }) async {
    final db = await database;
    final actors = await db.query('users', where: 'id = ?', whereArgs: [actorUserId]);
    if (actors.isEmpty) throw Exception('user not found');
    final actor = actors.first;
    final email = (actor['email'] ?? '').toString().trim().toLowerCase();
    final role = (actor['role'] ?? '').toString().trim();
    if (email != ExpenseStatementModel.approverEmail &&
        role != 'projects_manager') {
      throw Exception('غير مصرح بالاعتماد أو الرفض');
    }
    final rows = await db.query(
      'expense_statements',
      where: 'id = ?',
      whereArgs: [statementId],
    );
    if (rows.isEmpty) throw Exception('البيان غير موجود');
    final row = rows.first;
    if ((row['status'] ?? '') != ExpenseStatementModel.statusPending) {
      throw Exception('تم البت في هذا البيان مسبقاً');
    }
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      throw Exception('سبب الرفض مطلوب');
    }
    final now = DateTime.now().toIso8601String();
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final submitterId = row['submitter_user_id'] as int;
    final balanceUserId = row['balance_user_id'] as int;
    final projectName = row['project_name'] as String?;
    final description = (row['description'] ?? '').toString();

    if (approve) {
      await db.update(
        'expense_statements',
        {
          'status': ExpenseStatementModel.statusApproved,
          'responded_by_user_id': actorUserId,
          'responded_by_user_name': actor['name'],
          'responded_at': now,
          'rejection_reason': null,
        },
        where: 'id = ?',
        whereArgs: [statementId],
      );
      if (amount > 0) {
        final current = await getEngineerBalance(balanceUserId);
        await setEngineerBalance(balanceUserId, current - amount);
      }
      await _wrNotifyUser(
        db,
        submitterId,
        title: 'تم اعتماد بيان الصرف',
        body:
            'تم اعتماد بيان الصرف الخاص بكم من مدير المشروعات${description.isNotEmpty ? '\nالبيان: $description' : ''}\nالمبلغ: ${amount.toStringAsFixed(2)}${projectName != null && projectName.isNotEmpty ? '\nالمشروع: $projectName' : ''}',
        eventType: 'expense_statement_approved',
        actorUserId: actorUserId,
        actorUserName: actor['name'] as String?,
        projectName: projectName,
      );
    } else {
      await db.update(
        'expense_statements',
        {
          'status': ExpenseStatementModel.statusRejected,
          'rejection_reason': reason!.trim(),
          'responded_by_user_id': actorUserId,
          'responded_by_user_name': actor['name'],
          'responded_at': now,
        },
        where: 'id = ?',
        whereArgs: [statementId],
      );
      await _wrNotifyUser(
        db,
        submitterId,
        title: 'تم رفض بيان الصرف',
        body:
            'تم رفض بيان الصرف الخاص بكم من مدير المشروعات ويجب إعادة إدخاله مرة أخرى.\nسبب الرفض: ${reason.trim()}${description.isNotEmpty ? '\nالبيان: $description' : ''}\nالمبلغ: ${amount.toStringAsFixed(2)}',
        eventType: 'expense_statement_rejected',
        actorUserId: actorUserId,
        actorUserName: actor['name'] as String?,
        projectName: projectName,
      );
    }
  }

  Future<void> deleteExpenseStatement({
    required int statementId,
    required int actorUserId,
  }) async {
    final db = await database;
    final actors = await db.query('users', where: 'id = ?', whereArgs: [actorUserId]);
    if (actors.isEmpty) throw Exception('غير مصرح بالحذف');
    final email = (actors.first['email'] ?? '').toString().trim().toLowerCase();
    if (email != UserModel.primaryAppAdminEmail.toLowerCase()) {
      throw Exception('غير مصرح بالحذف');
    }
    final rows = await db.query(
      'expense_statements',
      where: 'id = ?',
      whereArgs: [statementId],
    );
    if (rows.isEmpty) throw Exception('البيان غير موجود');
    final row = rows.first;
    if ((row['status'] ?? '') == ExpenseStatementModel.statusApproved) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0;
      if (amount > 0) {
        final current = await getEngineerBalance(row['balance_user_id'] as int);
        await setEngineerBalance(row['balance_user_id'] as int, current + amount);
      }
    }
    await db.delete('expense_statements', where: 'id = ?', whereArgs: [statementId]);
  }
}
