/**
 * Cont Progress — إنجازات ميدانية من مهندس الموقع
 * (مقاول + مشروع + موقع هيكلة المستخلصات + نسبة أو أمتار)
 */

const { applyViewAsToUser } = require('./view_as');

function cpStr(raw) {
  return String(raw ?? '').trim();
}

function cpNum(raw, fallback = 0) {
  const n = parseFloat(String(raw ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : fallback;
}

function cpNormEmail(email) {
  return cpStr(email).toLowerCase();
}

function cpIsAppAdmin(user) {
  return !!user && cpStr(user.role) === 'app_admin';
}

function cpCanSubmit(user) {
  if (!user) return false;
  if (cpIsAppAdmin(user)) return true;
  const role = cpStr(user.role);
  return (
    role === 'site_engineer' ||
    role === 'site_engineer_manager' ||
    role === 'general_supervisor'
  );
}

function cpCanList(user) {
  if (!user) return false;
  if (cpCanSubmit(user)) return true;
  const role = cpStr(user.role);
  const email = cpNormEmail(user.email);
  return (
    role === 'qs' ||
    role === 'projects_manager' ||
    role === 'operation_manager' ||
    role === 'accountant' ||
    email === 'qs-user' ||
    email === 'qs@app.com' ||
    email === 'ah-amin' ||
    email === 'abdelrhmanellaithy828@gmail.com' ||
    email === 'shams'
  );
}

async function cpGetUser(pool, userId, req) {
  const r = await pool.query(
    'SELECT id, name, email, role FROM users WHERE id = $1',
    [userId],
  );
  return applyViewAsToUser(r.rows[0] || null, req);
}

async function ensureContProgressTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_progress_reports (
      id SERIAL PRIMARY KEY,
      project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      project_name TEXT NOT NULL DEFAULT '',
      contractor_id INTEGER REFERENCES contractors(id) ON DELETE SET NULL,
      contractor_name TEXT NOT NULL DEFAULT '',
      structure_location_id INTEGER NOT NULL
        REFERENCES invoice_structure_locations(id) ON DELETE RESTRICT,
      location_label TEXT NOT NULL DEFAULT '',
      measure_type TEXT NOT NULL DEFAULT '',
      progress_kind TEXT NOT NULL DEFAULT 'percent',
      progress_value NUMERIC(14,4) NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'submitted',
      created_by_user_id INTEGER,
      created_by_user_name TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_progress_project_contractor
    ON cont_progress_reports (project_id, contractor_id, created_at DESC)
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_progress_location
    ON cont_progress_reports (structure_location_id, created_at DESC)
  `);
}

function cpRowToJson(row) {
  return {
    id: parseInt(row.id, 10),
    project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
    project_name: row.project_name || '',
    contractor_id:
      row.contractor_id != null ? parseInt(row.contractor_id, 10) : null,
    contractor_name: row.contractor_name || '',
    structure_location_id:
      row.structure_location_id != null
        ? parseInt(row.structure_location_id, 10)
        : null,
    location_label: row.location_label || '',
    measure_type: row.measure_type || '',
    progress_kind: row.progress_kind || 'percent',
    progress_value: cpNum(row.progress_value),
    notes: row.notes || '',
    status: row.status || 'submitted',
    created_by_user_id:
      row.created_by_user_id != null
        ? parseInt(row.created_by_user_id, 10)
        : null,
    created_by_user_name: row.created_by_user_name || '',
    created_at: row.created_at,
  };
}

function registerContProgressRoutes(app, pool) {
  ensureContProgressTables(pool).catch((e) =>
    console.warn('ensureContProgressTables:', e.message),
  );

  /** قائمة إنجازات (فلترة اختيارية بمشروع/مقاول) */
  app.get('/cont-progress', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await cpGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!cpCanList(user)) return res.status(403).json({ error: 'forbidden' });

      const params = [];
      const where = [];
      const projectId = parseInt(String(req.query.projectId || ''), 10);
      const contractorId = parseInt(String(req.query.contractorId || ''), 10);
      if (Number.isFinite(projectId)) {
        params.push(projectId);
        where.push(`project_id = $${params.length}`);
      }
      if (Number.isFinite(contractorId)) {
        params.push(contractorId);
        where.push(`contractor_id = $${params.length}`);
      }
      // مهندس الموقع يرى ما سجّله؛ الأدوار الأعلى ترى الكل
      if (
        cpStr(user.role) === 'site_engineer' &&
        !cpIsAppAdmin(user)
      ) {
        params.push(userId);
        where.push(`created_by_user_id = $${params.length}`);
      }

      const sql = `
        SELECT * FROM cont_progress_reports
        ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
        ORDER BY created_at DESC, id DESC
        LIMIT 200
      `;
      const r = await pool.query(sql, params);
      res.json(r.rows.map(cpRowToJson));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /**
   * ملخص آخر إنجاز لكل موقع (لنفس المقاول+المشروع)
   * جاهز لاحقاً لشاشة QS.
   */
  app.get('/cont-progress/summary', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      const projectId = parseInt(String(req.query.projectId || ''), 10);
      if (Number.isNaN(userId) || Number.isNaN(projectId)) {
        return res.status(400).json({ error: 'userId and projectId required' });
      }
      const user = await cpGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!cpCanList(user)) return res.status(403).json({ error: 'forbidden' });

      const contractorIdRaw = req.query.contractorId;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const contractorName = cpStr(req.query.contractorName);

      const params = [projectId];
      let contractorClause = '';
      if (Number.isFinite(contractorId)) {
        params.push(contractorId);
        contractorClause = `AND contractor_id = $${params.length}`;
      } else if (contractorName) {
        params.push(contractorName);
        contractorClause = `AND LOWER(TRIM(contractor_name)) = LOWER(TRIM($${params.length}))`;
      }

      const r = await pool.query(
        `
        SELECT DISTINCT ON (structure_location_id) *
        FROM cont_progress_reports
        WHERE project_id = $1
          ${contractorClause}
        ORDER BY structure_location_id, created_at DESC, id DESC
        `,
        params,
      );
      res.json(r.rows.map(cpRowToJson));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /** إرسال إنجاز جديد */
  app.post('/cont-progress', async (req, res) => {
    try {
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await cpGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!cpCanSubmit(user)) return res.status(403).json({ error: 'forbidden' });

      const projectId = parseInt(String(b.projectId ?? b.project_id ?? ''), 10);
      const structureLocationId = parseInt(
        String(b.structureLocationId ?? b.structure_location_id ?? ''),
        10,
      );
      if (Number.isNaN(projectId) || Number.isNaN(structureLocationId)) {
        return res.status(400).json({
          error: 'projectId and structureLocationId required',
        });
      }

      const contractorIdRaw = b.contractorId ?? b.contractor_id;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const contractorName = cpStr(b.contractorName ?? b.contractor_name);
      if (!contractorName && !Number.isFinite(contractorId)) {
        return res.status(400).json({ error: 'contractor required' });
      }

      const projectName = cpStr(b.projectName ?? b.project_name);
      const locationLabel = cpStr(b.locationLabel ?? b.location_label);
      const notes = cpStr(b.notes);

      const proj = await pool.query(
        'SELECT id, name FROM projects WHERE id = $1',
        [projectId],
      );
      if (!proj.rows.length) {
        return res.status(404).json({ error: 'project not found' });
      }

      const loc = await pool.query(
        `SELECT id, project_id, name, type
         FROM invoice_structure_locations
         WHERE id = $1 AND project_id = $2`,
        [structureLocationId, projectId],
      );
      if (!loc.rows.length) {
        return res.status(404).json({ error: 'structure location not found' });
      }

      const mt = await pool.query(
        `SELECT measure_type FROM invoice_structure_projects WHERE project_id = $1`,
        [projectId],
      );
      if (!mt.rows.length) {
        return res.status(400).json({
          error: 'measure_type not set for project',
        });
      }
      const measureType = cpStr(mt.rows[0].measure_type).toLowerCase();
      const progressKind =
        measureType === 'flooring' ? 'meters' : 'percent';
      const progressValue = cpNum(b.progressValue ?? b.progress_value);
      if (!(progressValue > 0)) {
        return res.status(400).json({ error: 'progressValue must be > 0' });
      }
      if (progressKind === 'percent' && progressValue > 100) {
        return res.status(400).json({ error: 'percent cannot exceed 100' });
      }

      const ins = await pool.query(
        `INSERT INTO cont_progress_reports (
          project_id, project_name, contractor_id, contractor_name,
          structure_location_id, location_label, measure_type,
          progress_kind, progress_value, notes, status,
          created_by_user_id, created_by_user_name
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,'submitted',$11,$12)
        RETURNING *`,
        [
          projectId,
          projectName || proj.rows[0].name || '',
          Number.isFinite(contractorId) ? contractorId : null,
          contractorName,
          structureLocationId,
          locationLabel || loc.rows[0].name || '',
          measureType,
          progressKind,
          progressValue,
          notes,
          userId,
          user.name || '',
        ],
      );
      res.status(201).json(cpRowToJson(ins.rows[0]));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureContProgressTables,
  registerContProgressRoutes,
};
