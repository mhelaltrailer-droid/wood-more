/**
 * تقرير قراءة فقط عن جدول activity_logs: النمو اليومي، أكثر الطلبات تسجيلاً، وحجم الصف.
 * لا يعدّل أي بيانات.
 *
 * التشغيل:
 *   cd backend
 *   node scripts/inspect_activity_logs.js
 */
require('dotenv').config();
const { Pool } = require('pg');

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

function mb(bytes) {
  return `${(Number(bytes || 0) / 1024 / 1024).toFixed(2)} MB`;
}

function pad(v, n) {
  return String(v ?? '').padEnd(n);
}

async function overview(pool) {
  const { rows } = await pool.query(`
    SELECT
      COUNT(*)::bigint AS rows,
      MIN(created_at) AS oldest,
      MAX(created_at) AS newest,
      pg_total_relation_size('activity_logs') AS total_bytes,
      pg_indexes_size('activity_logs') AS index_bytes,
      COALESCE(SUM(octet_length(details)), 0)::bigint AS details_bytes,
      COALESCE(SUM(octet_length(endpoint) + octet_length(action_type) + octet_length(action_label)), 0)::bigint AS meta_bytes
    FROM activity_logs
  `);
  const r = rows[0];
  console.log('\n=== activity_logs: نظرة عامة ===');
  console.log(`عدد الصفوف:        ${Number(r.rows).toLocaleString('en-US')}`);
  console.log(`أقدم سجل:          ${String(r.oldest).slice(0, 19)}`);
  console.log(`أحدث سجل:          ${String(r.newest).slice(0, 19)}`);
  console.log(`الحجم الكلي:       ${mb(r.total_bytes)} (منها فهارس ${mb(r.index_bytes)})`);
  console.log(`عمود details:      ${mb(r.details_bytes)}`);
  console.log(`أعمدة الوصف:       ${mb(r.meta_bytes)}`);
  console.log(`متوسط حجم الصف:    ${(Number(r.total_bytes) / Math.max(Number(r.rows), 1)).toFixed(0)} bytes`);
  return r;
}

async function perDay(pool) {
  const { rows } = await pool.query(`
    SELECT LEFT(created_at, 10) AS day,
           COUNT(*)::bigint AS rows,
           COALESCE(SUM(octet_length(details)), 0)::bigint AS details_bytes
    FROM activity_logs
    GROUP BY 1
    ORDER BY 1 DESC
    LIMIT 45
  `);
  console.log('\n=== النمو اليومي (آخر 45 يوماً مسجَّلاً) ===');
  console.log(`${pad('day', 14)}${pad('rows', 12)}details`);
  for (const r of rows) {
    console.log(pad(r.day, 14) + pad(Number(r.rows).toLocaleString('en-US'), 12) + mb(r.details_bytes));
  }
}

async function perMonth(pool) {
  const { rows } = await pool.query(`
    SELECT LEFT(created_at, 7) AS month,
           COUNT(*)::bigint AS rows,
           COALESCE(SUM(octet_length(details)), 0)::bigint AS details_bytes
    FROM activity_logs
    GROUP BY 1 ORDER BY 1
  `);
  console.log('\n=== التجميع الشهري ===');
  console.log(`${pad('month', 12)}${pad('rows', 14)}details`);
  for (const r of rows) {
    console.log(pad(r.month, 12) + pad(Number(r.rows).toLocaleString('en-US'), 14) + mb(r.details_bytes));
  }
}

async function topEndpoints(pool) {
  const { rows } = await pool.query(`
    SELECT method, endpoint, action_type,
           COUNT(*)::bigint AS rows,
           COALESCE(SUM(octet_length(details)), 0)::bigint AS details_bytes
    FROM activity_logs
    GROUP BY 1, 2, 3
    ORDER BY 4 DESC
    LIMIT 20
  `);
  console.log('\n=== أكثر 20 طلباً تسجيلاً ===');
  console.log(`${pad('rows', 12)}${pad('details', 12)}${pad('method', 8)}endpoint (action_type)`);
  for (const r of rows) {
    console.log(
      pad(Number(r.rows).toLocaleString('en-US'), 12) +
        pad(mb(r.details_bytes), 12) +
        pad(r.method, 8) +
        `${r.endpoint} (${r.action_type})`,
    );
  }
}

async function retentionPreview(pool) {
  console.log('\n=== كم سنوفّر لو حدّدنا مدة استبقاء؟ ===');
  for (const days of [7, 14, 30, 60, 90]) {
    const cutoff = new Date(Date.now() - days * 86400 * 1000).toISOString();
    const { rows } = await pool.query(
      `SELECT COUNT(*)::bigint AS rows,
              COALESCE(SUM(octet_length(details)), 0)::bigint AS details_bytes
       FROM activity_logs WHERE created_at < $1`,
      [cutoff],
    );
    const r = rows[0];
    console.log(
      `الاستبقاء ${pad(days + ' يوم', 10)} → يُحذف ${pad(Number(r.rows).toLocaleString('en-US'), 12)} صف`,
    );
  }
}

async function run() {
  const pool = createPool();
  try {
    await overview(pool);
    await perMonth(pool);
    await perDay(pool);
    await topEndpoints(pool);
    await retentionPreview(pool);
  } finally {
    await pool.end();
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
