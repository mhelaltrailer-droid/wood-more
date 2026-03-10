-- Wood & More - PostgreSQL schema and seed data
-- =============================================================================
-- IMPORTANT: Run this script in the APPLICATION database only, not in "public"
-- or the default postgres database.
--
-- 1. First run: backend/01-create-database.sql (while connected to "postgres")
--    → This creates a dedicated database: wood_more
-- 2. In Beekeeper (أو Neon SQL Editor): اتصل بقاعدة wood_more
-- 3. Then run THIS file (init-db.sql) in that connection.
--    → All tables and seed data will be created inside wood_more.
-- (Docker Compose uses POSTGRES_DB=wood_more and runs this script automatically.)
--
-- إذا كانت قاعدة Neon موجودة مسبقاً وبدون أعمدة movement_type/document_path
-- في engineer_custody، شغّل مرة واحدة: migrations/001_add_engineer_custody_movement_type.sql
-- من Neon Console → SQL Editor (انظر التعليمات داخل الملف).
-- =============================================================================

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL,
  password TEXT NOT NULL DEFAULT '0000'
);

-- Add password column if upgrading from an older schema (safe to run multiple times)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema() AND table_name = 'users' AND column_name = 'password'
  ) THEN
    ALTER TABLE users ADD COLUMN password TEXT NOT NULL DEFAULT '0000';
    UPDATE users SET password = '0000' WHERE password IS NULL;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS projects (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS attendance_records (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  type TEXT NOT NULL,
  date_time TEXT NOT NULL,
  location TEXT NOT NULL,
  project_id INTEGER,
  project_name TEXT,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS materials (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_reports (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
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
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'daily_reports' AND column_name = 'contractors_json') THEN
    ALTER TABLE daily_reports ADD COLUMN contractors_json TEXT;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS zones (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS buildings (
  id SERIAL PRIMARY KEY,
  zone_id INTEGER NOT NULL REFERENCES zones(id),
  name TEXT NOT NULL,
  storage_info TEXT,
  model_details TEXT,
  cut_list TEXT
);

CREATE TABLE IF NOT EXISTS supervisors (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS contractors (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS project_stock (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  material_name TEXT NOT NULL,
  quantity TEXT NOT NULL,
  unit TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS project_stock_ledger (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  material_name TEXT NOT NULL,
  unit TEXT NOT NULL,
  quantity_delta REAL NOT NULL,
  type TEXT NOT NULL,
  created_at TEXT NOT NULL,
  user_id INTEGER REFERENCES users(id),
  user_name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS units (
  id SERIAL PRIMARY KEY,
  building_id INTEGER NOT NULL REFERENCES buildings(id),
  name TEXT NOT NULL,
  model TEXT NOT NULL,
  image_path TEXT
);

CREATE TABLE IF NOT EXISTS building_materials (
  id SERIAL PRIMARY KEY,
  building_id INTEGER NOT NULL REFERENCES buildings(id),
  material_name TEXT NOT NULL,
  quantity TEXT NOT NULL,
  unit TEXT NOT NULL,
  length TEXT DEFAULT '',
  pieces_count TEXT DEFAULT '',
  total_length TEXT DEFAULT '',
  total_area TEXT DEFAULT '',
  image_path TEXT
);

CREATE TABLE IF NOT EXISTS building_cutlist_images (
  id SERIAL PRIMARY KEY,
  building_id INTEGER NOT NULL REFERENCES buildings(id),
  image_path TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS engineer_balance (
  user_id INTEGER PRIMARY KEY REFERENCES users(id),
  balance REAL NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS engineer_custody (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  amount REAL NOT NULL,
  created_at TEXT NOT NULL,
  note TEXT
);

-- Add movement_type and document_path for custody vs add_balance/withdraw_balance (safe to run multiple times)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'engineer_custody' AND column_name = 'movement_type') THEN
    ALTER TABLE engineer_custody ADD COLUMN movement_type TEXT DEFAULT 'custody';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'engineer_custody' AND column_name = 'document_path') THEN
    ALTER TABLE engineer_custody ADD COLUMN document_path TEXT;
  END IF;
END $$;

-- Seed users (password: default 0000; app_admin h@h.com uses 123)
INSERT INTO users (name, email, role, password) VALUES
  ('Hany', 'hany.samir1708@gmail.com', 'site_engineer', '0000'),
  ('Emam', 'amirelazab46@gmail.com', 'site_engineer', '0000'),
  ('Mansur', 'saedm0566@gmail.com', 'site_engineer', '0000'),
  ('Mahmud', 'mahmoudsiko630@gmail.com', 'site_engineer', '0000'),
  ('Abdhusseny', 'abdallaelhosseny1011@gmail.com', 'site_engineer', '0000'),
  ('Hamza', 'hamzamhamad704@gmail.com', 'site_engineer', '0000'),
  ('Gohary', 'mohamedelgohary371@gmail.com', 'site_engineer', '0000'),
  ('Amr', 'amrelshabrawy55@gmail.com', 'site_engineer', '0000'),
  ('Hassan', 'mouhammed.helal@gmail.com', 'site_engineer', '0000'),
  ('Helal', 'mouhamedhelal.cor@gmail.com', 'site_engineer_manager', '0000'),
  ('Shams', 'islam.shams2050@gmail.com', 'site_engineer_manager', '0000'),
  ('Abdrhman', 'AbdelrhmanEllaithy828@gmail.com', 'site_engineer_manager', '0000'),
  ('مسؤول التطبيق', 'mouhammedhelal@gmail.com', 'app_admin', '0000'),
  ('Helal', 'h@h.com', 'app_admin', '123'),
  ('account manager', 'Account@gmail.com', 'accountant', '0000'),
  ('Cipherpath', 'cipherpath@proton.me', 'app_admin', '0000'),
  ('Test Site Engineer', 'test-site-engineer@example.com', 'site_engineer', '0000')
ON CONFLICT (email) DO NOTHING;

-- Seed projects
INSERT INTO projects (name) VALUES
  ('UTC_Z5_CRC_F'), ('Mivida 31_CRC_F'), ('UTC_Z5_EMAAR Building C_F'), ('Zed east_ORASCOM_F'),
  ('Belle Vie_El-Hazek_F'), ('CAIRO GATE elain (02)_CRC_F'), ('Cairo gate_ACC_W'), ('Z1_EMAAR_F'),
  ('Community Center_CRC_W'), ('Terrace Zayed_CRC_W'), ('Silver Sands_REDCON_D'), ('CAR SHADE_W&M_W'),
  ('OLD CITY_ORASCOM_W'), ('Cairo gate-Eden_ATRUM_F'), ('AUC Campus Expansion_Orascom_W&F'),
  ('UTC - 2 Villa- Link International_W'), ('UTC - 2 Villa- Link International_F'), ('City Gate_CCC_W'),
  ('cairo gate - locanda_INOVOO_F'), ('Village West _ club_FIT-OUT_W'), ('Village West _Villa_W'),
  ('Mivida gardens_Atrium_F'), ('Village West_CRC_ F'), ('Up Town Cairo _Z5 _EMAAR_W'), ('Belle Vie _ EMAAR_W'),
  ('Village West _ CRC_ W'), ('Wood&More(head office)')
;

-- Seed default materials (same list as app default_materials - only when table is empty)
INSERT INTO materials (name)
SELECT name FROM unnest(ARRAY[
  'وزر ((white))((f099))((700 cm))',
  'زاوية 9.8*4 عرض 10سم سمك 5مم((Angle 9.8*4))((10cm))((10 cm))',
  'زاواية 8*7.5 عرض 8سم سمك 5مم((Angle 8*7.5))((8cm))((8 cm))',
  'زاواية 7.5*8.5 عرض 12سم سمك 5مم((Angle 7.5*8.5))((12cm))((12 cm))',
  'زاواية 6.5*8.5 عرض 10سم سمك 5مم((Angle 8.5*6.5))((10cm))((10 cm))',
  'زاواية 4.4.5 عرض 12سم سمك 4مم((Angle 4*4.5))((12cm))((12 cm))',
  'زاواية 4*4.5 عرض 9.5سم سمك 5مم((Angle 4*4.5))((9.5cm))((9.5 cm))',
  'زاواية 4*4.5 عرض 12سم سمك 5مم((Angle 4*4.5))((12cm))((12 cm))',
  'زاواية 3*2.5 عرض 10سم سمك 4مم((Angle 3*2.5))((10cm))((10 cm))',
  'WPC - wood grain((P7))((12*12))((100 cm))',
  'WPC - wood grain((P6))((20*80))((350 cm))',
  'WPC - wood grain((P6))((20*80))((320 cm))',
  'WPC - wood grain((P6))((20*20))((85 cm))',
  'WPC - wood grain((P6))((20*20))((40 cm))',
  'WPC - wood grain((P6))((20*20))((166 cm))',
  'WPC - wood grain((P6))((20*20))((100 cm))',
  'WPC - wood grain((P6))((20*15))((400 cm))',
  'WPC - wood grain((P6))((20*15))((340 cm))',
  'WPC - wood grain((P6))((20*15))((290 cm))',
  'WPC - wood grain((P6))((20*15))((150 cm))',
  'WPC - wood grain((P6))((20*15))((100 cm))',
  'WPC - wood grain((P6))((20*10))((360 cm))',
  'WPC - wood grain((P6))((20*10))((290 cm))',
  'WPC - wood grain((P6))((150*6))((200 cm))',
  'WPC - wood grain((P6))((15*5))((85 cm))',
  'WPC - wood grain((P6))((15*5))((360 cm))',
  'WPC - wood grain((P6))((15*5))((230 cm))',
  'WPC - wood grain((P6))((15*15))((300 cm))',
  'WPC - wood grain((P6))((15*15))((240 cm))',
  'WPC - wood grain((P6))((12*12))((360 cm))',
  'WPC - wood grain((P6))((12*12))((300 cm))',
  'WPC - wood grain((P6))((12*12))((290 cm))',
  'WPC - wood grain((P6))((12*12))((280 cm))',
  'WPC - wood grain((P6))((12*12))((270 cm))',
  'WPC - wood grain((P6))((12*12))((240 cm))',
  'WPC - wood grain((P6))((12*12))((100 cm))',
  'WPC - wood grain((P6))((10*5))((90 cm))',
  'WPC - wood grain((P6))((10*5))((80 cm))',
  'WPC - wood grain((P6))((10*5))((70 cm))',
  'WPC - wood grain((P6))((10*5))((400 cm))',
  'WPC - wood grain((P6))((10*5))((360 cm))',
  'WPC - wood grain((P6))((10*5))((350 cm))',
  'WPC - wood grain((P6))((10*5))((289 cm))',
  'WPC - wood grain((P6))((10*5))((280 cm))',
  'WPC - wood grain((P6))((10*5))((245 cm))',
  'WPC - wood grain((P6))((10*5))((235 cm))',
  'WPC - wood grain((P6))((10*5))((220 cm))',
  'WPC - wood grain((P6))((10*5))((200 cm))',
  'WPC - wood grain((P6))((10*5))((190 cm))',
  'WPC - wood grain((P6))((10*5))((160 cm))',
  'WPC - wood grain((P6))((10*5))((150 cm))',
  'WPC - wood grain((P6))((10*5))((140 cm))',
  'WPC - wood grain((P6))((10*5))((130 cm))',
  'WPC - wood grain((P6))((10*5))((120 cm))',
  'WPC - wood grain((P6))((10*5))((110 cm))',
  'WPC - wood grain((P6))((10*5))((100 cm))',
  'WPC - wood grain((P6))((10*10))((80 cm))',
  'WPC - wood grain((P6))((10*10))((65 cm))',
  'WPC - wood grain((P6))((10*10))((60 cm))',
  'WPC - wood grain((P6))((10*10))((320 cm))',
  'WPC - wood grain((P6))((10*10))((270 cm))',
  'WPC - wood grain((P6))((10*10))((265 cm))',
  'WPC - wood grain((P6))((10*10))((240 cm))',
  'WPC - wood grain((P6))((10*10))((200 cm))',
  'WPC - wood grain((P6))((10*10))((160 cm))',
  'WPC - wood grain((P6))((10*10))((140 cm))',
  'WPC - wood grain((P6))((10*10))((130 cm))',
  'WPC - wood grain((P6))((10*10))((125 cm))',
  'WPC - wood grain((P6))((10*10))((120 cm))',
  'WPC - wood grain((P6))((10*10))((100 cm))',
  'Steel plate 4*3 - 6m((Steel))((4*3))((600 cm))',
  'Steel plate 4*3 - 5m((Steel))((4*3))((500 cm))',
  'Steel plate 4*3 - 3m((Steel))((4*3))((300 cm))',
  'Steel box 4*4 - 6 m - 2mm((Steel ))((4*4))((600 cm))',
  'Steel box 3*3 - 6 m - 2mm((Steel ))((3*3))((600 cm))',
  'HDF((oak skyline pearl ))((grey1285*194*8mm))(())',
  'silant((silant))((silant))(())',
  'keels((keels))((40*20.5))((300 cm))',
  'Clips -Steel((Clips ))((Steel))(())',
  'Clips - plastic((Clips ))(( plastic))(())',
  'steel shs 30*30*2mm length 6m',
  'steel plate 90*40*3*mm',
  'STEEL BOX 30*30 MM LENGTH 6M',
  'STEEL BOX 40*40 MM LENGTH 6M'
]) AS t(name)
WHERE (SELECT COUNT(*) FROM materials) = 0;

-- If materials already exist, add any from the list that are missing (نفس القائمة أعلاه لضمان ظهور جميع الخامات)
INSERT INTO materials (name)
SELECT t.name FROM unnest(ARRAY[
  'وزر ((white))((f099))((700 cm))',
  'زاوية 9.8*4 عرض 10سم سمك 5مم((Angle 9.8*4))((10cm))((10 cm))',
  'زاواية 8*7.5 عرض 8سم سمك 5مم((Angle 8*7.5))((8cm))((8 cm))',
  'زاواية 7.5*8.5 عرض 12سم سمك 5مم((Angle 7.5*8.5))((12cm))((12 cm))',
  'زاواية 6.5*8.5 عرض 10سم سمك 5مم((Angle 8.5*6.5))((10cm))((10 cm))',
  'زاواية 4.4.5 عرض 12سم سمك 4مم((Angle 4*4.5))((12cm))((12 cm))',
  'زاواية 4*4.5 عرض 9.5سم سمك 5مم((Angle 4*4.5))((9.5cm))((9.5 cm))',
  'زاواية 4*4.5 عرض 12سم سمك 5مم((Angle 4*4.5))((12cm))((12 cm))',
  'زاواية 3*2.5 عرض 10سم سمك 4مم((Angle 3*2.5))((10cm))((10 cm))',
  'WPC - wood grain((P7))((12*12))((100 cm))',
  'WPC - wood grain((P6))((20*80))((350 cm))',
  'WPC - wood grain((P6))((20*80))((320 cm))',
  'WPC - wood grain((P6))((20*20))((85 cm))',
  'WPC - wood grain((P6))((20*20))((40 cm))',
  'WPC - wood grain((P6))((20*20))((166 cm))',
  'WPC - wood grain((P6))((20*20))((100 cm))',
  'WPC - wood grain((P6))((20*15))((400 cm))',
  'WPC - wood grain((P6))((20*15))((340 cm))',
  'WPC - wood grain((P6))((20*15))((290 cm))',
  'WPC - wood grain((P6))((20*15))((150 cm))',
  'WPC - wood grain((P6))((20*15))((100 cm))',
  'WPC - wood grain((P6))((20*10))((360 cm))',
  'WPC - wood grain((P6))((20*10))((290 cm))',
  'WPC - wood grain((P6))((150*6))((200 cm))',
  'WPC - wood grain((P6))((15*5))((85 cm))',
  'WPC - wood grain((P6))((15*5))((360 cm))',
  'WPC - wood grain((P6))((15*5))((230 cm))',
  'WPC - wood grain((P6))((15*15))((300 cm))',
  'WPC - wood grain((P6))((15*15))((240 cm))',
  'WPC - wood grain((P6))((12*12))((360 cm))',
  'WPC - wood grain((P6))((12*12))((300 cm))',
  'WPC - wood grain((P6))((12*12))((290 cm))',
  'WPC - wood grain((P6))((12*12))((280 cm))',
  'WPC - wood grain((P6))((12*12))((270 cm))',
  'WPC - wood grain((P6))((12*12))((240 cm))',
  'WPC - wood grain((P6))((12*12))((100 cm))',
  'WPC - wood grain((P6))((10*5))((90 cm))',
  'WPC - wood grain((P6))((10*5))((80 cm))',
  'WPC - wood grain((P6))((10*5))((70 cm))',
  'WPC - wood grain((P6))((10*5))((400 cm))',
  'WPC - wood grain((P6))((10*5))((360 cm))',
  'WPC - wood grain((P6))((10*5))((350 cm))',
  'WPC - wood grain((P6))((10*5))((289 cm))',
  'WPC - wood grain((P6))((10*5))((280 cm))',
  'WPC - wood grain((P6))((10*5))((245 cm))',
  'WPC - wood grain((P6))((10*5))((235 cm))',
  'WPC - wood grain((P6))((10*5))((220 cm))',
  'WPC - wood grain((P6))((10*5))((200 cm))',
  'WPC - wood grain((P6))((10*5))((190 cm))',
  'WPC - wood grain((P6))((10*5))((160 cm))',
  'WPC - wood grain((P6))((10*5))((150 cm))',
  'WPC - wood grain((P6))((10*5))((140 cm))',
  'WPC - wood grain((P6))((10*5))((130 cm))',
  'WPC - wood grain((P6))((10*5))((120 cm))',
  'WPC - wood grain((P6))((10*5))((110 cm))',
  'WPC - wood grain((P6))((10*5))((100 cm))',
  'WPC - wood grain((P6))((10*10))((80 cm))',
  'WPC - wood grain((P6))((10*10))((65 cm))',
  'WPC - wood grain((P6))((10*10))((60 cm))',
  'WPC - wood grain((P6))((10*10))((320 cm))',
  'WPC - wood grain((P6))((10*10))((270 cm))',
  'WPC - wood grain((P6))((10*10))((265 cm))',
  'WPC - wood grain((P6))((10*10))((240 cm))',
  'WPC - wood grain((P6))((10*10))((200 cm))',
  'WPC - wood grain((P6))((10*10))((160 cm))',
  'WPC - wood grain((P6))((10*10))((140 cm))',
  'WPC - wood grain((P6))((10*10))((130 cm))',
  'WPC - wood grain((P6))((10*10))((125 cm))',
  'WPC - wood grain((P6))((10*10))((120 cm))',
  'WPC - wood grain((P6))((10*10))((100 cm))',
  'Steel plate 4*3 - 6m((Steel))((4*3))((600 cm))',
  'Steel plate 4*3 - 5m((Steel))((4*3))((500 cm))',
  'Steel plate 4*3 - 3m((Steel))((4*3))((300 cm))',
  'Steel box 4*4 - 6 m - 2mm((Steel ))((4*4))((600 cm))',
  'Steel box 3*3 - 6 m - 2mm((Steel ))((3*3))((600 cm))',
  'HDF((oak skyline pearl ))((grey1285*194*8mm))(())',
  'silant((silant))((silant))(())',
  'keels((keels))((40*20.5))((300 cm))',
  'Clips -Steel((Clips ))((Steel))(())',
  'Clips - plastic((Clips ))(( plastic))(())',
  'steel shs 30*30*2mm length 6m',
  'steel plate 90*40*3*mm',
  'STEEL BOX 30*30 MM LENGTH 6M',
  'STEEL BOX 40*40 MM LENGTH 6M'
]) AS t(name)
WHERE NOT EXISTS (SELECT 1 FROM materials m WHERE m.name = t.name);