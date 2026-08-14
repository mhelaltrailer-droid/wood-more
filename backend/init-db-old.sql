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

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO app_settings (key, value) VALUES ('system_locked', '0')
ON CONFLICT (key) DO NOTHING;

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

-- POST /projects relies on ON CONFLICT ((lower(btrim(name)))), which needs this index.
-- Kept non-fatal: a database that still holds duplicate project names keeps working without it.
DO $$
BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS ux_projects_name_norm
    ON projects (lower(btrim(name)));
EXCEPTION WHEN unique_violation THEN
  RAISE NOTICE 'ux_projects_name_norm not created: projects contains duplicate names (compare lower(btrim(name)))';
END $$;

CREATE TABLE IF NOT EXISTS attendance_records (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  type TEXT NOT NULL,
  date_time TEXT NOT NULL,
  calendar_date TEXT,
  location TEXT NOT NULL,
  project_id INTEGER,
  project_name TEXT,
  notes TEXT
);

CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  recipient_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_role TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  event_type TEXT NOT NULL,
  actor_user_id INTEGER,
  actor_user_name TEXT,
  project_name TEXT,
  created_at TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TEXT,
  withdrawal_request_id INTEGER,
  action_taken_at TEXT,
  attachment_source TEXT,
  attachment_record_id INTEGER,
  attachment_count INTEGER
);

