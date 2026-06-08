const fs = require('fs');
const path = require('path');

const projectId = 60;
const towers = {};

towers['T01-101'] = {
  'TYPE 01': ['MODEL 01', 'MODEL 02', 'MODEL 03', 'MODEL 04'],
  'TYPE 02': ['MODEL 01', 'MODEL 02', 'MODEL 03'],
  'TYPE 03': ['MODEL 01', 'MODEL 03'],
};
towers['T02-102'] = {
  'TYPE 01': ['MODEL 01', 'MODEL 02', 'MODEL 03', 'MODEL 04'],
  'TYPE 02': ['MODEL 01', 'MODEL 02', 'MODEL 03'],
  'TYPE 03': ['MODEL 01', 'MODEL 02', 'MODEL 03'],
};

const t03 = ['T03-107', 'T03-108', 'T03-109', 'T03-110'];
const t03p = {
  'TYPE 01': ['MODEL 01', 'MODEL 02', 'MODEL 03', 'MODEL 04'],
  'TYPE 02': ['MODEL 04', 'MODEL 05', 'MODEL 06'],
  'TYPE 03': ['MODEL 01', 'MODEL 02', 'MODEL 03'],
};
for (const t of t03) towers[t] = JSON.parse(JSON.stringify(t03p));

const t04 = ['T04-104', 'T04-106', 'T04-112', 'T04-114'];
const t05 = ['T05-103', 'T05-105', 'T05-111', 'T05-113'];
const t45p = {
  'TYPE 01': ['MODEL 01', 'MODEL 02'],
  'TYPE 02': ['MODEL 01', 'MODEL 02', 'MODEL 03'],
  'TYPE 03': ['MODEL 01', 'MODEL 02', 'MODEL 03'],
};
for (const t of [...t04, ...t05]) towers[t] = JSON.parse(JSON.stringify(t45p));

const towerNames = Object.keys(towers);
const l1 = towerNames.map((n, i) => `('${n}', ${i + 1})`).join(',\n  ');
const l2rows = [];
for (const [tower] of Object.entries(towers)) {
  ['TYPE 01', 'TYPE 02', 'TYPE 03'].forEach((typeName, idx) => {
    l2rows.push(`('${tower}', '${typeName}', ${idx + 1})`);
  });
}
const wsrows = [];
for (const [tower, types] of Object.entries(towers)) {
  for (const [typeName, models] of Object.entries(types)) {
    models.forEach((m, idx) => {
      wsrows.push(`('${tower}', '${typeName}', '${m}', ${idx + 1})`);
    });
  }
}

const sql1 = `INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT ${projectId}, NULL, v.name, 'folder', v.ord
FROM (VALUES
  ${l1}
) AS v(name, ord)
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = ${projectId} AND pl.parent_id IS NULL AND pl.name = v.name AND pl.type = 'folder'
);`;

const sql2 = `INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT ${projectId}, tower_pl.id, v.type_name, 'folder', v.ord
FROM (VALUES
  ${l2rows.join(',\n  ')}
) AS v(tower, type_name, ord)
JOIN project_locations tower_pl
  ON tower_pl.project_id = ${projectId}
 AND tower_pl.parent_id IS NULL
 AND tower_pl.name = v.tower
 AND tower_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = ${projectId}
    AND pl.parent_id = tower_pl.id
    AND pl.name = v.type_name
    AND pl.type = 'folder'
);`;

const sql3 = `INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT ${projectId}, type_pl.id, v.model_name, 'work_site', v.ord
FROM (VALUES
  ${wsrows.join(',\n  ')}
) AS v(tower, type_name, model_name, ord)
JOIN project_locations tower_pl
  ON tower_pl.project_id = ${projectId}
 AND tower_pl.parent_id IS NULL
 AND tower_pl.name = v.tower
 AND tower_pl.type = 'folder'
JOIN project_locations type_pl
  ON type_pl.parent_id = tower_pl.id
 AND type_pl.name = v.type_name
 AND type_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = ${projectId}
    AND pl.parent_id = type_pl.id
    AND pl.name = v.model_name
    AND pl.type = 'work_site'
);`;

const outSql = path.join(__dirname, 'seed_village_west_crc_w_project_locations.sql');
fs.writeFileSync(
  outSql,
  `-- Village West _ CRC_ W (15) — project_id ${projectId}\n-- Level1: ${towerNames.length}, Level2: ${l2rows.length}, Work sites: ${wsrows.length}\n\n${sql1}\n\n${sql2}\n\n${sql3}\n`,
);
fs.writeFileSync(
  path.join(__dirname, '_vw_w_stmts.json'),
  JSON.stringify([sql1, sql2, sql3]),
);
console.log(JSON.stringify({ l1: towerNames.length, l2: l2rows.length, ws: wsrows.length }));
