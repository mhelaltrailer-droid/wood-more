/**
 * إدراج خامات WPC - WG -P06 - SECTION في جدول materials (Neon عبر DATABASE_URL).
 * Usage: cd backend && node scripts/run_wpc_p06_section_materials_neon.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
const NAMES = require('./wpc_p06_section_materials_list');

function esc(s) {
  return String(s).replace(/'/g, "''");
}

function buildSql() {
  const lines = NAMES.map((n) => `  '${esc(n)}'`).join(',\n');
  return `-- خامات WPC - WG -P06 - SECTION (${NAMES.length} بند)
INSERT INTO materials (name)
SELECT t.name FROM unnest(ARRAY[
${lines}
]) AS t(name)
WHERE NOT EXISTS (SELECT 1 FROM materials m WHERE m.name = t.name);
`;
}

async function main() {
  const u = process.env.DATABASE_URL;
  if (!u) {
    console.error('DATABASE_URL غير مضبوط في backend/.env');
    process.exit(1);
  }

  const sqlPath = path.join(__dirname, 'seed_wpc_p06_section_materials.sql');
  const sql = buildSql();
  fs.writeFileSync(sqlPath, sql, 'utf8');
  console.log('Wrote', sqlPath);

  const pool = new Pool({
    connectionString: u,
    ssl:
      u.includes('neon.tech') || u.includes('sslmode=require')
        ? { rejectUnauthorized: false }
        : false,
  });

  try {
    const before = await pool.query(
      `SELECT COUNT(*)::int AS n FROM materials WHERE name = ANY($1::text[])`,
      [NAMES],
    );
    const r = await pool.query(sql);
    const after = await pool.query(
      `SELECT COUNT(*)::int AS n FROM materials WHERE name = ANY($1::text[])`,
      [NAMES],
    );
    const inserted = after.rows[0].n - before.rows[0].n;
    console.log(`List size: ${NAMES.length}`);
    console.log(`Already in DB before: ${before.rows[0].n}`);
    console.log(`Now in DB (from list): ${after.rows[0].n}`);
    console.log(`Newly inserted (approx): ${inserted}`);
    console.log('Done — refresh لوح التحكم → الخامات in the app.');
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
