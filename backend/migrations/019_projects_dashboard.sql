-- Projects Dashboard: شيت Excel واحد + ملاحظات المكتب الفني ومدير العمليات

CREATE TABLE IF NOT EXISTS projects_dashboard_sheet (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  file_name TEXT NOT NULL,
  file_mime TEXT NOT NULL DEFAULT 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  file_data TEXT NOT NULL,
  rows_json TEXT NOT NULL DEFAULT '{"sheetName":"Sheet1","rows":[[""]]}',
  uploaded_by_user_id INTEGER NOT NULL REFERENCES users(id),
  uploaded_by_user_name TEXT NOT NULL,
  updated_by_user_id INTEGER REFERENCES users(id),
  updated_by_user_name TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS projects_dashboard_notes (
  id SERIAL PRIMARY KEY,
  author_role TEXT NOT NULL CHECK (author_role IN ('technical_office', 'operation_manager')),
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_projects_dashboard_notes_role_created
  ON projects_dashboard_notes (author_role, created_at DESC);
