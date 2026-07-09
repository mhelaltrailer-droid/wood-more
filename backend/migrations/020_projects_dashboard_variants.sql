-- Projects Dashboard: separate sheet + notes per variant (webdav vs upload).

ALTER TABLE projects_dashboard_sheet
  DROP CONSTRAINT IF EXISTS projects_dashboard_sheet_id_check;

ALTER TABLE projects_dashboard_sheet
  ADD COLUMN IF NOT EXISTS variant TEXT NOT NULL DEFAULT 'webdav';

UPDATE projects_dashboard_sheet
SET variant = 'webdav'
WHERE variant IS NULL OR variant = '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_dashboard_sheet_variant
  ON projects_dashboard_sheet (variant);

ALTER TABLE projects_dashboard_notes
  ADD COLUMN IF NOT EXISTS variant TEXT NOT NULL DEFAULT 'webdav';

UPDATE projects_dashboard_notes
SET variant = 'webdav'
WHERE variant IS NULL OR variant = '';

CREATE INDEX IF NOT EXISTS idx_projects_dashboard_notes_variant_role_created
  ON projects_dashboard_notes (variant, author_role, created_at DESC);
