-- ملاحظات مدير العمليات عند الاعتماد النهائي (SD & PO)
ALTER TABLE shop_drawings
  ADD COLUMN IF NOT EXISTS om_notes TEXT;
