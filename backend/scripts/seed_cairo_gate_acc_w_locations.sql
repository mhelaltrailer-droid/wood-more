-- مواقع فرعية لمشروع Cairo gate_ACC_W
INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, NULL, v.name, 'folder', v.display_order
FROM projects p
CROSS JOIN (
  VALUES
    ('Villa 1', 1),
    ('Villa 2', 2),
    ('Villa 3', 3),
    ('Villa 4', 4),
    ('Villa 5', 5),
    ('Villa 6', 6),
    ('Villa 7', 7),
    ('Villa 70', 8),
    ('Villa 71', 9),
    ('Villa 76', 10),
    ('Villa 77', 11),
    ('Villa 78', 12),
    ('Villa 82', 13),
    ('Villa 83', 14)
) AS v(name, display_order)
WHERE p.name = 'Cairo gate_ACC_W'
  AND NOT EXISTS (
    SELECT 1
    FROM project_locations pl
    WHERE pl.project_id = p.id AND pl.name = v.name
  );
