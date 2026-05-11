-- مواقع عمل Shed01 و Shed02 تحت كل فيلا في مشروع Cairo gate_ACC_W
INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT v.project_id, v.id, w.name, 'work_site', w.display_order
FROM project_locations v
INNER JOIN projects p ON p.id = v.project_id
CROSS JOIN (
  VALUES
    ('Shed01', 1),
    ('Shed02', 2)
) AS w(name, display_order)
WHERE p.name = 'Cairo gate_ACC_W'
  AND v.parent_id IS NULL
  AND v.type = 'folder'
  AND v.name IN (
    'Villa 1', 'Villa 2', 'Villa 3', 'Villa 4', 'Villa 5', 'Villa 6', 'Villa 7',
    'Villa 70', 'Villa 71', 'Villa 76', 'Villa 77', 'Villa 78', 'Villa 82', 'Villa 83'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM project_locations child
    WHERE child.parent_id = v.id AND child.name = w.name
  );
