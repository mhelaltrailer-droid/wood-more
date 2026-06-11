-- ملخص ما تم تنفيذه اليوم (خطة عمل الغد)
ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS executed_today_summary TEXT;
