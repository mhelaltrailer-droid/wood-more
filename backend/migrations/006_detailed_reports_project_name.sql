-- دعم "أخرى" في التقرير المفصل: اسم مشروع مخصص يحل محل اسم المشروع في التقارير
ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS project_name TEXT;
ALTER TABLE detailed_reports ALTER COLUMN project_id DROP NOT NULL;
