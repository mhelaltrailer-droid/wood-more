-- ============================================================
-- التقرير المفصل: استبدال مراحل العمل بالخمس الجديدة + جعل المقاول اختيارياً
-- النسخ في Neon SQL Editor → تشغيل مرة واحدة
-- ============================================================

-- 1) استبدال مراحل العمل الثلاث بالخمس الجديدة (مع الحفاظ على البيانات إن وُجدت)
UPDATE work_phases SET name = 'تركيب اكسسوارات' WHERE id = 1;
UPDATE work_phases SET name = 'تقطيع WPC' WHERE id = 2;
UPDATE work_phases SET name = 'تركيب WPC' WHERE id = 3;
INSERT INTO work_phases (name)
SELECT 'معالجة' WHERE NOT EXISTS (SELECT 1 FROM work_phases WHERE name = 'معالجة');
INSERT INTO work_phases (name)
SELECT 'دهان' WHERE NOT EXISTS (SELECT 1 FROM work_phases WHERE name = 'دهان');

-- 2) جعل contractor_id اختيارياً (للتقرير المبسط: مرحلة + عدد عمال فقط)
ALTER TABLE detailed_report_lines
  ALTER COLUMN contractor_id DROP NOT NULL;

-- (اختياري) تخفيف قيد contractor_workers_count ليكون >= 0 إن كان القيد القديم يمنع 0
-- إذا ظهر خطأ في السطرين التاليين يمكن حذفهما
-- ALTER TABLE detailed_report_lines DROP CONSTRAINT IF EXISTS detailed_report_lines_contractor_workers_count_check;
-- ALTER TABLE detailed_report_lines ADD CONSTRAINT detailed_report_lines_contractor_workers_count_check CHECK (contractor_workers_count >= 0);
