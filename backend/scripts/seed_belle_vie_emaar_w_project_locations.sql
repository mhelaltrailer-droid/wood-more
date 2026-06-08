-- Belle Vie _ EMAAR_W (3) — project_id 59
-- Level1: 3, Level2: 6, Work sites: 54

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT 59, NULL, v.name, 'folder', v.ord
FROM (VALUES
  ('Alma-B', 1),
  ('FAYA', 2),
  ('CAIRO GATE (CG)', 3)
) AS v(name, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = 59 AND pl.parent_id IS NULL AND pl.name = v.name AND pl.type = 'folder'
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT 59, zone_pl.id, v.building_name, 'folder', v.ord
FROM (VALUES
  ('Alma-B', 'Building No.07', 1),
  ('Alma-B', 'Building No.04', 2),
  ('FAYA', 'Building No.02', 1),
  ('FAYA', 'Building No.09', 2),
  ('CAIRO GATE (CG)', 'Building No.03', 1),
  ('CAIRO GATE (CG)', 'Building No.08', 2)
) AS v(zone_name, building_name, ord)
JOIN project_locations zone_pl
  ON zone_pl.project_id = 59
 AND zone_pl.parent_id IS NULL
 AND zone_pl.name = v.zone_name
 AND zone_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = 59
    AND pl.parent_id = zone_pl.id
    AND pl.name = v.building_name
    AND pl.type = 'folder'
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT 59, building_pl.id, v.model_name, 'work_site', v.ord
FROM (VALUES
  ('Alma-B', 'Building No.07', 'Type.01 Model.01 No.01', 1),
  ('Alma-B', 'Building No.07', 'Type.01 Model.01 No.02', 2),
  ('Alma-B', 'Building No.07', 'Type.02 Model.01 No.01', 3),
  ('Alma-B', 'Building No.07', 'Type.02 Model.01 No.02', 4),
  ('Alma-B', 'Building No.07', 'Type.02 Model.02 No.01', 5),
  ('Alma-B', 'Building No.07', 'Type.02 Model.02 No.02', 6),
  ('Alma-B', 'Building No.07', 'Type.03 Model.01 No.01', 7),
  ('Alma-B', 'Building No.07', 'Type.03 Model.01 No.02', 8),
  ('Alma-B', 'Building No.07', 'Type.03 Model.01 No.03', 9),
  ('Alma-B', 'Building No.07', 'Type.03 Model.01 No.04', 10),
  ('Alma-B', 'Building No.04', 'Type.01 Model.01 No.01', 1),
  ('Alma-B', 'Building No.04', 'Type.01 Model.01 No.02', 2),
  ('Alma-B', 'Building No.04', 'Type.02 Model.01 No.01', 3),
  ('Alma-B', 'Building No.04', 'Type.02 Model.01 No.02', 4),
  ('Alma-B', 'Building No.04', 'Type.02 Model.02 No.01', 5),
  ('Alma-B', 'Building No.04', 'Type.02 Model.02 No.02', 6),
  ('Alma-B', 'Building No.04', 'Type.03 Model.01 No.01', 7),
  ('Alma-B', 'Building No.04', 'Type.03 Model.01 No.02', 8),
  ('Alma-B', 'Building No.04', 'Type.03 Model.01 No.03', 9),
  ('Alma-B', 'Building No.04', 'Type.03 Model.01 No.04', 10),
  ('FAYA', 'Building No.02', 'Model 01', 1),
  ('FAYA', 'Building No.02', 'Model 02 No.01', 2),
  ('FAYA', 'Building No.02', 'Model 02 No.02', 3),
  ('FAYA', 'Building No.02', 'Model 03', 4),
  ('FAYA', 'Building No.02', 'Model 04', 5),
  ('FAYA', 'Building No.02', 'Model 05', 6),
  ('FAYA', 'Building No.02', 'Model 06 No.01', 7),
  ('FAYA', 'Building No.02', 'Model 06 No.02', 8),
  ('FAYA', 'Building No.02', 'Model 07', 9),
  ('FAYA', 'Building No.09', 'Model 01', 1),
  ('FAYA', 'Building No.09', 'Model 02 No.01', 2),
  ('FAYA', 'Building No.09', 'Model 02 No.02', 3),
  ('FAYA', 'Building No.09', 'Model 03', 4),
  ('FAYA', 'Building No.09', 'Model 04', 5),
  ('FAYA', 'Building No.09', 'Model 05', 6),
  ('FAYA', 'Building No.09', 'Model 06 No.01', 7),
  ('FAYA', 'Building No.09', 'Model 06 No.02', 8),
  ('FAYA', 'Building No.09', 'Model 07', 9),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 01', 1),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 02', 2),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 03', 3),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 04', 4),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 05 No.01', 5),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 05 No.02', 6),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 06 No.01', 7),
  ('CAIRO GATE (CG)', 'Building No.03', 'Model 06 No.02', 8),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 01', 1),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 02', 2),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 03', 3),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 04', 4),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 05 No.01', 5),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 05 No.02', 6),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 06 No.01', 7),
  ('CAIRO GATE (CG)', 'Building No.08', 'Model 06 No.02', 8)
) AS v(zone_name, building_name, model_name, ord)
JOIN project_locations zone_pl
  ON zone_pl.project_id = 59
 AND zone_pl.parent_id IS NULL
 AND zone_pl.name = v.zone_name
 AND zone_pl.type = 'folder'
JOIN project_locations building_pl
  ON building_pl.parent_id = zone_pl.id
 AND building_pl.name = v.building_name
 AND building_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = 59
    AND pl.parent_id = building_pl.id
    AND pl.name = v.model_name
    AND pl.type = 'work_site'
);
