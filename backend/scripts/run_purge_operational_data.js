/**
 * حذف بيانات تشغيلية من Postgres (Neon أو محلي) عبر DATABASE_URL.
 * الاستخدام من مجلد backend: node scripts/run_purge_operational_data.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL غير موجود في backend/.env');
  process.exit(1);
}

const ssl =
  url.includes('neon.tech') || url.includes('sslmode=require')
    ? { rejectUnauthorized: false }
    : undefined;

const tables = [
  'executed_plans',
  'detailed_reports',
  'contractors',
  'projects',
  'project_stock',
  'project_stock_ledger',
  'location_withdrawal',
  'location_materials',
  'withdrawal_requests',
  'attendance_records',
];

async function counts(client) {
  const out = {};
  for (const t of tables) {
    const r = await client.query(`SELECT COUNT(*)::int AS n FROM ${t}`);
    out[t] = r.rows[0].n;
  }
  return out;
}

async function main() {
  const client = new Client({ connectionString: url, ssl });
  await client.connect();
  try {
    console.log('قبل الحذف:', await counts(client));
    const sql = fs.readFileSync(path.join(__dirname, 'purge_operational_data.sql'), 'utf8');
    await client.query(sql);
    console.log('بعد الحذف:', await counts(client));
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
