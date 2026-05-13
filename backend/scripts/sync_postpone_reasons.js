require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const DEFAULTS = [
  ['site_not_ready', 'عدم جاهزية موقع العمل', false],
  ['weather', 'ظروف جوية', false],
  ['contractor_absent', 'عدم حضور المقاول', false],
  ['other', 'أخرى', true],
];

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const now = new Date().toISOString();
    for (const [key, label, requiresCustom] of DEFAULTS) {
      await pool.query(
        `INSERT INTO postpone_reasons (reason_key, label, requires_custom, is_system, created_at)
         VALUES ($1,$2,$3,TRUE,$4)
         ON CONFLICT (reason_key) DO UPDATE
           SET label = EXCLUDED.label,
               requires_custom = EXCLUDED.requires_custom,
               is_system = TRUE`,
        [key, label, requiresCustom, now],
      );
    }
    const del = await pool.query(
      `DELETE FROM postpone_reasons
       WHERE is_system = TRUE
         AND reason_key NOT IN ('site_not_ready', 'weather', 'contractor_absent', 'other')`,
    );
    const rows = await pool.query(
      `SELECT reason_key, label, requires_custom
       FROM postpone_reasons
       WHERE is_system = TRUE
       ORDER BY CASE reason_key
         WHEN 'site_not_ready' THEN 1
         WHEN 'weather' THEN 2
         WHEN 'contractor_absent' THEN 3
         WHEN 'other' THEN 4
         ELSE 99
       END`,
    );
    console.log('deleted_system_rows', del.rowCount);
    for (const row of rows.rows) {
      console.log(`${row.reason_key}\t${row.label}\t${row.requires_custom}`);
    }
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
