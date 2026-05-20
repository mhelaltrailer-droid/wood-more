-- إضافة calendar_date لسجلات الحضور (يوم التقويم المحلي من التطبيق) لمنع التكرار لنفس المشروع/اليوم
ALTER TABLE attendance_records ADD COLUMN IF NOT EXISTS calendar_date TEXT;
