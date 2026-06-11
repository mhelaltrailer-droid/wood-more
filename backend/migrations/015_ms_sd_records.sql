-- MS-SD: سجلات Material Submittal و Shop Drawing (Document Controller)
CREATE TABLE IF NOT EXISTS ms_sd_records (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('ms', 'sd')),
  record_name TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ms_sd_attachments (
  id SERIAL PRIMARY KEY,
  record_id INTEGER NOT NULL REFERENCES ms_sd_records(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_mime TEXT NOT NULL,
  file_data TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ms_sd_records_project_kind ON ms_sd_records(project_id, kind);
CREATE INDEX IF NOT EXISTS idx_ms_sd_attachments_record_id ON ms_sd_attachments(record_id);
