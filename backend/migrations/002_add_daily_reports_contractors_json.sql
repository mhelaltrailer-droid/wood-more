-- إضافة عمود المقاولين المتعددين (مقاول + عدد عمال لكل واحد) لجدول daily_reports
-- شغّله من Neon SQL Editor إذا كانت قاعدة البيانات موجودة مسبقاً.

ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS contractors_json TEXT;
