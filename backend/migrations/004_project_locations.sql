-- جدول هيكل مواقع المشروع (مواقع فرعية folder / مواقع عمل work_site)
-- شغّله من Neon SQL Editor إذا كانت قاعدة البيانات موجودة مسبقاً ولم يُضف الجدول.

CREATE TABLE IF NOT EXISTS project_locations (
  id SERIAL PRIMARY KEY,
  project_id INTEGER NOT NULL REFERENCES projects(id),
  parent_id INTEGER REFERENCES project_locations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'folder' CHECK (type IN ('folder', 'work_site')),
  display_order INTEGER NOT NULL DEFAULT 0
);
