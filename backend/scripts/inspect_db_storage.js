/**
 * تقرير قراءة فقط عن استهلاك المساحة في قاعدة البيانات (Neon).
 * لا ينفّذ أي تعديل أو حذف — SELECT فقط.
 *
 * الإعداد:
 *   backend/.env يحتوي: DATABASE_URL=postgresql://...
 *
 * التشغيل:
 *   cd backend
 *   node scripts/inspect_db_storage.js
 *
 * أو بدون .env:
 *   $env:DATABASE_URL="postgresql://..."; cd backend; node scripts/inspect_db_storage.js
 */
require('dotenv').config();
const { Pool } = require('pg');

// أعمدة المحتوى الكبير (base64) التي نتوقع أنها سبب نمو الحجم.
const BLOB_COLUMN_PATTERN = /(file_data|chunk_data|data_url|image|images|photo|attachment|payload|rows_json|_json)/i;
const DAYS_BACK = 45;

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

async function totalSize(pool) {
  const { rows } = await pool.query(
    'SELECT pg_database_size(current_database()) AS bytes, current_database() AS db',
  );
  console.log(`\n=== إجمالي حجم قاعدة البيانات (${rows[0].db}) ===`);
  console.log(mb(rows[0].bytes));
}

async function tableSizes(pool) {
  const { rows } = await pool.query(`
    SELECT
      c.relname AS table_name,
      pg_total_relation_size(c.oid) AS total_bytes,
      pg_relation_size(c.oid) AS heap_bytes,
      COALESCE(pg_total_relation_size(c.reltoastrelid), 0) AS toast_bytes,
      pg_indexes_size(c.oid) AS index_bytes,
      COALESCE(s.n_live_tup, 0) AS live_rows,
      COALESCE(s.n_dead_tup, 0) AS dead_rows,
      s.last_autovacuum,
      s.last_vacuum
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
    WHERE c.relkind = 'r' AND n.nspname = 'public'
    ORDER BY pg_total_relation_size(c.oid) DESC
    LIMIT 25
  `);

  console.log('\n=== أكبر 25 جدولاً (الحجم الكلي يتضمن TOAST والفهارس) ===');
  console.log(
    `${pad('table', 34)}${pad('total', 12)}${pad('toast', 12)}${pad('index', 12)}${pad('live', 9)}${pad('dead', 9)}vacuum`,
  );
  for (const r of rows) {
    const vac = r.last_autovacuum || r.last_vacuum;
    console.log(
      pad(r.table_name, 34) +
        pad(mb(r.total_bytes), 12) +
        pad(mb(r.toast_bytes), 12) +
        pad(mb(r.index_bytes), 12) +
        pad(r.live_rows, 9) +
        pad(r.dead_rows, 9) +
        (vac ? new Date(vac).toISOString().slice(0, 10) : 'never'),
    );
  }
}

async function findBlobColumns(pool) {
  const { rows } = await pool.query(`
    SELECT table_name, column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND data_type IN ('text', 'bytea', 'character varying', 'json', 'jsonb')
    ORDER BY table_name, column_name
  `);
  return rows.filter((r) => BLOB_COLUMN_PATTERN.test(r.column_name));
}

async function timestampColumnFor(pool, table) {
  const { rows } = await pool.query(
    `SELECT column_name, data_type
     FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1
       AND column_name IN ('created_at', 'uploaded_at', 'report_datetime', 'updated_at', 'downloaded_at')
     ORDER BY array_position(
       ARRAY['created_at','uploaded_at','report_datetime','updated_at','downloaded_at'], column_name)
     LIMIT 1`,
    [table],
  );
  return rows[0] || null;
}

async function blobTotals(pool, blobColumns) {
  console.log('\n=== حجم المحتوى المخزَّن داخل الأعمدة (base64 وغيره) ===');
  const byTable = new Map();
  for (const col of blobColumns) {
    if (!byTable.has(col.table_name)) byTable.set(col.table_name, []);
    byTable.get(col.table_name).push(col.column_name);
  }

  const results = [];
  for (const [table, cols] of byTable) {
    const sums = cols.map((c) => `COALESCE(SUM(octet_length("${c}"::text)), 0)`).join(' + ');
    try {
      const { rows } = await pool.query(
        `SELECT COUNT(*)::bigint AS rows, (${sums})::bigint AS bytes FROM "${table}"`,
      );
      results.push({ table, cols: cols.join(', '), rows: rows[0].rows, bytes: rows[0].bytes });
    } catch (e) {
      results.push({ table, cols: cols.join(', '), rows: '-', bytes: 0, error: e.message });
    }
  }

  results.sort((a, b) => Number(b.bytes) - Number(a.bytes));
  console.log(`${pad('table', 30)}${pad('content', 12)}${pad('rows', 8)}columns`);
  for (const r of results) {
    console.log(
      pad(r.table, 30) + pad(mb(r.bytes), 12) + pad(r.rows, 8) + (r.error ? `ERROR: ${r.error}` : r.cols),
    );
  }
  return results.filter((r) => Number(r.bytes) > 1024 * 1024);
}

