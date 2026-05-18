require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Pool } = require('pg');

/** يطابق priorityMaterialNames في التطبيق (لم يعد حصراً على سبعة أسماء). */
const ALLOWED = [
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 3 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.9 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.7 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.4 m',
  'WPC - WG - LIGHT GRAY - Cladding grove 15.6*2.1 cm - L= 2.3 m',
  'ALU - KEEL - 40*20 - L= 6 m',
  'ALU - Shadow gap - ETR11 - 21*10 - L= 6 m',
  'ALU - Profile - ETR12 - 40*41 - L= 6 m',
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
