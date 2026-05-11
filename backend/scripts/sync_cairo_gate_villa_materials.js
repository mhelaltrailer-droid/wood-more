require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Client } = require('pg');

async function main() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });
  await client.connect();

  const villas = await client.query(`
    SELECT pl.id, pl.name
    FROM project_locations pl
    JOIN projects p ON p.id = pl.project_id
    WHERE p.name = 'Cairo gate_ACC_W'
      AND pl.parent_id IS NULL
      AND pl.type = 'folder'
      AND pl.name ILIKE 'Villa%'
    ORDER BY pl.display_order, pl.id
  `);

  const template = await client.query(`
    SELECT lm.phase, lm.material_name, lm.quantity, lm.unit
    FROM location_materials lm
    JOIN project_locations pl ON pl.id = lm.location_id
    JOIN projects p ON p.id = pl.project_id
    WHERE p.name = 'Cairo gate_ACC_W'
      AND pl.name = 'Villa 1'
      AND pl.parent_id IS NULL
    ORDER BY lm.phase, lm.material_name
  `);

  if (template.rows.length === 0) {
    throw new Error('لا توجد خامات مرجعية في Villa 1');
  }

  await client.query('BEGIN');
  try {
    for (const villa of villas.rows) {
      await client.query('DELETE FROM location_materials WHERE location_id = $1', [villa.id]);
      for (const row of template.rows) {
        await client.query(
          `INSERT INTO location_materials (location_id, phase, material_name, quantity, unit)
           VALUES ($1, $2, $3, $4, $5)`,
          [villa.id, row.phase, row.material_name, row.quantity, row.unit]
        );
      }
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }

  const summary = await client.query(`
    SELECT pl.name AS villa, lm.phase, COUNT(*)::int AS materials_count
    FROM project_locations pl
    JOIN projects p ON p.id = pl.project_id
    LEFT JOIN location_materials lm ON lm.location_id = pl.id
    WHERE p.name = 'Cairo gate_ACC_W'
      AND pl.parent_id IS NULL
      AND pl.type = 'folder'
      AND pl.name ILIKE 'Villa%'
    GROUP BY pl.name, pl.display_order, pl.id, lm.phase
    ORDER BY pl.display_order, pl.id, lm.phase
  `);

  console.log(
    JSON.stringify(
      {
        templateRows: template.rows.length,
        villasUpdated: villas.rows.length,
        summary: summary.rows,
      },
      null,
      2
    )
  );

  await client.end();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
