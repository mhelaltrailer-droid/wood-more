/**
 * تقليص جدول activity_logs: حذف السجلات الأقدم من مدة الاستبقاء، ثم استعادة المساحة.
 *
 * الحذف على دفعات لتجنّب قفل الجدول طويلاً على قاعدة بيانات إنتاج،
 * ثم VACUUM FULL لأن الحذف وحده لا يُصغّر الحجم في PostgreSQL.
 *
 * عرض فقط بدون تنفيذ (افتراضي):
 *   cd backend
 *   node scripts/prune_activity_logs.js --days=7
 *
 * التنفيذ الفعلي:
 *   node scripts/prune_activity_logs.js --days=7 --yes
 *
 * خيارات:
 *   --days=N        مدة الاستبقاء بالأيام (افتراضي 7).
 *   --batch=N       عدد الصفوف في كل دفعة حذف (افتراضي 50000).
 *   --no-vacuum     تخطَّ VACUUM FULL.
 *   --vacuum-only   لا تحذف؛ نفّذ VACUUM FULL فقط لاستعادة المساحة الميتة.
 */
require('dotenv').config();
const { Pool } = require('pg');

const args = process.argv.slice(2);
const APPLY = args.includes('--yes');
const SKIP_VACUUM = args.includes('--no-vacuum');
const VACUUM_ONLY = args.includes('--vacuum-only');
const numArg = (name, fallback) => {
  const a = args.find((x) => x.startsWith(`--${name}=`));
  const n = a ? Number(a.split('=')[1]) : NaN;
  return Number.isFinite(n) && n > 0 ? n : fallback;
};
const RETENTION_DAYS = numArg('days', 7);
const BATCH = numArg('batch', 50000);

// الجداول التي نستعيد مساحتها الميتة أيضاً (app_releases فيه dead tuples من إصدارات محذوفة).
const EXTRA_VACUUM_TABLES = ['app_releases', 'app_release_upload_chunks', 'app_release_downloads'];

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

async function snapshot(pool, label) {
  const { rows } = await pool.query(`
    SELECT pg_database_size(current_database()) AS db_bytes,
           pg_total_relation_size('activity_logs') AS logs_bytes,
           (SELECT COUNT(*)::bigint FROM activity_logs) AS logs_rows
  `);
  const r = rows[0];
  console.log(
    `\n[${label}] قاعدة البيانات: ${mb(r.db_bytes)} | activity_logs: ${mb(r.logs_bytes)} | ` +
      `${Number(r.logs_rows).toLocaleString('en-US')} صف`,
  );
  return r;
}

async function plan(pool, cutoffIso) {
  const { rows } = await pool.query(
    `SELECT COUNT(*)::bigint AS doomed,
            MIN(created_at) AS oldest,
            MAX(created_at) AS newest_doomed
     FROM activity_logs WHERE created_at < $1`,
    [cutoffIso],
  );
  const r = rows[0];
  console.log('\n=== خطة الحذف ===');
  console.log(`مدة الاستبقاء:     ${RETENTION_DAYS} يوم`);
  console.log(`الحد الفاصل:       ${cutoffIso.slice(0, 19)}`);
  console.log(`سيُحذف:            ${Number(r.doomed).toLocaleString('en-US')} صف`);
  console.log(`أقدم سجل حالياً:   ${String(r.oldest || '-').slice(0, 19)}`);
  console.log(`أحدث سجل سيُحذف:   ${String(r.newest_doomed || '-').slice(0, 19)}`);
  return Number(r.doomed);
}

async function deleteInBatches(pool, cutoffIso, doomed) {
  console.log('\n=== الحذف على دفعات ===');
  let removed = 0;
  for (;;) {
    const res = await pool.query(
      `DELETE FROM activity_logs
       WHERE id IN (
         SELECT id FROM activity_logs WHERE created_at < $1 ORDER BY id LIMIT $2
       )`,
      [cutoffIso, BATCH],
    );
    if (!res.rowCount) break;
    removed += res.rowCount;
    const pct = doomed ? ((removed / doomed) * 100).toFixed(0) : '?';
    console.log(`  حُذف ${removed.toLocaleString('en-US')} / ${doomed.toLocaleString('en-US')} (${pct}%)`);
  }
  console.log(`الإجمالي المحذوف: ${removed.toLocaleString('en-US')} صف`);
  return removed;
}

async function vacuum(pool) {
  console.log('\n=== استعادة المساحة (VACUUM FULL) ===');
  for (const t of ['activity_logs', ...EXTRA_VACUUM_TABLES]) {
    const startedAt = Date.now();
    try {
      await pool.query(`VACUUM (FULL, ANALYZE) ${t}`);
      console.log(`  ${t}: تم في ${((Date.now() - startedAt) / 1000).toFixed(1)}s`);
    } catch (e) {
      console.log(`  ${t}: فشل (${e.message})`);
    }
  }
}

async function run() {
  const pool = createPool();
  try {
    const before = await snapshot(pool, 'قبل');

    if (VACUUM_ONLY) {
      if (!APPLY) {
        console.log('\n*** وضع العرض فقط — أضف --yes لتنفيذ VACUUM. ***');
        return;
      }
      await vacuum(pool);
      await snapshot(pool, 'بعد');
      return;
    }

    const cutoffIso = new Date(Date.now() - RETENTION_DAYS * 86400 * 1000).toISOString();
    const doomed = await plan(pool, cutoffIso);

    if (!APPLY) {
      console.log('\n*** وضع العرض فقط — لم يُحذف أي شيء. أضف --yes للتنفيذ. ***');
      return;
    }
    if (!doomed) {
      console.log('\nلا يوجد ما يُحذف.');
    } else {
      await deleteInBatches(pool, cutoffIso, doomed);
    }

    if (!SKIP_VACUUM) await vacuum(pool);
    const after = await snapshot(pool, 'بعد');
    const saved = Number(before.db_bytes) - Number(after.db_bytes);
    console.log(`\nالمساحة المستعادة: ${mb(saved)}`);
  } finally {
    await pool.end();
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
