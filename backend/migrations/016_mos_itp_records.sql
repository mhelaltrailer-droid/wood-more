-- MoS-ITP: سجلات Method of Statement و Inspection and Test Plan
CREATE TABLE IF NOT EXISTS mos_itp_records (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('mos', 'itp')),
  record_name TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS mos_itp_attachments (
  id SERIAL PRIMARY KEY,
  record_id INTEGER NOT NULL REFERENCES mos_itp_records(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_mime TEXT NOT NULL,
  file_data TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_mos_itp_records_project_kind ON mos_itp_records(project_id, kind);
CREATE INDEX IF NOT EXISTS idx_mos_itp_attachments_record_id ON mos_itp_attachments(record_id);
