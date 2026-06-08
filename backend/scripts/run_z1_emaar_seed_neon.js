/**
 * يضيف هيكلة Z1_EMAAR_F إلى PostgreSQL (Neon) ثم تظهر في تطبيق الهاتف عبر الـ API.
 *
 * الإعداد:
 *   1. انسخ connection string من Neon (يضم غالباً sslmode=require)
 *   2. في مجلد backend أنشئ ملف .env يحتوي:
 *        DATABASE_URL=postgresql://...
 *
 * التشغيل من جذر المستودع:
 *   cd backend
 *   node scripts/run_z1_emaar_seed_neon.js
 *
 * أو من PowerShell بدون .env:
 *   $env:DATABASE_URL="postgresql://..."; cd backend; node scripts/run_z1_emaar_seed_neon.js
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const { splitSqlChunks } = require('./lib/xlsx_project_locations');

const PROJECT_NAME = 'Z1_EMAAR_F';

function createPool() {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl || !String(databaseUrl).trim()) {
    console.error('Missing DATABASE_URL. Set it in backend/.env or the environment.');
    process.exit(1);
  }
  return new Pool({
    connectionString: databaseUrl,
    ssl:
      databaseUrl.includes('sslmode=require') || databaseUrl.includes('neon.tech')
        ? { rejectUnauthorized: false }
        : false,
  });
}

async function ensureProject(pool) {
  await pool.query(
    `INSERT INTO projects (name)
     SELECT $1::text
     WHERE NOT EXISTS (SELECT 1 FROM projects WHERE name = $1)`,
    [PROJECT_NAME],
  );
}

function loadSeedChunks() {
  const sqlPath = path.join(__dirname, 'seed_z1_emaar_f_project_locations.sql');
  if (!fs.existsSync(sqlPath)) {
    throw new Error(`Seed file not found: ${sqlPath}`);
  }
  const raw = fs.readFileSync(sqlPath, 'utf8');
  return splitSqlChunks(raw);
}

async function run() {
  const pool = createPool();
  try {
    await ensureProject(pool);
    console.log(`Project ensured: ${PROJECT_NAME}`);

    const chunks = loadSeedChunks();
    let ran = 0;
    for (const chunk of chunks) {
      const s = chunk.trim();
      if (!s.startsWith('INSERT INTO')) continue;
      await pool.query(s);
      ran += 1;
    }
    console.log(`Seed OK: executed ${ran} INSERT chunk(s).`);

    const { rows } = await pool.query(
      `SELECT COUNT(*)::int AS c FROM project_locations pl
       INNER JOIN projects p ON p.id = pl.project_id
       WHERE p.name = $1`,
      [PROJECT_NAME],
    );
    console.log(`Locations in DB for ${PROJECT_NAME}: ${rows[0].c}`);
  } finally {
    await pool.end();
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
