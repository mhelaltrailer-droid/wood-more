-- IR / MIR uploads (site engineers attach; managers view)
CREATE TABLE IF NOT EXISTS ir_mir_uploads (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('mir', 'ir')),
  mir_name TEXT,
  location_id INTEGER REFERENCES project_locations(id) ON DELETE CASCADE,
  phase TEXT,
  file_name TEXT NOT NULL,
  file_mime TEXT NOT NULL,
  file_data TEXT NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ir_mir_project_kind ON ir_mir_uploads(project_id, kind);
CREATE INDEX IF NOT EXISTS idx_ir_mir_location_phase ON ir_mir_uploads(location_id, phase);
