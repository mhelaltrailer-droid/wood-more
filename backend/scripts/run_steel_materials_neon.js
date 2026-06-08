/**
 * إدراج خامات حديدية مع منع التكرار الحرفي في DB والإبلاغ عن التكرارات المحتملة.
 * Usage: cd backend && node scripts/run_steel_materials_neon.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const RAW_NAMES = require('./steel_materials_list');

function esc(s) {
  return String(s).replace(/'/g, "''");
}

/** مفتاح تقريبي لمقارنة أسماء متشابهة (ST. vs Steel، x vs *) */
function normalizeKey(name) {
  return String(name)
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/×/g, '*')
    .replace(/x/gi, '*')
    .replace(/steel/g, 'st')
    .replace(/st\./g, 'st')
    .replace(/\s*mm\s*$/i, ' mm')
    .replace(/\s+/g, ' ')
    .trim();
}

function dedupeExact(names) {
  const seen = new Set();
  const unique = [];
  const dupes = [];
  for (const n of names) {
    const t = n.trim();
    if (!t) continue;
    if (seen.has(t)) {
      dupes.push(t);
      continue;
    }
    seen.add(t);
    unique.push(t);
  }
  return { unique, dupes };
}

function findNormalizedCollisions(names) {
  const map = new Map();
  const groups = [];
  for (const n of names) {
    const k = normalizeKey(n);
    if (!map.has(k)) map.set(k, []);
    map.get(k).push(n);
  }
  for (const [, group] of map) {
    if (group.length > 1) {
      const distinct = [...new Set(group)];
      if (distinct.length > 1) groups.push(distinct);
    }
  }
  return groups;
}

function buildSql(names) {
  const lines = names.map((n) => `  '${esc(n)}'`).join(',\n');
  return `-- خامات حديدية (${names.length} بند)
INSERT INTO materials (name)
SELECT t.name FROM unnest(ARRAY[
${lines}
]) AS t(name)
WHERE NOT EXISTS (SELECT 1 FROM materials m WHERE m.name = t.name);
`;
}

async function main() {
  const { unique, dupes: exactDupesInList } = dedupeExact(RAW_NAMES);
  const normCollisionsInList = findNormalizedCollisions(unique);

  console.log('=== القائمة المرفقة ===');
  console.log('عدد البنود الأصلي:', RAW_NAMES.length);
  console.log('بعد إزالة التكرار الحرفي داخل القائمة:', unique.length);
  if (exactDupesInList.length) {
    console.log('تكرار حرفي داخل القائمة (لم يُدرج مرة ثانية):', exactDupesInList);
  }
  if (normCollisionsInList.length) {
    console.log('\n⚠ تكرار محتمل داخل القائمة (نفس المعنى بصيغ مختلفة):');
    normCollisionsInList.forEach((g, i) => {
      console.log(`  ${i + 1}. ${g.join('  |  ')}`);
    });
  }

  const u = process.env.DATABASE_URL;
  if (!u) {
    console.error('\nDATABASE_URL غير مضبوط في backend/.env');
    process.exit(1);
  }

  const sqlPath = path.join(__dirname, 'seed_steel_materials.sql');
  const sql = buildSql(unique);
  fs.writeFileSync(sqlPath, sql, 'utf8');
  console.log('\nWrote', sqlPath);

  const pool = new Pool({
    connectionString: u,
    ssl:
      u.includes('neon.tech') || u.includes('sslmode=require')
        ? { rejectUnauthorized: false }
        : false,
  });

  try {
    const allDb = await pool.query('SELECT id, name FROM materials ORDER BY name');
    const dbNames = allDb.rows.map((r) => r.name);

    const exactInDb = unique.filter((n) => dbNames.includes(n));
    const toInsert = unique.filter((n) => !dbNames.includes(n));

    const normDbMap = new Map();
    for (const n of dbNames) {
      const k = normalizeKey(n);
      if (!normDbMap.has(k)) normDbMap.set(k, []);
      normDbMap.get(k).push(n);
    }

    const crossDbSimilar = [];
    for (const n of unique) {
      const k = normalizeKey(n);
      const existing = normDbMap.get(k) || [];
      const others = existing.filter((e) => e !== n);
      if (others.length > 0) {
        crossDbSimilar.push({ newName: n, existing: others });
      }
    }

    const before = await pool.query(
      `SELECT COUNT(*)::int AS n FROM materials WHERE name = ANY($1::text[])`,
      [unique],
    );
    await pool.query(sql);
    const after = await pool.query(
      `SELECT COUNT(*)::int AS n FROM materials WHERE name = ANY($1::text[])`,
      [unique],
    );

    console.log('\n=== قاعدة البيانات (Neon) ===');
    console.log('موجود مسبقاً بنفس الاسم (تخطي):', exactInDb.length);
    if (exactInDb.length) {
      exactInDb.forEach((n) => console.log('  -', n));
    }
    console.log('أُدرج حديثاً:', after.rows[0].n - before.rows[0].n);
    console.log('إجمالي بنود القائمة في DB الآن:', after.rows[0].n, '/', unique.length);

    if (crossDbSimilar.length) {
      console.log('\n⚠ تكرار محتمل مع خامات موجودة مسبقاً (اسم مختلف لكن نفس المعنى تقريباً):');
      crossDbSimilar.forEach((x, i) => {
        console.log(`  ${i + 1}. جديد: "${x.newName}"`);
        x.existing.forEach((e) => console.log(`       موجود: "${e}"`));
      });
    } else if (!normCollisionsInList.length) {
      console.log('\nلا يوجد تكرار محتمل إضافي مع قاعدة البيانات (بالمقارنة التقريبية).');
    }

    console.log('\nتم — حدّث شاشة الخامات في التطبيق.');
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
