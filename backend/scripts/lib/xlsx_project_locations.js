/**
 * تحليل صفوف Excel (عمود B = موقع فرعي، C = موقع عمل) وبناء SQL seed لـ project_locations.
 * نفس منطق ملفات DDD.xlsx: إذا كان B فارغاً يُورَّث آخر موقع فرعي.
 */

function esc(s) {
  return String(s).replace(/'/g, "''");
}

/**
 * @param {any[][]} rows — sheet_to_json(..., { header: 1 })
 */
function parseRowsToStructure(rows) {
  let folder = '';
  const folderOrderMap = {};
  let folderSeq = 0;
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

function sqlWorkBlocks(projectName, pairs, folderNames) {
  const byFolder = {};
  for (const f of folderNames) byFolder[f] = [];
  for (const p of pairs) byFolder[p.folder].push(p);

  let sql = '';
  const pEsc = esc(projectName);
  for (const folder of folderNames) {
    const works = byFolder[folder];
    const valueRows = works
      .map((x) => `    ('${esc(x.work)}', ${x.workOrder})`)
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
WHERE p.name = '${pEsc}'
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

/**
 * @returns {string} ملف SQL كامل
 */
function buildLocationsSeedSql(projectName, parsed) {
  const { folderNames, folderOrderMap, pairs } = parsed;
  const pEsc = esc(projectName);
  const header = `-- هيكل مواقع: ${pEsc} (موقع فرعي=folder، موقع عمل=work_site)
-- يتطلب وجود الصف في projects بنفس الاسم بالضبط.
-- آمن لإعادة التشغيل (NOT EXISTS).

INSERT INTO project_locations (project_id, parent_id, name, type, display_order)
SELECT p.id, NULL, v.name, 'folder', v.display_order
FROM projects p
CROSS JOIN (
  VALUES
${sqlValuesFolder(folderOrderMap)}
) AS v(name, display_order)
WHERE p.name = '${pEsc}'
AND NOT EXISTS (
  SELECT 1
  FROM project_locations pl
  WHERE pl.project_id = p.id
    AND pl.parent_id IS NULL
    AND pl.name = v.name
    AND pl.type = 'folder'
);
`;
  const body = sqlWorkBlocks(projectName, pairs, folderNames);
  return header + body + '\n';
}

/** تقسيم لجمل PostgreSQL (كما في server.js) */
function splitSqlChunks(raw) {
  if (raw.charCodeAt(0) === 0xfeff) raw = raw.slice(1);
  return raw.split(/\n\n(?=INSERT INTO)/);
}

module.exports = {
  esc,
  parseRowsToStructure,
  buildLocationsSeedSql,
  splitSqlChunks,
};
