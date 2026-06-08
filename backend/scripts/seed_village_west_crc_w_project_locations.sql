-- Village West _ CRC_ W (15) — project_id 60
-- Level1: 14, Level2: 42, Work sites: 123

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT 60, NULL, v.name, 'folder', v.ord
FROM (VALUES
  ('T01-101', 1),
  ('T02-102', 2),
  ('T03-107', 3),
  ('T03-108', 4),
  ('T03-109', 5),
  ('T03-110', 6),
  ('T04-104', 7),
  ('T04-106', 8),
  ('T04-112', 9),
  ('T04-114', 10),
  ('T05-103', 11),
  ('T05-105', 12),
  ('T05-111', 13),
  ('T05-113', 14)
) AS v(name, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = 60 AND pl.parent_id IS NULL AND pl.name = v.name AND pl.type = 'folder'
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT 60, tower_pl.id, v.type_name, 'folder', v.ord
FROM (VALUES
  ('T01-101', 'TYPE 01', 1),
  ('T01-101', 'TYPE 02', 2),
  ('T01-101', 'TYPE 03', 3),
  ('T02-102', 'TYPE 01', 1),
  ('T02-102', 'TYPE 02', 2),
  ('T02-102', 'TYPE 03', 3),
  ('T03-107', 'TYPE 01', 1),
  ('T03-107', 'TYPE 02', 2),
  ('T03-107', 'TYPE 03', 3),
  ('T03-108', 'TYPE 01', 1),
  ('T03-108', 'TYPE 02', 2),
  ('T03-108', 'TYPE 03', 3),
  ('T03-109', 'TYPE 01', 1),
  ('T03-109', 'TYPE 02', 2),
  ('T03-109', 'TYPE 03', 3),
  ('T03-110', 'TYPE 01', 1),
  ('T03-110', 'TYPE 02', 2),
  ('T03-110', 'TYPE 03', 3),
  ('T04-104', 'TYPE 01', 1),
  ('T04-104', 'TYPE 02', 2),
  ('T04-104', 'TYPE 03', 3),
  ('T04-106', 'TYPE 01', 1),
  ('T04-106', 'TYPE 02', 2),
  ('T04-106', 'TYPE 03', 3),
  ('T04-112', 'TYPE 01', 1),
  ('T04-112', 'TYPE 02', 2),
  ('T04-112', 'TYPE 03', 3),
  ('T04-114', 'TYPE 01', 1),
  ('T04-114', 'TYPE 02', 2),
  ('T04-114', 'TYPE 03', 3),
  ('T05-103', 'TYPE 01', 1),
  ('T05-103', 'TYPE 02', 2),
  ('T05-103', 'TYPE 03', 3),
  ('T05-105', 'TYPE 01', 1),
  ('T05-105', 'TYPE 02', 2),
  ('T05-105', 'TYPE 03', 3),
  ('T05-111', 'TYPE 01', 1),
  ('T05-111', 'TYPE 02', 2),
  ('T05-111', 'TYPE 03', 3),
  ('T05-113', 'TYPE 01', 1),
  ('T05-113', 'TYPE 02', 2),
  ('T05-113', 'TYPE 03', 3)
) AS v(tower, type_name, ord)
JOIN project_locations tower_pl
  ON tower_pl.project_id = 60
 AND tower_pl.parent_id IS NULL
 AND tower_pl.name = v.tower
 AND tower_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = 60
    AND pl.parent_id = tower_pl.id
    AND pl.name = v.type_name
    AND pl.type = 'folder'
);

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT 60, type_pl.id, v.model_name, 'work_site', v.ord
FROM (VALUES
  ('T01-101', 'TYPE 01', 'MODEL 01', 1),
  ('T01-101', 'TYPE 01', 'MODEL 02', 2),
  ('T01-101', 'TYPE 01', 'MODEL 03', 3),
  ('T01-101', 'TYPE 01', 'MODEL 04', 4),
  ('T01-101', 'TYPE 02', 'MODEL 01', 1),
  ('T01-101', 'TYPE 02', 'MODEL 02', 2),
  ('T01-101', 'TYPE 02', 'MODEL 03', 3),
  ('T01-101', 'TYPE 03', 'MODEL 01', 1),
  ('T01-101', 'TYPE 03', 'MODEL 03', 2),
  ('T02-102', 'TYPE 01', 'MODEL 01', 1),
  ('T02-102', 'TYPE 01', 'MODEL 02', 2),
  ('T02-102', 'TYPE 01', 'MODEL 03', 3),
  ('T02-102', 'TYPE 01', 'MODEL 04', 4),
  ('T02-102', 'TYPE 02', 'MODEL 01', 1),
  ('T02-102', 'TYPE 02', 'MODEL 02', 2),
  ('T02-102', 'TYPE 02', 'MODEL 03', 3),
  ('T02-102', 'TYPE 03', 'MODEL 01', 1),
  ('T02-102', 'TYPE 03', 'MODEL 02', 2),
  ('T02-102', 'TYPE 03', 'MODEL 03', 3),
  ('T03-107', 'TYPE 01', 'MODEL 01', 1),
  ('T03-107', 'TYPE 01', 'MODEL 02', 2),
  ('T03-107', 'TYPE 01', 'MODEL 03', 3),
  ('T03-107', 'TYPE 01', 'MODEL 04', 4),
  ('T03-107', 'TYPE 02', 'MODEL 04', 1),
  ('T03-107', 'TYPE 02', 'MODEL 05', 2),
  ('T03-107', 'TYPE 02', 'MODEL 06', 3),
  ('T03-107', 'TYPE 03', 'MODEL 01', 1),
  ('T03-107', 'TYPE 03', 'MODEL 02', 2),
  ('T03-107', 'TYPE 03', 'MODEL 03', 3),
  ('T03-108', 'TYPE 01', 'MODEL 01', 1),
  ('T03-108', 'TYPE 01', 'MODEL 02', 2),
  ('T03-108', 'TYPE 01', 'MODEL 03', 3),
  ('T03-108', 'TYPE 01', 'MODEL 04', 4),
  ('T03-108', 'TYPE 02', 'MODEL 04', 1),
  ('T03-108', 'TYPE 02', 'MODEL 05', 2),
  ('T03-108', 'TYPE 02', 'MODEL 06', 3),
  ('T03-108', 'TYPE 03', 'MODEL 01', 1),
  ('T03-108', 'TYPE 03', 'MODEL 02', 2),
  ('T03-108', 'TYPE 03', 'MODEL 03', 3),
  ('T03-109', 'TYPE 01', 'MODEL 01', 1),
  ('T03-109', 'TYPE 01', 'MODEL 02', 2),
  ('T03-109', 'TYPE 01', 'MODEL 03', 3),
  ('T03-109', 'TYPE 01', 'MODEL 04', 4),
  ('T03-109', 'TYPE 02', 'MODEL 04', 1),
  ('T03-109', 'TYPE 02', 'MODEL 05', 2),
  ('T03-109', 'TYPE 02', 'MODEL 06', 3),
  ('T03-109', 'TYPE 03', 'MODEL 01', 1),
  ('T03-109', 'TYPE 03', 'MODEL 02', 2),
  ('T03-109', 'TYPE 03', 'MODEL 03', 3),
  ('T03-110', 'TYPE 01', 'MODEL 01', 1),
  ('T03-110', 'TYPE 01', 'MODEL 02', 2),
  ('T03-110', 'TYPE 01', 'MODEL 03', 3),
  ('T03-110', 'TYPE 01', 'MODEL 04', 4),
  ('T03-110', 'TYPE 02', 'MODEL 04', 1),
  ('T03-110', 'TYPE 02', 'MODEL 05', 2),
  ('T03-110', 'TYPE 02', 'MODEL 06', 3),
  ('T03-110', 'TYPE 03', 'MODEL 01', 1),
  ('T03-110', 'TYPE 03', 'MODEL 02', 2),
  ('T03-110', 'TYPE 03', 'MODEL 03', 3),
  ('T04-104', 'TYPE 01', 'MODEL 01', 1),
  ('T04-104', 'TYPE 01', 'MODEL 02', 2),
  ('T04-104', 'TYPE 02', 'MODEL 01', 1),
  ('T04-104', 'TYPE 02', 'MODEL 02', 2),
  ('T04-104', 'TYPE 02', 'MODEL 03', 3),
  ('T04-104', 'TYPE 03', 'MODEL 01', 1),
  ('T04-104', 'TYPE 03', 'MODEL 02', 2),
  ('T04-104', 'TYPE 03', 'MODEL 03', 3),
  ('T04-106', 'TYPE 01', 'MODEL 01', 1),
  ('T04-106', 'TYPE 01', 'MODEL 02', 2),
  ('T04-106', 'TYPE 02', 'MODEL 01', 1),
  ('T04-106', 'TYPE 02', 'MODEL 02', 2),
  ('T04-106', 'TYPE 02', 'MODEL 03', 3),
  ('T04-106', 'TYPE 03', 'MODEL 01', 1),
  ('T04-106', 'TYPE 03', 'MODEL 02', 2),
  ('T04-106', 'TYPE 03', 'MODEL 03', 3),
  ('T04-112', 'TYPE 01', 'MODEL 01', 1),
  ('T04-112', 'TYPE 01', 'MODEL 02', 2),
  ('T04-112', 'TYPE 02', 'MODEL 01', 1),
  ('T04-112', 'TYPE 02', 'MODEL 02', 2),
  ('T04-112', 'TYPE 02', 'MODEL 03', 3),
  ('T04-112', 'TYPE 03', 'MODEL 01', 1),
  ('T04-112', 'TYPE 03', 'MODEL 02', 2),
  ('T04-112', 'TYPE 03', 'MODEL 03', 3),
  ('T04-114', 'TYPE 01', 'MODEL 01', 1),
  ('T04-114', 'TYPE 01', 'MODEL 02', 2),
  ('T04-114', 'TYPE 02', 'MODEL 01', 1),
  ('T04-114', 'TYPE 02', 'MODEL 02', 2),
  ('T04-114', 'TYPE 02', 'MODEL 03', 3),
  ('T04-114', 'TYPE 03', 'MODEL 01', 1),
  ('T04-114', 'TYPE 03', 'MODEL 02', 2),
  ('T04-114', 'TYPE 03', 'MODEL 03', 3),
  ('T05-103', 'TYPE 01', 'MODEL 01', 1),
  ('T05-103', 'TYPE 01', 'MODEL 02', 2),
  ('T05-103', 'TYPE 02', 'MODEL 01', 1),
  ('T05-103', 'TYPE 02', 'MODEL 02', 2),
  ('T05-103', 'TYPE 02', 'MODEL 03', 3),
  ('T05-103', 'TYPE 03', 'MODEL 01', 1),
  ('T05-103', 'TYPE 03', 'MODEL 02', 2),
  ('T05-103', 'TYPE 03', 'MODEL 03', 3),
  ('T05-105', 'TYPE 01', 'MODEL 01', 1),
  ('T05-105', 'TYPE 01', 'MODEL 02', 2),
  ('T05-105', 'TYPE 02', 'MODEL 01', 1),
  ('T05-105', 'TYPE 02', 'MODEL 02', 2),
  ('T05-105', 'TYPE 02', 'MODEL 03', 3),
  ('T05-105', 'TYPE 03', 'MODEL 01', 1),
  ('T05-105', 'TYPE 03', 'MODEL 02', 2),
  ('T05-105', 'TYPE 03', 'MODEL 03', 3),
  ('T05-111', 'TYPE 01', 'MODEL 01', 1),
  ('T05-111', 'TYPE 01', 'MODEL 02', 2),
  ('T05-111', 'TYPE 02', 'MODEL 01', 1),
  ('T05-111', 'TYPE 02', 'MODEL 02', 2),
  ('T05-111', 'TYPE 02', 'MODEL 03', 3),
  ('T05-111', 'TYPE 03', 'MODEL 01', 1),
  ('T05-111', 'TYPE 03', 'MODEL 02', 2),
  ('T05-111', 'TYPE 03', 'MODEL 03', 3),
  ('T05-113', 'TYPE 01', 'MODEL 01', 1),
  ('T05-113', 'TYPE 01', 'MODEL 02', 2),
  ('T05-113', 'TYPE 02', 'MODEL 01', 1),
  ('T05-113', 'TYPE 02', 'MODEL 02', 2),
  ('T05-113', 'TYPE 02', 'MODEL 03', 3),
  ('T05-113', 'TYPE 03', 'MODEL 01', 1),
  ('T05-113', 'TYPE 03', 'MODEL 02', 2),
  ('T05-113', 'TYPE 03', 'MODEL 03', 3)
) AS v(tower, type_name, model_name, ord)
JOIN project_locations tower_pl
  ON tower_pl.project_id = 60
 AND tower_pl.parent_id IS NULL
 AND tower_pl.name = v.tower
 AND tower_pl.type = 'folder'
JOIN project_locations type_pl
  ON type_pl.parent_id = tower_pl.id
 AND type_pl.name = v.type_name
 AND type_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = 60
    AND pl.parent_id = type_pl.id
    AND pl.name = v.model_name
    AND pl.type = 'work_site'
);
