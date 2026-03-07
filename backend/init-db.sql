-- Wood & More - PostgreSQL schema and seed data
-- Run once when the DB is first created

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL
);

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
  tomorrow_plan TEXT NOT NULL,
  document_path TEXT,
  images_json TEXT,
  notes TEXT,
  materials_json TEXT NOT NULL,
  expenses_json TEXT NOT NULL,
  created_at TEXT NOT NULL
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

-- Seed users
INSERT INTO users (name, email, role) VALUES
  ('Hany', 'hany.samir1708@gmail.com', 'site_engineer'),
  ('Emam', 'amirelazab46@gmail.com', 'site_engineer'),
  ('Mansur', 'saedm0566@gmail.com', 'site_engineer'),
  ('Mahmud', 'mahmoudsiko630@gmail.com', 'site_engineer'),
  ('Abdhusseny', 'abdallaelhosseny1011@gmail.com', 'site_engineer'),
  ('Hamza', 'hamzamhamad704@gmail.com', 'site_engineer'),
  ('Gohary', 'mohamedelgohary371@gmail.com', 'site_engineer'),
  ('Amr', 'amrelshabrawy55@gmail.com', 'site_engineer'),
  ('Hassan', 'mouhammed.helal@gmail.com', 'site_engineer'),
  ('Helal', 'mouhamedhelal.cor@gmail.com', 'site_engineer_manager'),
  ('Shams', 'islam.shams2050@gmail.com', 'site_engineer_manager'),
  ('Abdrhman', 'AbdelrhmanEllaithy828@gmail.com', 'site_engineer_manager'),
  ('مسؤول التطبيق', 'mouhammedhelal@gmail.com', 'app_admin'),
  ('Cipherpath', 'cipherpath@proton.me', 'app_admin'),
  ('Test Site Engineer', 'test-site-engineer@example.com', 'site_engineer')
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

-- Seed default materials (first few - app can add more)
INSERT INTO materials (name) SELECT 'وزر ((white))((f099))((700 cm))' WHERE NOT EXISTS (SELECT 1 FROM materials LIMIT 1);
