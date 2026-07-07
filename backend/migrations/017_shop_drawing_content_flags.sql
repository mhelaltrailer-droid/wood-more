-- محتوى المرفقات: SD / QS / Dashboard (مكتب فني Shop-Drawing & PO)
ALTER TABLE shop_drawings
  ADD COLUMN IF NOT EXISTS content_sd BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE shop_drawings
  ADD COLUMN IF NOT EXISTS content_qs BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE shop_drawings
  ADD COLUMN IF NOT EXISTS content_dashboard BOOLEAN NOT NULL DEFAULT FALSE;