async function growthByDay(pool, table, cols) {
  const ts = await timestampColumnFor(pool, table);
  if (!ts) {
    console.log(`\n--- ${table}: لا يوجد عمود تاريخ للتجميع ---`);
    return;
  }
  const sums = cols
    .split(', ')
    .map((c) => `COALESCE(SUM(octet_length("${c}"::text)), 0)`)
    .join(' + ');

  // created_at مخزَّن كنص ISO في معظم الجداول، لذا نأخذ أول 10 أحرف.
  const dayExpr =
    ts.data_type === 'text' || ts.data_type === 'character varying'
      ? `LEFT("${ts.column_name}", 10)`
      : `TO_CHAR("${ts.column_name}", 'YYYY-MM-DD')`;

  try {
    const { rows } = await pool.query(`
      SELECT ${dayExpr} AS day, COUNT(*)::bigint AS rows, (${sums})::bigint AS bytes
      FROM "${table}"
      GROUP BY 1
      HAVING (${sums}) > 0
      ORDER BY 1 DESC
      LIMIT ${DAYS_BACK}
    `);
    if (!rows.length) return;
    console.log(`\n--- ${table}: التوزيع الزمني (${ts.column_name}) ---`);
    for (const r of rows) {
      console.log(`${pad(r.day, 14)}${pad(mb(r.bytes), 12)}${r.rows} row(s)`);
    }
  } catch (e) {
    console.log(`\n--- ${table}: فشل التجميع الزمني: ${e.message} ---`);
  }
}

async function appReleaseDetail(pool) {
  console.log('\n=== تفاصيل جداول تحديث التطبيق (APK) ===');
  try {
    const { rows } = await pool.query(`
      SELECT id, version_label, version_code, file_name, size_bytes,
             octet_length(file_data) AS stored_bytes, uploaded_by_email, created_at
      FROM app_releases ORDER BY id DESC
    `);
    if (!rows.length) {
      console.log('app_releases: لا يوجد إصدار مخزَّن حالياً.');
    } else {
      for (const r of rows) {
        console.log(
          `app_releases #${r.id}  ${r.version_label} (code ${r.version_code})  ` +
            `apk=${mb(r.size_bytes)}  base64=${mb(r.stored_bytes)}  ${String(r.created_at).slice(0, 10)}  ${r.uploaded_by_email}`,
        );
      }
    }
  } catch (e) {
    console.log(`app_releases: ${e.message}`);
  }

  try {
    const { rows } = await pool.query(`
      SELECT upload_id, COUNT(*)::int AS chunks,
             SUM(octet_length(chunk_data))::bigint AS bytes,
             MIN(created_at) AS started
      FROM app_release_upload_chunks
      GROUP BY upload_id ORDER BY 3 DESC
    `);
    if (!rows.length) {
      console.log('app_release_upload_chunks: فارغ (لا بقايا رفع غير مكتمل).');
    } else {
      console.log('app_release_upload_chunks: بقايا عمليات رفع غير مكتملة');
      for (const r of rows) {
        console.log(
          `  upload ${r.upload_id}  ${r.chunks} chunk(s)  ${mb(r.bytes)}  بدأ ${String(r.started).slice(0, 10)}`,
        );
      }
    }
  } catch (e) {
    console.log(`app_release_upload_chunks: ${e.message}`);
  }
}

async function run() {
  const pool = createPool();
  try {
    await totalSize(pool);
    await tableSizes(pool);
    const blobColumns = await findBlobColumns(pool);
    const big = await blobTotals(pool, blobColumns);
    await appReleaseDetail(pool);
    console.log('\n=== نمو المحتوى يوماً بيوم لأكبر الجداول ===');
    for (const r of big.slice(0, 8)) {
      await growthByDay(pool, r.table, r.cols);
    }
  } finally {
    await pool.end();
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