-- لقواعد البيانات القديمة التي أُنشئ فيها الجدول قبل إشعارات المرفقات
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS attachment_source TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS attachment_record_id INTEGER;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS attachment_count INTEGER;

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
  ON notifications(recipient_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
  ON notifications(recipient_user_id, is_read);

CREATE TABLE IF NOT EXISTS operation_reports (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  project_id INTEGER REFERENCES projects(id),
  project_name TEXT,
  report_type TEXT NOT NULL,
  details TEXT NOT NULL DEFAULT '',
  images_json TEXT NOT NULL DEFAULT '[]',
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_operation_reports_user_created
  ON operation_reports(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS shop_darwing_notifications (
  id SERIAL PRIMARY KEY,
  recipient_user_id INTEGER NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  shop_drawing_id INTEGER,
  created_at TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_shop_darwing_notifications_recipient_created
  ON shop_darwing_notifications(recipient_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_shop_darwing_notifications_recipient_unread
  ON shop_darwing_notifications(recipient_user_id, is_read);

CREATE TABLE IF NOT EXISTS shop_drawings (
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id),
  project_name TEXT NOT NULL DEFAULT '',
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending_pm',
  created_by_user_id INTEGER NOT NULL REFERENCES users(id),
  created_by_user_name TEXT NOT NULL DEFAULT '',
  current_assignee_user_id INTEGER REFERENCES users(id),
  current_assignee_user_name TEXT,
  return_reason TEXT,
  document_type TEXT NOT NULL DEFAULT 'shop_drawing',
  external_url TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  approved_at TEXT
);

CREATE TABLE IF NOT EXISTS shop_drawing_attachments (
  id SERIAL PRIMARY KEY,
  drawing_id INTEGER NOT NULL REFERENCES shop_drawings(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  data_base64 TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS shop_drawing_actions (
  id SERIAL PRIMARY KEY,
  drawing_id INTEGER NOT NULL REFERENCES shop_drawings(id) ON DELETE CASCADE,
  actor_user_id INTEGER NOT NULL REFERENCES users(id),
  actor_user_name TEXT NOT NULL,
  action TEXT NOT NULL,
  comment TEXT,
  created_at TEXT NOT NULL
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

-- هيكل مواقع المشروع (شجري): موقع فرعي folder أو موقع عمل work_site
CREATE TABLE IF NOT EXISTS project_locations (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  parent_id INTEGER REFERENCES project_locations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'folder' CHECK (type IN ('folder', 'work_site')),
  display_order INTEGER NOT NULL DEFAULT 0
);

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
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'engineer_custody' AND column_name = 'actor_user_id') THEN
    ALTER TABLE engineer_custody ADD COLUMN actor_user_id INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'engineer_custody' AND column_name = 'actor_user_name') THEN
    ALTER TABLE engineer_custody ADD COLUMN actor_user_name TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'engineer_custody' AND column_name = 'actor_role') THEN
    ALTER TABLE engineer_custody ADD COLUMN actor_role TEXT;
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

-- Seed projects: only names that are still missing, so re-runs add nothing and change nothing
INSERT INTO projects (name)
SELECT t.name FROM unnest(ARRAY[
  'UTC_Z5_CRC_F', 'Mivida 31_CRC_F', 'UTC_Z5_EMAAR Building C_F', 'Zed east_ORASCOM_F',
  'Belle Vie_El-Hazek_F', 'CAIRO GATE elain (02)_CRC_F', 'Cairo gate_ACC_W', 'Z1_EMAAR_F',
  'Community Center_CRC_W', 'Terrace Zayed_CRC_W', 'Silver Sands_REDCON_D', 'CAR SHADE_W&M_W',
  'OLD CITY_ORASCOM_W', 'Cairo gate-Eden_ATRUM_F', 'AUC Campus Expansion_Orascom_W&F',
  'UTC - 2 Villa- Link International_W', 'UTC - 2 Villa- Link International_F', 'City Gate_CCC_W',
  'cairo gate - locanda_INOVOO_F', 'Village West _ club_FIT-OUT_W', 'Village West _Villa_W',
  'Mivida gardens_Atrium_F', 'Village West_CRC_ F', 'Up Town Cairo _Z5 _EMAAR_W', 'Belle Vie _ EMAAR_W',
  'Village West _ CRC_ W', 'Wood&More(head office)'
]) AS t(name)
WHERE NOT EXISTS (
  SELECT 1 FROM projects p WHERE lower(btrim(p.name)) = lower(btrim(t.name))
);

-- Seed default materials (قائمة الخامات المعتمدة؛ الترتيب للعرض في العميل)
INSERT INTO materials (name)
SELECT name FROM unnest(ARRAY[
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 3 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.9 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.7 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.4 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.3 m',
  'ALU - KEEL - 40*20 - L= 6 m',
  'ALU - Shadow gap - ETR11 - 21*10 - L= 6 m',
  'ALU - Profile - ETR12 - 40*41 - L= 6 m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 2.5m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1.4m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 3.7m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1m',
  'Steel box 30x30x3 mm lengh 2.45',
  'Steel C-Channel 135*50*30*2 mm length 0.035',
  'Steel box 30x30x3 mm length 3.65'
]) AS t(name)
WHERE (SELECT COUNT(*) FROM materials) = 0;

-- If materials already exist, add any from the list that are missing
INSERT INTO materials (name)
SELECT t.name FROM unnest(ARRAY[
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 3 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.9 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.7 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.4 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.3 m',
  'ALU - KEEL - 40*20 - L= 6 m',
  'ALU - Shadow gap - ETR11 - 21*10 - L= 6 m',
  'ALU - Profile - ETR12 - 40*41 - L= 6 m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 2.5m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1.4m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 3.7m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1m',
  'Steel box 30x30x3 mm lengh 2.45',
  'Steel C-Channel 135*50*30*2 mm length 0.035',
  'Steel box 30x30x3 mm length 3.65'
]) AS t(name)
WHERE NOT EXISTS (SELECT 1 FROM materials m WHERE m.name = t.name);

-- ========== التقرير المفصل (مهندس الموقع) ==========
CREATE TABLE IF NOT EXISTS work_phases (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS detailed_reports (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  report_datetime TEXT NOT NULL,
  project_id INTEGER REFERENCES projects(id),
  project_name TEXT,
  supervisor_id INTEGER REFERENCES supervisors(id),
  created_at TEXT NOT NULL,
  summary TEXT,
  executed_today_summary TEXT
);

CREATE TABLE IF NOT EXISTS detailed_report_lines (
  id SERIAL PRIMARY KEY,
  detailed_report_id INTEGER NOT NULL REFERENCES detailed_reports(id) ON DELETE CASCADE,
  contractor_id INTEGER REFERENCES contractors(id),
  contractor_workers_count INTEGER NOT NULL DEFAULT 0 CHECK (contractor_workers_count >= 0),
  self_workers_count INTEGER NOT NULL DEFAULT 0 CHECK (self_workers_count >= 0 AND self_workers_count <= 10),
  zone_id INTEGER REFERENCES zones(id),
  building_id INTEGER REFERENCES buildings(id),
  location_id INTEGER REFERENCES project_locations(id),
  phase_id INTEGER NOT NULL REFERENCES work_phases(id),
  workers_count INTEGER NOT NULL CHECK (workers_count >= 0)
);

DO $$
BEGIN
  IF (SELECT COUNT(*) FROM work_phases) = 0 THEN
    INSERT INTO work_phases (name) VALUES ('تركيب اكسسوارات'), ('تقطيع WPC'), ('تركيب WPC'), ('معالجة'), ('دهان');
  END IF;
END $$;

-- هيكلة المخازن: خامات لكل موقع فرعي + سجل السحب (مرة واحدة لكل موقع)
CREATE TABLE IF NOT EXISTS location_materials (
  id SERIAL PRIMARY KEY,
  location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
  phase TEXT NOT NULL DEFAULT 'first_fix',
  material_name TEXT NOT NULL,
  quantity TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS location_withdrawal (
  id SERIAL PRIMARY KEY,
  location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
  phase TEXT NOT NULL DEFAULT 'first_fix',
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  disbursement_permit_images_json TEXT,
  delivery_permit_images_json TEXT,
  UNIQUE(location_id, phase)
);

CREATE INDEX IF NOT EXISTS idx_location_materials_location_id ON location_materials(location_id);
CREATE INDEX IF NOT EXISTS idx_location_withdrawal_location_id ON location_withdrawal(location_id);

-- تنفيذ خطة اليوم (تأكيد/تعديل/تأجيل)
CREATE TABLE IF NOT EXISTS executed_plans (
  id SERIAL PRIMARY KEY,
  source_plan_id INTEGER REFERENCES detailed_reports(id) ON DELETE SET NULL,
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  project_id INTEGER REFERENCES projects(id),
  project_name TEXT,
  plan_date TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('confirmed', 'confirmed_edited', 'postponed')),
  modification_summary TEXT,
  postpone_reason_key TEXT,
  postpone_reason_label TEXT,
  postpone_custom_reason TEXT,
  postpone_notes TEXT,
  postpone_reopen_date TEXT,
  plan_json TEXT NOT NULL,
  created_at TEXT NOT NULL
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema() AND table_name = 'executed_plans' AND column_name = 'postpone_reopen_date'
  ) THEN
    ALTER TABLE executed_plans ADD COLUMN postpone_reopen_date TEXT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_executed_plans_plan_date ON executed_plans(plan_date);
CREATE INDEX IF NOT EXISTS idx_executed_plans_user_id ON executed_plans(user_id);

-- IR / MIR: مرفقات مهندسي المواقع (MIR أو IR حسب هيكلة المشروع)
CREATE TABLE IF NOT EXISTS ir_mir_uploads (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('mir', 'ir')),
  mir_name TEXT,
  location_id INTEGER REFERENCES project_locations(id) ON DELETE CASCADE,
  phase TEXT,
  file_name TEXT NOT NULL,
  file_mime TEXT NOT NULL,
  file_data TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ir_mir_project_kind ON ir_mir_uploads(project_id, kind);
CREATE INDEX IF NOT EXISTS idx_ir_mir_location_phase ON ir_mir_uploads(location_id, phase);

-- MS-SD: سجلات Material Submittal و Shop Drawing
CREATE TABLE IF NOT EXISTS ms_sd_records (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('ms', 'sd')),
  record_name TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ms_sd_attachments (
  id SERIAL PRIMARY KEY,
  record_id INTEGER NOT NULL REFERENCES ms_sd_records(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_mime TEXT NOT NULL,
  file_data TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ms_sd_records_project_kind ON ms_sd_records(project_id, kind);
CREATE INDEX IF NOT EXISTS idx_ms_sd_attachments_record_id ON ms_sd_attachments(record_id);

-- MoS-ITP: سجلات Method of Statement و Inspection and Test Plan
CREATE TABLE IF NOT EXISTS mos_itp_records (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('mos', 'itp')),
  record_name TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS mos_itp_attachments (
  id SERIAL PRIMARY KEY,
  record_id INTEGER NOT NULL REFERENCES mos_itp_records(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_mime TEXT NOT NULL,
  file_data TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_mos_itp_records_project_kind ON mos_itp_records(project_id, kind);
CREATE INDEX IF NOT EXISTS idx_mos_itp_attachments_record_id ON mos_itp_attachments(record_id);

-- بيانات تجريبية للتقرير المفصل: فيلات D1–D5 وبرجولات shed01, shed02 لمشروع Cairo gate_ACC_W
DO $$
DECLARE
  pid INT;
  zid INT;
  zname TEXT;
BEGIN
  SELECT id INTO pid FROM projects WHERE name = 'Cairo gate_ACC_W' LIMIT 1;
  IF pid IS NULL THEN RETURN; END IF;
  IF EXISTS (SELECT 1 FROM zones WHERE project_id = pid LIMIT 1) THEN RETURN; END IF;
  FOR zname IN SELECT unnest(ARRAY['D1','D2','D3','D4','D5'])
  LOOP
    INSERT INTO zones (project_id, name) VALUES (pid, zname) RETURNING id INTO zid;
    INSERT INTO buildings (zone_id, name) VALUES (zid, 'shed01'), (zid, 'shed02');
  END LOOP;
END $$;