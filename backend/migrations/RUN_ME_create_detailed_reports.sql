-- ============================================================
-- إنشاء جداول التقرير المفصل إذا لم تكن موجودة
--
-- الاستخدام عند ظهور: relation "detailed_reports" does not exist
-- 1) افتح لوحة Neon (console.neon.tech) واختر مشروعك وقاعدة البيانات
-- 2) افتح SQL Editor
-- 3) انسخ هذا الملف بالكامل والصقه في المحرر
-- 4) اضغط Run / تنفيذ
-- ============================================================

-- 1) مراحل العمل
CREATE TABLE IF NOT EXISTS work_phases (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

-- 2) جدول هيكل مواقع المشروع (مطلوب لـ location_id في سطور التقرير)
CREATE TABLE IF NOT EXISTS project_locations (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  parent_id INTEGER REFERENCES project_locations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'folder' CHECK (type IN ('folder', 'work_site')),
  display_order INTEGER NOT NULL DEFAULT 0
);

-- 3) جدول التقرير المفصل (مع دعم "أخرى" و project_name)
CREATE TABLE IF NOT EXISTS detailed_reports (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  report_datetime TEXT NOT NULL,
  project_id INTEGER REFERENCES projects(id),
  project_name TEXT,
  supervisor_id INTEGER REFERENCES supervisors(id),
  created_at TEXT NOT NULL,
  summary TEXT
);

-- 4) سطور التقرير المفصل
CREATE TABLE IF NOT EXISTS detailed_report_lines (
  id SERIAL PRIMARY KEY,
  detailed_report_id INTEGER NOT NULL REFERENCES detailed_reports(id) ON DELETE CASCADE,
  contractor_id INTEGER NOT NULL REFERENCES contractors(id),
  contractor_workers_count INTEGER NOT NULL CHECK (contractor_workers_count >= 0),
  self_workers_count INTEGER NOT NULL DEFAULT 0 CHECK (self_workers_count >= 0 AND self_workers_count <= 10),
  zone_id INTEGER REFERENCES zones(id),
  building_id INTEGER REFERENCES buildings(id),
  location_id INTEGER REFERENCES project_locations(id),
  phase_id INTEGER NOT NULL REFERENCES work_phases(id),
  workers_count INTEGER NOT NULL CHECK (workers_count >= 1)
);

-- إضافة أعمدة قد تكون ناقصة (إذا الجداول وُجدت من migration قديم)
ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS project_name TEXT;
ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS summary TEXT;
ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS expenses_json TEXT;
DO $$ BEGIN ALTER TABLE detailed_reports ALTER COLUMN project_id DROP NOT NULL; EXCEPTION WHEN OTHERS THEN NULL; END $$;

ALTER TABLE detailed_report_lines ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES project_locations(id);

-- بيانات افتراضية لمراحل العمل
DO $$
BEGIN
  IF (SELECT COUNT(*) FROM work_phases) = 0 THEN
    INSERT INTO work_phases (name) VALUES ('تركيب اكسسوارات'), ('تقطيع WPC'), ('تركيب WPC'), ('معالجة'), ('دهان');
  END IF;
END $$;
