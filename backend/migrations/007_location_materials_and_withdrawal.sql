-- ============================================================
-- هيكلة المخازن: خامات لكل موقع فرعي + سجل السحب (مرة واحدة لكل موقع)
-- الاستخدام: شغّل هذا الملف في SQL Editor بقاعدة wood_more
-- ============================================================

-- خامات مخصصة لكل موقع فرعي (project_locations) — تظهر لمهندس الموقع للسحب
CREATE TABLE IF NOT EXISTS location_materials (
  id SERIAL PRIMARY KEY,
  location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
  material_name TEXT NOT NULL,
  quantity TEXT NOT NULL,
  unit TEXT NOT NULL DEFAULT ''
);

-- سجل سحب الخامات لكل موقع (مرة واحدة فقط لكل location)
CREATE TABLE IF NOT EXISTS location_withdrawal (
  id SERIAL PRIMARY KEY,
  location_id INTEGER NOT NULL UNIQUE REFERENCES project_locations(id) ON DELETE CASCADE,
  user_id INTEGER NOT NULL REFERENCES users(id),
  user_name TEXT NOT NULL,
  created_at TEXT NOT NULL,
  disbursement_permit_images_json TEXT,
  delivery_permit_images_json TEXT
);

CREATE INDEX IF NOT EXISTS idx_location_materials_location_id ON location_materials(location_id);
CREATE INDEX IF NOT EXISTS idx_location_withdrawal_location_id ON location_withdrawal(location_id);
