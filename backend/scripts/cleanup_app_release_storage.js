/**
 * تنظيف المساحة التي تشغلها ملفات APK داخل قاعدة البيانات:
 *   1. حذف كل الإصدارات المرفوعة من app_releases (يحذف معها app_release_downloads بالـ CASCADE).
 *   2. حذف بقايا الرفع غير المكتمل من app_release_upload_chunks فقط.
 *   3. VACUUM FULL لاستعادة المساحة فعلياً (الحذف وحده لا يُصغّر الحجم في PostgreSQL).
 *
 * الإعداد:
 *   backend/.env يحتوي: DATABASE_URL=postgresql://...
 *
 * عرض ما سيُحذف بدون تنفيذ (الوضع الافتراضي):
 *   cd backend
 *   node scripts/cleanup_app_release_storage.js
 *
 * التنفيذ الفعلي:
 *   node scripts/cleanup_app_release_storage.js --yes
 *
 * خيارات:
 *   --max-age-hours=N   لا تحذف الأجزاء الأحدث من N ساعة (افتراضي 2) حتى لا نقطع رفعاً جارياً الآن.
 *   --all-chunks        احذف كل الأجزاء بغض النظر عن عمرها.
 *   --no-vacuum         تخطَّ خطوة VACUUM FULL.
 */
require('dotenv').config();
const { Pool } = require('pg');

const args = process.argv.slice(2);
const APPLY = args.includes('--yes');
const ALL_CHUNKS = args.includes('--all-chunks');
const SKIP_VACUUM = args.includes('--no-vacuum');
const maxAgeArg = args.find((a) => a.startsWith('--max-age-hours='));
const MAX_AGE_HOURS = maxAgeArg ? Number(maxAgeArg.split('=')[1]) : 2;

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

async function sizes(pool, label) {
  const { rows } = await pool.query(`
    SELECT
      pg_database_size(current_database()) AS db_bytes,
      COALESCE(pg_total_relation_size('app_releases'), 0) AS releases_bytes,
      COALESCE(pg_total_relation_size('app_release_upload_chunks'), 0) AS chunks_bytes
  `);
  const r = rows[0];
  console.log(
    `\n[${label}] قاعدة البيانات: ${mb(r.db_bytes)} | app_releases: ${mb(r.releases_bytes)} | chunks: ${mb(r.chunks_bytes)}`,
  );
  return r;
}

async function reportReleases(pool) {
  const { rows } = await pool.query(`
    SELECT id, version_label, version_code, file_name,
           size_bytes, octet_length(file_data) AS stored_bytes,
           uploaded_by_email, created_at
    FROM app_releases ORDER BY id DESC
  `);
  console.log('\n=== الإصدارات المرفوعة (app_releases) ===');
  if (!rows.length) {
    console.log('لا يوجد شيء للحذف.');
    return rows;
  }
  for (const r of rows) {
    console.log(
      `#${r.id}  ${r.version_label} (code ${r.version_code})  ${r.file_name}  ` +
        `apk=${mb(r.size_bytes)}  base64=${mb(r.stored_bytes)}  ${String(r.created_at).slice(0, 10)}  ${r.uploaded_by_email}`,
    );
  }
  const { rows: dl } = await pool.query('SELECT COUNT(*)::int AS n FROM app_release_downloads');
  console.log(`سجلات التنزيل المرتبطة (تُحذف بالـ CASCADE): ${dl[0].n}`);
  return rows;
}

async function reportChunks(pool) {
  // كل صف باقٍ هنا هو رفع غير مكتمل: الرفع الناجح يحذف أجزاءه في upload-finalize.
  const { rows } = await pool.query(`
    SELECT upload_id,
           COUNT(*)::int AS chunks,
           SUM(octet_length(chunk_data))::bigint AS bytes,
           MIN(created_at) AS started,
           MAX(created_at) AS last_activity
    FROM app_release_upload_chunks
    GROUP BY upload_id
    ORDER BY 3 DESC
  `);
  console.log('\n=== بقايا الرفع غير المكتمل (app_release_upload_chunks) ===');
  if (!rows.length) {
    console.log('الجدول فارغ — لا بقايا.');
    return { rows, cutoffIso: null };
  }

  const cutoffIso = new Date(Date.now() - MAX_AGE_HOURS * 3600 * 1000).toISOString();
  for (const r of rows) {
    const stale = ALL_CHUNKS || String(r.last_activity) < cutoffIso;
    console.log(
      `${stale ? '[سيُحذف] ' : '[يُستبعد - قد يكون جارياً] '}upload ${r.upload_id}  ` +
        `${r.chunks} chunk(s)  ${mb(r.bytes)}  آخر نشاط ${String(r.last_activity).slice(0, 19)}`,
    );
  }
  if (!ALL_CHUNKS) {
    console.log(`الحد الزمني: أي رفع آخر نشاط له قبل ${cutoffIso.slice(0, 19)} يُعد مهجوراً.`);
  }
  return { rows, cutoffIso };
}

async function run() {
  const pool = createPool();
  try {
    await sizes(pool, 'قبل');
    const releases = await reportReleases(pool);
    const { rows: chunkGroups, cutoffIso } = await reportChunks(pool);

    if (!APPLY) {
      console.log('\n*** وضع العرض فقط — لم يُحذف أي شيء. أضف --yes للتنفيذ. ***');
      return;
    }

    console.log('\n=== التنفيذ ===');

    const delReleases = await pool.query('DELETE FROM app_releases');
    console.log(`app_releases: حُذف ${delReleases.rowCount} صف.`);

    let delChunks = { rowCount: 0 };
    if (chunkGroups.length) {
      if (ALL_CHUNKS) {
        delChunks = await pool.query('DELETE FROM app_release_upload_chunks');
      } else {
        delChunks = await pool.query(
          `DELETE FROM app_release_upload_chunks
           WHERE upload_id IN (
             SELECT upload_id FROM app_release_upload_chunks
             GROUP BY upload_id
             HAVING MAX(created_at) < $1
           )`,
          [cutoffIso],
        );
      }
    }
    console.log(`app_release_upload_chunks: حُذف ${delChunks.rowCount} جزء.`);

    if (!SKIP_VACUUM) {
      // الحذف لا يُعيد المساحة في PostgreSQL؛ VACUUM FULL يعيد كتابة الجدول ويُصغّره فعلياً.
      for (const t of ['app_releases', 'app_release_upload_chunks', 'app_release_downloads']) {
        try {
          await pool.query(`VACUUM (FULL, ANALYZE) ${t}`);
          console.log(`VACUUM FULL ${t}: تم.`);
        } catch (e) {
          console.log(`VACUUM FULL ${t}: فشل (${e.message})`);
        }
      }
    }

    await sizes(pool, 'بعد');
    if (releases.length) {
      console.log(
        '\nتنبيه: لم يبق أي إصدار منشور، لذا لن يجد المستخدمون تحديثاً داخل التطبيق حتى ترفع APK جديداً.',
      );
    }
  } finally {
    await pool.end();
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
