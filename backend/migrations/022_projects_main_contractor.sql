-- Main Contractor على المشاريع + تسلسل رقم طلب أذن الصرف/التسليم
ALTER TABLE projects ADD COLUMN IF NOT EXISTS main_contractor TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS disbursement_note_seq (
  id SERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
