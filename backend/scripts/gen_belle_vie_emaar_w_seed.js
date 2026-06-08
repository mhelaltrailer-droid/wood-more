const fs = require('fs');
const path = require('path');

const projectId = 59;

const almaWorkSites = [
  'Type.01 Model.01 No.01',
  'Type.01 Model.01 No.02',
  'Type.02 Model.01 No.01',
  'Type.02 Model.01 No.02',
  'Type.02 Model.02 No.01',
  'Type.02 Model.02 No.02',
  'Type.03 Model.01 No.01',
  'Type.03 Model.01 No.02',
  'Type.03 Model.01 No.03',
  'Type.03 Model.01 No.04',
];

const fayaWorkSites = [
  'Model 01',
  'Model 02 No.01',
  'Model 02 No.02',
  'Model 03',
  'Model 04',
  'Model 05',
  'Model 06 No.01',
  'Model 06 No.02',
  'Model 07',
];

const cgWorkSites = [
  'Model 01',
  'Model 02',
  'Model 03',
  'Model 04',
  'Model 05 No.01',
  'Model 05 No.02',
  'Model 06 No.01',
  'Model 06 No.02',
];

/** zoneName -> buildingName -> work site names */
const tree = {
  'Alma-B': {
    'Building No.07': almaWorkSites,
    'Building No.04': almaWorkSites,
  },
  FAYA: {
    'Building No.02': fayaWorkSites,
    'Building No.09': fayaWorkSites,
  },
  'CAIRO GATE (CG)': {
    'Building No.03': cgWorkSites,
    'Building No.08': cgWorkSites,
  },
};

const zoneNames = Object.keys(tree);
const l1 = zoneNames.map((n, i) => `('${n.replace(/'/g, "''")}', ${i + 1})`).join(',\n  ');

const l2rows = [];
for (const [zone, buildings] of Object.entries(tree)) {
  Object.keys(buildings).forEach((building, idx) => {
    l2rows.push(`('${zone.replace(/'/g, "''")}', '${building.replace(/'/g, "''")}', ${idx + 1})`);
  });
}

const wsrows = [];
for (const [zone, buildings] of Object.entries(tree)) {
  for (const [building, models] of Object.entries(buildings)) {
    models.forEach((model, idx) => {
      wsrows.push(
        `('${zone.replace(/'/g, "''")}', '${building.replace(/'/g, "''")}', '${model.replace(/'/g, "''")}', ${idx + 1})`,
      );
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
SELECT ${projectId}, zone_pl.id, v.building_name, 'folder', v.ord
FROM (VALUES
  ${l2rows.join(',\n  ')}
) AS v(zone_name, building_name, ord)
JOIN project_locations zone_pl
  ON zone_pl.project_id = ${projectId}
 AND zone_pl.parent_id IS NULL
 AND zone_pl.name = v.zone_name
 AND zone_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = ${projectId}
    AND pl.parent_id = zone_pl.id
    AND pl.name = v.building_name
    AND pl.type = 'folder'
);`;

const sql3 = `INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT ${projectId}, building_pl.id, v.model_name, 'work_site', v.ord
FROM (VALUES
  ${wsrows.join(',\n  ')}
) AS v(zone_name, building_name, model_name, ord)
JOIN project_locations zone_pl
  ON zone_pl.project_id = ${projectId}
 AND zone_pl.parent_id IS NULL
 AND zone_pl.name = v.zone_name
 AND zone_pl.type = 'folder'
JOIN project_locations building_pl
  ON building_pl.parent_id = zone_pl.id
 AND building_pl.name = v.building_name
 AND building_pl.type = 'folder'
WHERE NOT EXISTS (
  SELECT 1 FROM project_locations pl
  WHERE pl.project_id = ${projectId}
    AND pl.parent_id = building_pl.id
    AND pl.name = v.model_name
    AND pl.type = 'work_site'
);`;

const outSql = path.join(__dirname, 'seed_belle_vie_emaar_w_project_locations.sql');
fs.writeFileSync(
  outSql,
  `-- Belle Vie _ EMAAR_W (3) — project_id ${projectId}\n-- Level1: ${zoneNames.length}, Level2: ${l2rows.length}, Work sites: ${wsrows.length}\n\n${sql1}\n\n${sql2}\n\n${sql3}\n`,
);
fs.writeFileSync(path.join(__dirname, '_belle_vie_stmts.json'), JSON.stringify([sql1, sql2, sql3]));
console.log(JSON.stringify({ l1: zoneNames.length, l2: l2rows.length, ws: wsrows.length }));
