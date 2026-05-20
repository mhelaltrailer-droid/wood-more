/**
 * Reads DDD.xlsx sheet "Z1_EMAAR_F" and writes seed_z1_emaar_f_project_locations.sql
 *
 * One-time setup: cd backend && npm install xlsx
 * Usage: node scripts/generate_z1_emaar_locations_sql.js [path/to/DDD.xlsx]
 */
const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

const defaultXlsx = path.join('C:', 'Users', 'home', 'Downloads', 'DDD.xlsx');
const xlsxPath = process.argv[2] || defaultXlsx;
const outSql = path.join(__dirname, 'seed_z1_emaar_f_project_locations.sql');

function esc(s) {
  return String(s).replace(/'/g, "''");
}

function parseSheet() {
  const wb = XLSX.readFile(xlsxPath);
  const sh = wb.Sheets['Z1_EMAAR_F'];
  if (!sh) throw new Error('Sheet Z1_EMAAR_F not found');
  const rows = XLSX.utils.sheet_to_json(sh, { header: 1, defval: '' });

  let folder = '';
  const folderOrderMap = {};
  let folderSeq = 0;
  /** @type {{folder:string, work:string, folderOrder:number, workOrder:number}[]} */
  const pairs = [];
  const workOrderByFolder = {};

  for (let i = 0; i < rows.length; i++) {
    const b = String(rows[i][1] ?? '').trim();
    const c = String(rows[i][2] ?? '').trim();
    if (!b && !c) continue;
    if (b.includes('موقع فرعي')) continue;

    if (b) {
      folder = b;
      if (folderOrderMap[folder] === undefined) {
        folderOrderMap[folder] = ++folderSeq;
      }
    }
    if (!folder || !c) continue;
    if (workOrderByFolder[folder] === undefined) workOrderByFolder[folder] = 0;
    const workOrder = ++workOrderByFolder[folder];
    pairs.push({
      folder,
      work: c,
      folderOrder: folderOrderMap[folder],
      workOrder,
    });
  }

  const folderNames = Object.keys(folderOrderMap).sort(
    (a, b) => folderOrderMap[a] - folderOrderMap[b],
  );
  return { folderNames, folderOrderMap, pairs };
}

function sqlValuesFolder(folderOrderMap) {
  const names = Object.keys(folderOrderMap).sort(
    (a, b) => folderOrderMap[a] - folderOrderMap[b],
  );
  return names.map((n) => `    ('${esc(n)}', ${folderOrderMap[n]})`).join(',\n');
}

function sqlWorkBlocks(pairs, folderNames) {
  const byFolder = {};
  for (const f of folderNames) byFolder[f] = [];
  for (const p of pairs) byFolder[p.folder].push(p);

  let sql = '';
  for (const folder of folderNames) {
    const works = byFolder[folder];
    const valueRows = works
      .map((p) => `    ('${esc(p.work)}', ${p.workOrder})`)
      .join(',\n');
    sql += `
INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, pl.id, w.name, 'work_site', w.display_order
FROM projects p
INNER JOIN project_locations pl
  ON pl.project_id = p.id
  AND pl.parent_id IS NULL
  AND pl.type = 'folder'
  AND pl.name = '${esc(folder)}'
CROSS JOIN (
  VALUES
${valueRows}
) AS w(name, display_order)
WHERE p.name = 'Z1_EMAAR_F'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations ex
  WHERE ex.project_id = p.id
    AND ex.parent_id = pl.id
    AND ex.name = w.name
);
`;
  }
  return sql;
}

function main() {
  const { folderNames, folderOrderMap, pairs } = parseSheet();

  const header = `-- هيكل مواقع مشروع Z1_EMAAR_F (من DDD.xlsx — ورقة Z1_EMAAR_F)
-- موقع فرعي = folder | موقع عمل = work_site
-- يتطلب وجود المشروع: SELECT id FROM projects WHERE name = 'Z1_EMAAR_F';
-- آمن لإعادة التشغيل: لا يُدرج صف مكرر لنفس الاسم تحت نفس الأب.

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, NULL, v.name, 'folder', v.display_order
FROM projects p
CROSS JOIN (
  VALUES
${sqlValuesFolder(folderOrderMap)}
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
`;

  const body = sqlWorkBlocks(pairs, folderNames);
  fs.writeFileSync(outSql, header + body + '\n', 'utf8');
  console.log('Wrote', outSql);
  console.log('Folders:', folderNames.length, 'Work sites:', pairs.length);
}

main();
