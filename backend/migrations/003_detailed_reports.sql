-- التقرير المفصل: مراحل العمل + جداول التقرير المفصل
-- Run once in Neon SQL Editor (اتصل بقاعدة wood_more ثم الصق وتشغيل).

CREATE TABLE IF NOT EXISTS work_phases (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS detailed_reports (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  report_datetime TEXT NOT NULL,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  supervisor_id INTEGER REFERENCES supervisors(id),
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS detailed_report_lines (
  id SERIAL PRIMARY KEY,
  detailed_report_id INTEGER NOT NULL REFERENCES detailed_reports(id) ON DELETE CASCADE,
  contractor_id INTEGER NOT NULL REFERENCES contractors(id),
  contractor_workers_count INTEGER NOT NULL CHECK (contractor_workers_count >= 1 AND contractor_workers_count <= 10),
  self_workers_count INTEGER NOT NULL DEFAULT 0 CHECK (self_workers_count >= 0 AND self_workers_count <= 10),
  zone_id INTEGER NOT NULL REFERENCES zones(id),
  building_id INTEGER NOT NULL REFERENCES buildings(id),
  phase_id INTEGER NOT NULL REFERENCES work_phases(id),
  workers_count INTEGER NOT NULL CHECK (workers_count >= 1)
);

DO $$
BEGIN
  IF (SELECT COUNT(*) FROM work_phases) = 0 THEN
    INSERT INTO work_phases (name) VALUES ('تركيب اكسسوارات'), ('تقطيع WPC'), ('تركيب WPC'), ('معالجة'), ('دهان');
  END IF;
END $$;

-- بيانات تجريبية: فيلات D1–D5 وبرجولات shed01, shed02 لمشروع Cairo gate_ACC_W
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
