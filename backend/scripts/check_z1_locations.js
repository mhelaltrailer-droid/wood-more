require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const PROJECT = 'Z1_EMAAR_F';

async function main() {
  const u = process.env.DATABASE_URL;
  if (!u) {
    console.log('FAIL: DATABASE_URL not set in backend/.env');
    process.exit(1);
  }
  const pool = new Pool({
    connectionString: u,
    ssl:
      u.includes('neon.tech') || u.includes('sslmode=require')
        ? { rejectUnauthorized: false }
        : false,
  });
  try {
    const meta = await pool.query('SELECT current_database() AS db');
    console.log('Connected database:', meta.rows[0].db);

    const p = await pool.query('SELECT id, name FROM projects WHERE name = $1', [
      PROJECT,
    ]);
    if (!p.rows.length) {
      console.log('FAIL: project not in DB:', PROJECT);
      return;
    }
    const projectId = p.rows[0].id;
    console.log('Project:', p.rows[0].name, 'id=', projectId);

    const total = await pool.query(
      'SELECT COUNT(*)::int AS n FROM project_locations WHERE project_id = $1',
      [projectId],
    );
    console.log('Locations total in DB:', total.rows[0].n);

    const byType = await pool.query(
      `SELECT type, COUNT(*)::int AS n FROM project_locations
       WHERE project_id = $1 GROUP BY type ORDER BY type`,
      [projectId],
    );
    console.log('By type:', byType.rows);

    if (total.rows[0].n > 0) {
      const sample = await pool.query(
        `SELECT id, name, type, parent_id FROM project_locations
         WHERE project_id = $1 ORDER BY display_order, id LIMIT 5`,
        [projectId],
      );
      console.log('Sample rows:', sample.rows);
    }
  } finally {
    await pool.end();
  }
}

main().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});
