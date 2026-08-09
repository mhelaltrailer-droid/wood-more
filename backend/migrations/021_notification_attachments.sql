-- إشعارات رفع الملفات: ربط الإشعار بمرفقات السجل + جدول تقارير العمليات.
-- آمن للتشغيل أكثر من مرة على قواعد Neon / wood_more المحلية.

-- ربط عام يسمح لأي إشعار بفتح مرفقات سجله عبر /attachments
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS attachment_source TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS attachment_record_id INTEGER;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS attachment_count INTEGER;

-- مستند العهدة كان يُرسل من الواجهة دون أن يُحفظ
ALTER TABLE engineer_custody ADD COLUMN IF NOT EXISTS document_path TEXT;

-- تقارير العمليات: صورها كانت إلزامية في الواجهة وغير محفوظة على الخادم
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
