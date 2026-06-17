-- Reports-SYS circulated reports workflow
-- Run once on existing PostgreSQL databases (Neon / local wood_more).

CREATE TABLE IF NOT EXISTS reports_sys (
  id SERIAL PRIMARY KEY,
  report_name TEXT NOT NULL,
  report_type TEXT NOT NULL,
  summary TEXT NOT NULL DEFAULT '',
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'draft',
  created_by_user_id INTEGER NOT NULL REFERENCES users(id),
  created_by_user_name TEXT NOT NULL DEFAULT '',
  current_assignee_user_id INTEGER REFERENCES users(id),
  current_assignee_user_name TEXT,
  source_report_id INTEGER REFERENCES reports_sys(id),
  rejection_reason TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived_at TEXT,
  rejected_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_sys_name_lower
  ON reports_sys (LOWER(TRIM(report_name)));

CREATE TABLE IF NOT EXISTS reports_sys_attachments (
  id SERIAL PRIMARY KEY,
  report_id INTEGER NOT NULL REFERENCES reports_sys(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  data_base64 TEXT NOT NULL,
  size_bytes INTEGER NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS reports_sys_actions (
  id SERIAL PRIMARY KEY,
  report_id INTEGER NOT NULL REFERENCES reports_sys(id) ON DELETE CASCADE,
  actor_user_id INTEGER NOT NULL REFERENCES users(id),
  actor_user_name TEXT NOT NULL,
  action TEXT NOT NULL,
  comment TEXT,
  from_user_id INTEGER,
  to_user_id INTEGER,
  to_user_name TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_reports_sys_assignee_status
  ON reports_sys (current_assignee_user_id, status);

CREATE INDEX IF NOT EXISTS idx_reports_sys_creator
  ON reports_sys (created_by_user_id, status);

ALTER TABLE reports_sys ADD COLUMN IF NOT EXISTS project_id INTEGER REFERENCES projects(id);
ALTER TABLE reports_sys ADD COLUMN IF NOT EXISTS project_name TEXT NOT NULL DEFAULT '';
