-- هيكل مواقع مشروع Z1_EMAAR_F (من DDD.xlsx — ورقة Z1_EMAAR_F)
-- موقع فرعي = folder | موقع عمل = work_site
-- يتطلب وجود المشروع: SELECT id FROM projects WHERE name = 'Z1_EMAAR_F';
-- آمن لإعادة التشغيل: لا يُدرج صف مكرر لنفس الاسم تحت نفس الأب.

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, NULL, v.name, 'folder', v.display_order
FROM projects p
CROSS JOIN (
  VALUES
    ('V02', 1),
    ('V02 FL', 2),
    ('V06B OR G', 3),
    ('V06-TH-A', 4),
    ('V06-TH-B', 5),
    ('V016', 6),
    ('V016 P', 7),
    ('V018B-F1', 8),
    ('V018B-F2', 9),
    ('V018 P', 10)
) AS v(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations pl
  WHERE pl.project_id = p.id
    AND pl.parent_id IS NULL
    AND pl.name = v.name
    AND pl.type = 'folder'
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V02'
CROSS JOIN (
  VALUES
    ('Villa 40', 1),
    ('Villa 41', 2),
    ('Villa 43', 3),
    ('Villa 45', 4),
    ('Villa 46', 5),
    ('Villa 47', 6),
    ('Villa 69', 7)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V02 FL'
CROSS JOIN (
  VALUES
    ('Villa 39', 1),
    ('Villa 42', 2),
    ('Villa 44', 3),
    ('Villa 48', 4),
    ('Villa 68', 5)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V06B OR G'
CROSS JOIN (
  VALUES
    ('Villa 2', 1),
    ('Villa 3', 2),
    ('Villa 5', 3),
    ('Villa 8', 4),
    ('Villa 10', 5),
    ('Villa 11', 6),
    ('Villa 12', 7),
    ('Villa 14', 8),
    ('Villa 19', 9),
    ('Villa 21', 10),
    ('Villa 23', 11),
    ('Villa 25', 12),
    ('Villa 26', 13),
    ('Villa 29', 14),
    ('Villa 30', 15),
    ('Villa 31', 16),
    ('Villa 32', 17),
    ('Villa 33', 18),
    ('Villa 36', 19),
    ('Villa 37', 20),
    ('Villa 78', 21),
    ('Villa 80', 22),
    ('Villa 81', 23),
    ('Villa 82', 24),
    ('Villa 84', 25),
    ('Villa 86', 26),
    ('Villa 88', 27),
    ('Villa 101', 28),
    ('Villa 103', 29),
    ('Villa 105', 30),
    ('Villa 107', 31),
    ('Villa 109', 32),
    ('Villa 112', 33)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V06-TH-A'
CROSS JOIN (
  VALUES
    ('Villa 94 A', 1),
    ('Villa 94 B', 2),
    ('Villa 94 C', 3),
    ('Villa 94 D', 4),
    ('Villa 96 A', 5),
    ('Villa 96 B', 6),
    ('Villa 96 C', 7),
    ('Villa 96 D', 8),
    ('Villa 116 A', 9),
    ('Villa 116 B', 10),
    ('Villa 116 C', 11),
    ('Villa 116 D', 12),
    ('Villa 119 A', 13),
    ('Villa 119 B', 14),
    ('Villa 119 C', 15),
    ('Villa 119 D', 16),
    ('Villa 120 A', 17),
    ('Villa 120 B', 18),
    ('Villa 120 C', 19),
    ('Villa 120 D', 20),
    ('Villa 123 A', 21),
    ('Villa 123 B', 22),
    ('Villa 123 C', 23),
    ('Villa 123 D', 24),
    ('Villa 125 A', 25),
    ('Villa 125 B', 26),
    ('Villa 125 C', 27),
    ('Villa 125 D', 28),
    ('Villa 127 A', 29),
    ('Villa 127 B', 30),
    ('Villa 127 C', 31),
    ('Villa 127 D', 32),
    ('Villa 130 A', 33),
    ('Villa 130 B', 34),
    ('Villa 130 C', 35),
    ('Villa 130 D', 36),
    ('Villa 133 A', 37),
    ('Villa 133 B', 38),
    ('Villa 133 C', 39),
    ('Villa 133 D', 40),
    ('Villa 134 A', 41),
    ('Villa 134 B', 42),
    ('Villa 134 C', 43),
    ('Villa 134 D', 44),
    ('Villa 136 A', 45),
    ('Villa 136 B', 46),
    ('Villa 136 C', 47),
    ('Villa 136 D', 48),
    ('Villa 138 A', 49),
    ('Villa 138 B', 50),
    ('Villa 138 C', 51),
    ('Villa 138 D', 52),
    ('Villa 140 A', 53),
    ('Villa 140 B', 54),
    ('Villa 140 C', 55),
    ('Villa 140 D', 56)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V06-TH-B'
CROSS JOIN (
  VALUES
    ('Villa 95 A', 1),
    ('Villa 95 B', 2),
    ('Villa 95 C', 3),
    ('Villa 95 D', 4),
    ('Villa 117 A', 5),
    ('Villa 117 B', 6),
    ('Villa 117 C', 7),
    ('Villa 117 D', 8),
    ('Villa 118 A', 9),
    ('Villa 118 B', 10),
    ('Villa 118 C', 11),
    ('Villa 118 D', 12),
    ('Villa 121 A', 13),
    ('Villa 121 B', 14),
    ('Villa 121 C', 15),
    ('Villa 121 D', 16),
    ('Villa 122 A', 17),
    ('Villa 122 B', 18),
    ('Villa 122 C', 19),
    ('Villa 122 D', 20),
    ('Villa 124 A', 21),
    ('Villa 124 B', 22),
    ('Villa 124 C', 23),
    ('Villa 124 D', 24),
    ('Villa 126 A', 25),
    ('Villa 126 B', 26),
    ('Villa 126 C', 27),
    ('Villa 126 D', 28),
    ('Villa 128 A', 29),
    ('Villa 128 B', 30),
    ('Villa 128 C', 31),
    ('Villa 128 D', 32),
    ('Villa 129 A', 33),
    ('Villa 129 B', 34),
    ('Villa 129 C', 35),
    ('Villa 129 D', 36),
    ('Villa 131 A', 37),
    ('Villa 131 B', 38),
    ('Villa 131 C', 39),
    ('Villa 131 D', 40),
    ('Villa 132 A', 41),
    ('Villa 132 B', 42),
    ('Villa 132 C', 43),
    ('Villa 132 D', 44),
    ('Villa 135 A', 45),
    ('Villa 135 B', 46),
    ('Villa 135 C', 47),
    ('Villa 135 D', 48),
    ('Villa 137 A', 49),
    ('Villa 137 B', 50),
    ('Villa 137 C', 51),
    ('Villa 137 D', 52),
    ('Villa 139 A', 53),
    ('Villa 139 B', 54),
    ('Villa 139 C', 55),
    ('Villa 139 D', 56)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V016'
CROSS JOIN (
  VALUES
    ('Villa 6', 1),
    ('Villa 7', 2),
    ('Villa 9', 3),
    ('Villa 17', 4),
    ('Villa 18', 5),
    ('Villa 20', 6),
    ('Villa 22', 7),
    ('Villa 24', 8),
    ('Villa 27', 9),
    ('Villa 28', 10),
    ('Villa 34', 11),
    ('Villa 35', 12),
    ('Villa 38', 13)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V016 P'
CROSS JOIN (
  VALUES
    ('Villa 1', 1),
    ('Villa 4', 2),
    ('Villa 13', 3),
    ('Villa 15', 4),
    ('Villa 16', 5),
    ('Villa 51', 6),
    ('Villa 72', 7),
    ('Villa 79', 8),
    ('Villa 83', 9),
    ('Villa 85', 10),
    ('Villa 87', 11),
    ('Villa 97', 12),
    ('Villa 102', 13),
    ('Villa 104', 14),
    ('Villa 106', 15),
    ('Villa 108', 16),
    ('Villa 110', 17),
    ('Villa 113', 18),
    ('Villa 115', 19)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V018B-F1'
CROSS JOIN (
  VALUES
    ('Villa 56', 1),
    ('Villa 57', 2),
    ('Villa 58', 3),
    ('Villa 59', 4),
    ('Villa 64', 5),
    ('Villa 67', 6),
    ('Villa 73', 7),
    ('Villa 75', 8)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V018B-F2'
CROSS JOIN (
  VALUES
    ('Villa 54', 1),
    ('Villa 55', 2),
    ('Villa 60', 3),
    ('Villa 61', 4),
    ('Villa 62', 5),
    ('Villa 63', 6),
    ('Villa 66', 7),
    ('Villa 74', 8)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = 'V018 P'
CROSS JOIN (
  VALUES
    ('Villa 49', 1),
    ('Villa 50', 2),
    ('Villa 52', 3),
    ('Villa 53', 4),
    ('Villa 65', 5),
    ('Villa 71', 6),
    ('Villa 76', 7),
    ('Villa 77', 8),
    ('Villa 89', 9),
    ('Villa 90', 10),
    ('Villa 91', 11),
    ('Villa 92', 12),
    ('Villa 93', 13),
    ('Villa 98', 14),
    ('Villa 99', 15),
    ('Villa 100', 16),
    ('Villa 111', 17),
    ('Villa 114', 18)
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);

