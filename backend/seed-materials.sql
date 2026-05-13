-- =============================================================================
-- الخامات المعتمدة في التطبيق (سبعة أسماء فقط).
-- شغّل مرة واحدة على قاعدة البيانات؛ لا يُضاف اسم إذا كان موجوداً مسبقاً.
-- =============================================================================

INSERT INTO materials (name)
SELECT t.name FROM unnest(ARRAY[
  'WPC - WG - P06 - RHW 15*5 cm - L= 2.5m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1.4m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 3.7m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1m',
  'Steel box 30x30x3 mm lengh 2.45',
  'Steel C-Channel 135*50*30*2 mm length 0.035',
  'Steel box 30x30x3 mm length 3.65'
]) AS t(name)
WHERE NOT EXISTS (SELECT 1 FROM materials m WHERE m.name = t.name);
