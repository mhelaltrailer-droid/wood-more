require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const ALLOWED = [
  'WPC - WG - P06 - RHW 15*5 cm - L= 2.5m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1.4m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 3.7m',
  'WPC - WG - P06 - RHW 15*5 cm - L= 1m',
  'Steel box 30x30x3 mm lengh 2.45',
  'Steel C-Channel 135*50*30*2 mm length 0.035',
  'Steel box 30x30x3 mm length 3.65',
];

async function main() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  try {
    const before = await pool.query('SELECT COUNT(*)::int AS n FROM materials');
    const del = await pool.query(
      'DELETE FROM materials WHERE name <> ALL($1::text[])',
      [ALLOWED],
    );
    for (const name of ALLOWED) {
      await pool.query(
        'INSERT INTO materials (name) SELECT $1 WHERE NOT EXISTS (SELECT 1 FROM materials WHERE name = $1)',
        [name],
      );
    }
    const after = await pool.query(
      'SELECT id, name FROM materials ORDER BY id',
    );
    console.log('before_count', before.rows[0].n);
    console.log('deleted_rows', del.rowCount);
    console.log('after_count', after.rows.length);
    for (const row of after.rows) {
      console.log(`${row.id}\t${row.name}`);
    }
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
