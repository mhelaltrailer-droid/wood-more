require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));

app.get('/', (req, res) => {
  res.json({ ok: true, message: 'Wood & More API', docs: 'Use POST /auth/login for login, /users, /projects, etc.' });
});

// Prefer DATABASE_URL (e.g. from Neon or Supabase); otherwise use individual env vars.
const pool = process.env.DATABASE_URL
  ? new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } })
  : new Pool({
      host: process.env.PGHOST || 'localhost',
      port: parseInt(process.env.PGPORT || '5432', 10),
      database: process.env.PGDATABASE || 'wood_more',
      user: process.env.PGUSER || 'wood_more',
      password: process.env.PGPASSWORD || 'wood_more',
    });

// One-time migration: add password column if missing (e.g. Docker volume created before it existed)
async function ensurePasswordColumn() {
  try {
    await pool.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS password TEXT NOT NULL DEFAULT '0000'
    `);
  } catch (e) {
    console.warn('ensurePasswordColumn:', e.message);
  }
}

// ——— Auth (email + password) ———
app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const emailNorm = (email || '').trim().toLowerCase();
    const pwd = (password || '').trim();
    if (!emailNorm || !pwd) return res.status(400).json({ error: 'email and password required' });
    const r = await pool.query(
      'SELECT id, name, email, role, COALESCE(password, \'0000\') AS password FROM users WHERE LOWER(TRIM(email)) = $1',
      [emailNorm]
    );
    if (r.rows.length === 0) return res.status(401).json(null);
    const row = r.rows[0];
    const stored = (row.password || '0000').trim();
    if (stored !== pwd) return res.status(401).json(null);
    res.json({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Users ———
app.get('/users/by-email', async (req, res) => {
  try {
    const email = (req.query.email || '').trim().toLowerCase();
    const r = await pool.query('SELECT id, name, email, role FROM users WHERE email = $1', [email]);
    if (r.rows.length === 0) return res.json(null);
    const row = r.rows[0];
    res.json({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/users', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name, email, role FROM users ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/users/site-engineers', async (req, res) => {
  try {
    const r = await pool.query("SELECT id, name, email, role FROM users WHERE role = 'site_engineer' ORDER BY name");
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/users', async (req, res) => {
  try {
    const { name, email, role, password } = req.body;
    const pwd = (password != null && String(password).trim() !== '') ? String(password).trim() : '0000';
    const r = await pool.query(
      'INSERT INTO users (name, email, role, password) VALUES ($1, $2, $3, $4) RETURNING id',
      [name, (email || '').trim().toLowerCase(), role, pwd]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/users/:id', async (req, res) => {
  try {
    const { name, email, role, password } = req.body;
    const updates = ['name = $1', 'email = $2', 'role = $3'];
    const params = [name, (email || '').trim().toLowerCase(), role];
    let i = 4;
    if (password != null && String(password).trim() !== '') {
      updates.push(`password = $${i}`);
      params.push(String(password).trim());
      i++;
    }
    params.push(req.params.id);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = $${i}`, params);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/users/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM users WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Projects ———
app.get('/projects', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM projects ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/projects', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO projects (name) VALUES ($1) RETURNING id', [req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/projects/:id', async (req, res) => {
  try {
    await pool.query('UPDATE projects SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/projects/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM project_stock WHERE project_id = $1', [req.params.id]);
    await pool.query('DELETE FROM zones WHERE project_id = $1', [req.params.id]);
    await pool.query('DELETE FROM projects WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Zones ———
app.get('/zones', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, project_id, name FROM zones WHERE project_id = $1 ORDER BY name', [req.query.projectId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), project_id: parseInt(row.project_id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/zones', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO zones (project_id, name) VALUES ($1, $2) RETURNING id', [req.body.projectId, req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/zones/:id', async (req, res) => {
  try {
    await pool.query('UPDATE zones SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/zones/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM buildings WHERE zone_id = $1', [req.params.id]);
    await pool.query('DELETE FROM zones WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Buildings ———
app.get('/buildings', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, zone_id, name, storage_info, model_details, cut_list FROM buildings WHERE zone_id = $1 ORDER BY name', [req.query.zoneId]);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), zone_id: parseInt(row.zone_id), name: row.name,
      storage_info: row.storage_info, model_details: row.model_details, cut_list: row.cut_list
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/buildings', async (req, res) => {
  try {
    const { zoneId, name, storageInfo, modelDetails, cutList } = req.body;
    const r = await pool.query(
      'INSERT INTO buildings (zone_id, name, storage_info, model_details, cut_list) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [zoneId, name, storageInfo || null, modelDetails || null, cutList || null]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/buildings/:id', async (req, res) => {
  try {
    const { name, storageInfo, modelDetails, cutList } = req.body;
    await pool.query('UPDATE buildings SET name = $1, storage_info = $2, model_details = $3, cut_list = $4 WHERE id = $5', [name, storageInfo || null, modelDetails || null, cutList || null, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/buildings/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM units WHERE building_id = $1', [req.params.id]);
    await pool.query('DELETE FROM building_materials WHERE building_id = $1', [req.params.id]);
    await pool.query('DELETE FROM building_cutlist_images WHERE building_id = $1', [req.params.id]);
    await pool.query('DELETE FROM buildings WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Attendance ———
app.post('/attendance', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query(
      'INSERT INTO attendance_records (user_id, user_name, type, date_time, location, project_id, project_name, notes) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id',
      [b.userId, b.userName, b.type, b.dateTime, b.location || '', b.projectId || null, b.projectName || null, b.notes || null]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/attendance', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM attendance_records ORDER BY date_time DESC');
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), user_id: parseInt(row.user_id), user_name: row.user_name, type: row.type,
      date_time: row.date_time, location: row.location, project_id: row.project_id ? parseInt(row.project_id) : null, project_name: row.project_name, notes: row.notes
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/attendance/by-user/:userId', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM attendance_records WHERE user_id = $1 ORDER BY date_time DESC', [req.params.userId]);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), user_id: parseInt(row.user_id), user_name: row.user_name, type: row.type,
      date_time: row.date_time, location: row.location, project_id: row.project_id ? parseInt(row.project_id) : null, project_name: row.project_name, notes: row.notes
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Materials ———
app.get('/materials', async (req, res) => {
  try {
    const r = await pool.query('SELECT name FROM materials ORDER BY name');
    res.json(r.rows.map(row => row.name));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/materials/with-ids', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM materials ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/materials', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO materials (name) VALUES ($1) RETURNING id', [req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/materials/:id', async (req, res) => {
  try {
    await pool.query('UPDATE materials SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/materials/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM materials WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Daily reports ———
app.post('/daily-reports', async (req, res) => {
  try {
    const b = req.body;
    const now = new Date().toISOString();
    const r = await pool.query(
      `INSERT INTO daily_reports (user_id, user_name, project_id, project_name, report_datetime, work_place, work_report, executed_today, supervisor_name, contractor_name, workers_count, tomorrow_plan, document_path, images_json, notes, materials_json, expenses_json, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18) RETURNING id`,
      [b.userId, b.userName, b.projectId || null, b.projectName || null, b.reportDate, b.workPlace || '', b.workReport || '', b.executedToday || '', b.supervisorName || null, b.contractorName || null, b.workersCount || null, b.tomorrowPlan || '', b.documentPath || null, typeof b.imagePaths === 'string' ? b.imagePaths : JSON.stringify(b.imagePaths || []), b.notes || null, typeof b.materials === 'string' ? b.materials : JSON.stringify(b.materials || []), typeof b.expenses === 'string' ? b.expenses : JSON.stringify(b.expenses || []), now]
    );
    const id = parseInt(r.rows[0].id);
    const expenses = Array.isArray(b.expenses) ? b.expenses : (typeof b.expenses === 'string' ? JSON.parse(b.expenses || '[]') : []);
    let totalExpense = 0;
    for (const e of expenses) {
      const amt = parseFloat(String((e.amount || '').replace(/[^\d.]/g, ''))) || 0;
      totalExpense += amt;
    }
    if (totalExpense > 0) {
      const bal = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [b.userId]);
      const current = bal.rows.length ? parseFloat(bal.rows[0].balance) : 0;
      await pool.query('INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2', [b.userId, current - totalExpense]);
    }
    // خصم المواد من مخزن المشروع: المطابقة بالمشروع + اسم الخامة فقط، والخصم يكون على رقم الكمية فقط (الوحدة ثابتة: متر / عود / متر مربع)
    if (b.projectId) {
      const materials = Array.isArray(b.materials) ? b.materials : (typeof b.materials === 'string' ? JSON.parse(b.materials || '[]') : []);
      const reportDate = b.reportDate ? new Date(b.reportDate) : new Date();
      for (const m of materials) {
        const materialName = m.materialName || m.material_name || '';
        const quantity = parseFloat(String((m.quantity || '').replace(/[^\d.]/g, ''))) || 0;
        const unit = (m.unit || 'متر').trim() || 'متر';
        if (!materialName || quantity <= 0) continue;
        const stock = await pool.query('SELECT id, quantity, unit FROM project_stock WHERE project_id = $1 AND material_name = $2 LIMIT 1', [b.projectId, materialName]);
        if (stock.rows.length === 0) continue;
        const row = stock.rows[0];
        const currentQty = parseFloat(String(row.quantity).replace(/[^\d.]/g, '')) || 0;
        const newQty = Math.max(0, currentQty - quantity);
        await pool.query('UPDATE project_stock SET quantity = $1 WHERE id = $2', [String(newQty), row.id]);
        await pool.query(
          'INSERT INTO project_stock_ledger (project_id, material_name, unit, quantity_delta, type, created_at, user_id, user_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
          [b.projectId, materialName, row.unit || unit, -quantity, 'deduct_report', reportDate.toISOString(), b.userId || null, b.userName || '']
        );
      }
    }
    res.json(id);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/daily-reports', async (req, res) => {
  try {
    const { dateFrom, dateTo, userId, projectId } = req.query;
    let q = 'SELECT * FROM daily_reports WHERE report_datetime >= $1 AND report_datetime <= $2';
    const params = [dateFrom, dateTo];
    let i = 3;
    if (userId) { q += ` AND user_id = $${i}`; params.push(userId); i++; }
    if (projectId) { q += ` AND project_id = $${i}`; params.push(projectId); i++; }
    q += ' ORDER BY report_datetime DESC';
    const r = await pool.query(q, params);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), user_id: parseInt(row.user_id), user_name: row.user_name, project_id: row.project_id ? parseInt(row.project_id) : null, project_name: row.project_name,
      report_datetime: row.report_datetime, work_place: row.work_place, work_report: row.work_report, executed_today: row.executed_today, supervisor_name: row.supervisor_name, contractor_name: row.contractor_name, workers_count: row.workers_count, tomorrow_plan: row.tomorrow_plan, document_path: row.document_path, images_json: row.images_json, notes: row.notes, materials_json: row.materials_json, expenses_json: row.expenses_json, created_at: row.created_at
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Engineer balance & custody ———
app.get('/engineer-balance/:userId', async (req, res) => {
  try {
    const r = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [req.params.userId]);
    res.json(r.rows.length ? parseFloat(r.rows[0].balance) : 0);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/engineer-balance', async (req, res) => {
  try {
    const { userId, balance } = req.body;
    await pool.query('INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2', [userId, balance]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/custody', async (req, res) => {
  try {
    const { userId, amount, note } = req.body;
    const now = new Date().toISOString();
    await pool.query('INSERT INTO engineer_custody (user_id, amount, created_at, note) VALUES ($1, $2, $3, $4)', [userId, amount, now, note || '']);
    const r = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [userId]);
    const current = r.rows.length ? parseFloat(r.rows[0].balance) : 0;
    // Custody = company gives cash to engineer → balance (what we owe) decreases
    await pool.query('INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2', [userId, current - parseFloat(amount)]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/custody', async (req, res) => {
  try {
    const userId = req.query.userId;
    const q = userId ? 'SELECT * FROM engineer_custody WHERE user_id = $1 ORDER BY created_at DESC' : 'SELECT * FROM engineer_custody ORDER BY created_at DESC';
    const params = userId ? [userId] : [];
    const r = await pool.query(q, params);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), user_id: parseInt(row.user_id), amount: parseFloat(row.amount), created_at: row.created_at, note: row.note })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Supervisors, Contractors ———
app.get('/supervisors', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM supervisors ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/supervisors', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO supervisors (name) VALUES ($1) RETURNING id', [req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/supervisors/:id', async (req, res) => {
  try {
    await pool.query('UPDATE supervisors SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/supervisors/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM supervisors WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/contractors', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM contractors ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/contractors', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO contractors (name) VALUES ($1) RETURNING id', [req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/contractors/:id', async (req, res) => {
  try {
    await pool.query('UPDATE contractors SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/contractors/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM contractors WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Project stock, Units, Building materials, Building cutlists ———
app.get('/project-stock', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, project_id, material_name, quantity, unit FROM project_stock WHERE project_id = $1 ORDER BY material_name', [req.query.projectId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), project_id: parseInt(row.project_id), material_name: row.material_name, quantity: row.quantity, unit: row.unit })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/project-stock', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query('INSERT INTO project_stock (project_id, material_name, quantity, unit) VALUES ($1, $2, $3, $4) RETURNING id', [b.projectId, b.materialName, b.quantity, b.unit]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/project-stock/:id', async (req, res) => {
  try {
    const b = req.body;
    await pool.query('UPDATE project_stock SET material_name = $1, quantity = $2, unit = $3 WHERE id = $4', [b.materialName, b.quantity, b.unit, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/project-stock/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM project_stock WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Project stock ledger (سجل حركات الخامات) ———
app.post('/project-stock-ledger', async (req, res) => {
  try {
    const { projectId, materialName, unit, quantityDelta, type, userName, userId, createdAt } = req.body;
    const now = (createdAt ? new Date(createdAt) : new Date()).toISOString();
    await pool.query(
      'INSERT INTO project_stock_ledger (project_id, material_name, unit, quantity_delta, type, created_at, user_id, user_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
      [projectId, materialName, unit || '', quantityDelta, type || 'add', now, userId || null, userName || '']
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/project-stock-ledger', async (req, res) => {
  try {
    const { projectId, materialName } = req.query;
    if (!projectId || !materialName) return res.status(400).json({ error: 'projectId and materialName required' });
    const r = await pool.query(
      'SELECT * FROM project_stock_ledger WHERE project_id = $1 AND material_name = $2 ORDER BY created_at DESC',
      [projectId, materialName]
    );
    res.json(r.rows.map(row => ({
      id: parseInt(row.id),
      project_id: parseInt(row.project_id),
      material_name: row.material_name,
      unit: row.unit,
      quantity_delta: parseFloat(row.quantity_delta),
      type: row.type,
      created_at: row.created_at,
      user_id: row.user_id ? parseInt(row.user_id) : null,
      user_name: row.user_name || ''
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/units', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, building_id, name, model, image_path FROM units WHERE building_id = $1 ORDER BY name', [req.query.buildingId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), building_id: parseInt(row.building_id), name: row.name, model: row.model, image_path: row.image_path })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/units', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query('INSERT INTO units (building_id, name, model, image_path) VALUES ($1, $2, $3, $4) RETURNING id', [b.buildingId, b.name, b.model || b.name, b.imagePath || null]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/units/:id', async (req, res) => {
  try {
    const b = req.body;
    await pool.query('UPDATE units SET name = $1, model = $2, image_path = $3 WHERE id = $4', [b.name, b.model, b.imagePath || null, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/units/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM units WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/building-materials', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, building_id, material_name, quantity, unit, length, pieces_count, total_length, total_area, image_path FROM building_materials WHERE building_id = $1 ORDER BY material_name', [req.query.buildingId]);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), building_id: parseInt(row.building_id), material_name: row.material_name, length: row.length || '', pieces_count: row.pieces_count || '', total_length: row.total_length || '', total_area: row.total_area || '', image_path: row.image_path
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/building-materials', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query(
      'INSERT INTO building_materials (building_id, material_name, quantity, unit, length, pieces_count, total_length, total_area, image_path) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id',
      [b.buildingId, b.materialName, b.quantity || '', b.unit || '', b.length || '', b.piecesCount || '', b.totalLength || '', b.totalArea || '', b.imagePath || null]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/building-materials/:id', async (req, res) => {
  try {
    const b = req.body;
    await pool.query('UPDATE building_materials SET material_name = $1, length = $2, pieces_count = $3, total_length = $4, total_area = $5, image_path = $6 WHERE id = $7', [b.materialName, b.length || '', b.piecesCount || '', b.totalLength || '', b.totalArea || '', b.imagePath || null, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/building-materials/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM building_materials WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/building-cutlists', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, building_id, image_path FROM building_cutlist_images WHERE building_id = $1', [req.query.buildingId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), building_id: parseInt(row.building_id), image_path: row.image_path })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/building-cutlists', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query('INSERT INTO building_cutlist_images (building_id, image_path) VALUES ($1, $2) RETURNING id', [b.buildingId, b.imagePath]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/building-cutlists/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM building_cutlist_images WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

const PORT = parseInt(process.env.PORT || '3000', 10);
ensurePasswordColumn()
  .then(() => {
    app.listen(PORT, () => console.log(`Wood & More API listening on ${PORT}`));
  })
  .catch((e) => {
    console.error('Startup failed:', e);
    process.exit(1);
  });
