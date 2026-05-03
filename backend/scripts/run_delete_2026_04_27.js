/**
 * One-off: حذف خطط/تقارير يوم 2026-04-27 من Neon أو أي Postgres عبر DATABASE_URL.
 * الاستخدام: من مجلد backend — node scripts/run_delete_2026_04_27.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const fs = require('fs');
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

async function main() {
  const beforeDr = `SELECT count(*)::int AS n FROM detailed_reports WHERE left(report_datetime, 10) = $1`;
  const beforeEp = `SELECT count(*)::int AS n FROM executed_plans WHERE plan_date LIKE $1 OR left(plan_date, 10) = $1`;
  const day = '2026-04-27';

  const client = new Client({ connectionString: url, ssl });
  await client.connect();
  try {
    const b1 = await client.query(beforeDr, [day]);
    const b2 = await client.query(beforeEp, [`${day}%`]);
    console.log('قبل الحذف — detailed_reports:', b1.rows[0].n, '| executed_plans:', b2.rows[0].n);

    const sql = fs.readFileSync(require('path').join(__dirname, 'delete_work_plans_2026_04_27.sql'), 'utf8');
    await client.query(sql);

    const a1 = await client.query(beforeDr, [day]);
    const a2 = await client.query(beforeEp, [`${day}%`]);
    console.log('بعد الحذف — detailed_reports:', a1.rows[0].n, '| executed_plans:', a2.rows[0].n);
  } finally {
    await client.end();
  }
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
