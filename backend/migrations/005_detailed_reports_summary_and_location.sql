-- ملخص الأعمال اليوم + دعم موقع العمل من هيكل المشروع (project_locations)
-- شغّله من Neon SQL Editor إذا كانت قاعدة البيانات موجودة مسبقاً.

-- ملخص الأعمال اليوم في رأس التقرير
ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS summary TEXT;

-- موقع العمل من هيكل المشروع (بديل لـ zone_id + building_id)
ALTER TABLE detailed_report_lines ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES project_locations(id);

-- جعل zone_id و building_id اختيارية لدعم التقارير الجديدة التي تستخدم location_id فقط
ALTER TABLE detailed_report_lines ALTER COLUMN zone_id DROP NOT NULL;
ALTER TABLE detailed_report_lines ALTER COLUMN building_id DROP NOT NULL;

-- السماح لعدد عمال المقاول أن يكون 0 أو أكثر (يُحسب من مجموع السطور)
ALTER TABLE detailed_report_lines DROP CONSTRAINT IF EXISTS detailed_report_lines_contractor_workers_count_check;
ALTER TABLE detailed_report_lines ADD CONSTRAINT detailed_report_lines_contractor_workers_count_check
  CHECK (contractor_workers_count >= 0);
