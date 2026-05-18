-- ============================================================
-- خامات WPC/ALU لـ Terrace Zayed + أرصدة مخزن المشروع (قطعة)
-- المشروع في البذور: Terrace Zayed_CRC_W
-- يمكن تشغيل الملف أكثر من مرة بأمان (حذف ثم إدراج لنفس الخامات)
-- ============================================================

INSERT INTO materials (name)
SELECT t.name FROM unnest(ARRAY[
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 3 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.9 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.7 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.4 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.3 m',
  'ALU - KEEL - 40*20 - L= 6 m',
  'ALU - Shadow gap - ETR11 - 21*10 - L= 6 m',
  'ALU - Profile - ETR12 - 40*41 - L= 6 m'
]) AS t(name)
WHERE NOT EXISTS (SELECT 1 FROM materials m WHERE m.name = t.name);

DO $$
DECLARE
  pid INTEGER;
BEGIN
  SELECT id INTO pid FROM projects WHERE name = 'Terrace Zayed_CRC_W' LIMIT 1;
  IF pid IS NULL THEN
    RAISE NOTICE '012_terrace_zayed: لم يُعثر على المشروع Terrace Zayed_CRC_W — تم تخطي أرصدة المخزن (أضف المشروع أو عدّل الاسم في الاستعلام)';
    RETURN;
  END IF;

  DELETE FROM project_stock
  WHERE project_id = pid
    AND material_name IN (
      'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 3 m',
      'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.9 m',
      'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.7 m',
      'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.4 m',
      'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.3 m',
      'ALU - KEEL - 40*20 - L= 6 m',
      'ALU - Shadow gap - ETR11 - 21*10 - L= 6 m',
      'ALU - Profile - ETR12 - 40*41 - L= 6 m'
    );

  INSERT INTO project_stock (project_id, material_name, quantity, unit) VALUES
    (pid, 'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 3 m', '5669', 'قطعة'),
    (pid, 'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.9 m', '1660', 'قطعة'),
    (pid, 'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.7 m', '69', 'قطعة'),
    (pid, 'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.4 m', '676', 'قطعة'),
    (pid, 'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.3 m', '2270', 'قطعة'),
    (pid, 'ALU - KEEL - 40*20 - L= 6 m', '1322', 'قطعة'),
    (pid, 'ALU - Shadow gap - ETR11 - 21*10 - L= 6 m', '600', 'قطعة'),
    (pid, 'ALU - Profile - ETR12 - 40*41 - L= 6 m', '1432', 'قطعة');
END $$;
