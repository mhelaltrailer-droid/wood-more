-- =============================================================================
-- الخامات المعتمدة في التطبيق (مع خامات Terrace Zayed في الأعلى).
-- شغّل على قاعدة البيانات؛ لا يُضاف اسم إذا كان موجوداً مسبقاً.
-- =============================================================================

INSERT INTO materials (name)
SELECT t.name FROM unnest(ARRAY[
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 3 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.9 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.7 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.4 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.3 m',
  'ALU - KEEL - 40*20 - L= 6 m',
  'ALU - Shadow gap - ETR11 - 21*10 - L= 6 m',
  'ALU - Profile - ETR12 - 40*41 - L= 6 m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 2.5m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1.4m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 3.7m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1m',
  'Steel box 30x30x3 mm lengh 2.45',
  'Steel C-Channel 135*50*30*2 mm length 0.035',
  'Steel box 30x30x3 mm length 3.65'
]) AS t(name)
WHERE NOT EXISTS (SELECT 1 FROM materials m WHERE m.name = t.name);
