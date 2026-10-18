/**
 * هيكلة المستخلصات — شجرة مستقلة عن project_locations.
 * أنواع القياس: flooring (= أمتار) | wpc (= Units)
 * صلاحية: app_admin فقط.
 */

const {
  applyViewAsToUser,
  primaryAdminPowersActiveForUser,
} = require('./view_as');

function isStr(raw) {
  return String(raw ?? '').trim();
}

function isNumOrNull(raw) {
  if (raw === null || raw === undefined || raw === '') return null;
  const n = parseFloat(String(raw).replace(/,/g, ''));
  return Number.isFinite(n) ? n : null;
}

function isAppAdmin(user) {
  return !!user && String(user.role || '').trim() === 'app_admin';
}

async function getUser(pool, userId, req) {
  const r = await pool.query(
    'SELECT id, name, email, role FROM users WHERE id = $1',
    [userId],
  );
  return applyViewAsToUser(r.rows[0] || null, req);
}

async function requireAppAdmin(pool, req, res) {
  const userId = parseInt(
    String(req.query.userId || req.body?.userId || ''),
    10,
  );
  if (Number.isNaN(userId)) {
    res.status(400).json({ error: 'userId required' });
    return null;
  }
  const user = await getUser(pool, userId, req);
  if (!user) {
    res.status(404).json({ error: 'user not found' });
    return null;
  }
  if (!isAppAdmin(user)) {
    res.status(403).json({ error: 'forbidden' });
    return null;
  }
  return user;
}

/** المسؤول الرئيسي فقط (وليس View-as لدور آخر). */
async function requirePrimaryAppAdmin(pool, req, res) {
  const user = await requireAppAdmin(pool, req, res);
  if (!user) return null;
  if (!primaryAdminPowersActiveForUser(user, req)) {
    res.status(403).json({ error: 'forbidden_primary_admin' });
    return null;
  }
  return user;
}

function normalizeMeasureType(raw) {
  const v = isStr(raw).toLowerCase();
  if (v === 'flooring' || v === 'wpc') return v;
  return null;
}

function normalizeNodeType(raw) {
  const v = isStr(raw).toLowerCase();
  if (v === 'folder' || v === 'work_site') return v;
  return null;
}

function locationRowToJson(row) {
  return {
    id: parseInt(row.id, 10),
    project_id: parseInt(row.project_id, 10),
    parent_id: row.parent_id != null ? parseInt(row.parent_id, 10) : null,
    name: row.name || '',
    type: row.type || 'folder',
    display_order: parseInt(row.display_order, 10) || 0,
    total_meters:
      row.total_meters == null ? null : parseFloat(row.total_meters),
    meter_price:
      row.meter_price == null ? null : parseFloat(row.meter_price),
    unit_value: row.unit_value == null ? null : parseFloat(row.unit_value),
  };
}

/**
 * نسخ شجرة project_locations → invoice_structure_locations لنفس المشروع.
 * فقط الاسم/النوع/الترتيب/الأب — بدون أمتار أو أسعار.
 */
async function importProjectLocationsToInvoiceStructure(
  pool,
  projectId,
  { onlyIfEmpty = true } = {},
) {
  const countR = await pool.query(
    `SELECT COUNT(*)::int AS c
     FROM invoice_structure_locations
     WHERE project_id = $1`,
    [projectId],
  );
  const existingCount = countR.rows[0]?.c || 0;
  if (onlyIfEmpty && existingCount > 0) {
    return {
      project_id: projectId,
      imported: 0,
      skipped: true,
      reason: 'already_has_locations',
      existing_count: existingCount,
    };
  }

  const src = await pool.query(
    `SELECT id, parent_id, name, type, display_order
     FROM project_locations
     WHERE project_id = $1
     ORDER BY display_order, id`,
    [projectId],
  );
  if (!src.rows.length) {
    return {
      project_id: projectId,
      imported: 0,
      skipped: true,
      reason: 'no_source_locations',
    };
  }

  const byParent = new Map();
  for (const row of src.rows) {
    const key = row.parent_id == null ? 'root' : String(row.parent_id);
    if (!byParent.has(key)) byParent.set(key, []);
    byParent.get(key).push(row);
  }

  const idMap = new Map();
  const queue = [...(byParent.get('root') || [])];
  let imported = 0;

  while (queue.length) {
    const row = queue.shift();
    const newParentId =
      row.parent_id == null ? null : idMap.get(parseInt(row.parent_id, 10));
    if (row.parent_id != null && newParentId == null) {
      continue;
    }
    const type = row.type === 'work_site' ? 'work_site' : 'folder';
    const ins = await pool.query(
      `INSERT INTO invoice_structure_locations (
        project_id, parent_id, name, type, display_order
      ) VALUES ($1, $2, $3, $4, $5)
      RETURNING id`,
      [
        projectId,
        newParentId ?? null,
        row.name || '',
        type,
        parseInt(row.display_order, 10) || 0,
      ],
    );
    idMap.set(parseInt(row.id, 10), parseInt(ins.rows[0].id, 10));
    imported += 1;
    const kids = byParent.get(String(row.id)) || [];
    queue.push(...kids);
  }

  return {
    project_id: projectId,
    imported,
    skipped: false,
    source_count: src.rows.length,
  };
}

async function ensureInvoiceStructureTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS invoice_structure_projects (
      project_id INTEGER PRIMARY KEY REFERENCES projects(id) ON DELETE CASCADE,
      measure_type TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CONSTRAINT invoice_structure_projects_measure_chk
        CHECK (measure_type IN ('flooring', 'wpc'))
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS invoice_structure_locations (
      id SERIAL PRIMARY KEY,
      project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      parent_id INTEGER REFERENCES invoice_structure_locations(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'folder',
      display_order INTEGER NOT NULL DEFAULT 0,
      total_meters NUMERIC(14,4),
      meter_price NUMERIC(14,4),
      unit_value NUMERIC(14,2),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CONSTRAINT invoice_structure_locations_type_chk
        CHECK (type IN ('folder', 'work_site'))
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_invoice_structure_locations_project
    ON invoice_structure_locations (project_id, parent_id, display_order, id)
  `);
}

function registerInvoiceStructureRoutes(app, pool) {
  /** حالة هيكلة مستخلصات لمشروع + الشجرة */
  app.get('/invoice-structure', async (req, res) => {
    try {
      const user = await requireAppAdmin(pool, req, res);
      if (!user) return;

      const projectId = parseInt(String(req.query.projectId || ''), 10);
      if (Number.isNaN(projectId)) {
        return res.status(400).json({ error: 'projectId required' });
      }

      const proj = await pool.query('SELECT id FROM projects WHERE id = $1', [
        projectId,
      ]);
      if (!proj.rows.length) {
        return res.status(404).json({ error: 'project not found' });
      }

      const mt = await pool.query(
        `SELECT measure_type FROM invoice_structure_projects WHERE project_id = $1`,
        [projectId],
      );
      const measureType = mt.rows.length
        ? String(mt.rows[0].measure_type)
        : null;

      const locs = await pool.query(
        `SELECT id, project_id, parent_id, name, type, display_order,
                total_meters, meter_price, unit_value
         FROM invoice_structure_locations
         WHERE project_id = $1
         ORDER BY display_order, id`,
        [projectId],
      );

      return res.json({
        project_id: projectId,
        measure_type: measureType,
        locations: locs.rows.map(locationRowToJson),
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /** تعيين نوع القياس مرة واحدة (flooring | wpc) */
  app.post('/invoice-structure/measure-type', async (req, res) => {
    try {
      const user = await requireAppAdmin(pool, req, res);
      if (!user) return;

      const projectId = parseInt(
        String(req.body.projectId ?? req.body.project_id ?? ''),
        10,
      );
      const measureType = normalizeMeasureType(
        req.body.measureType ?? req.body.measure_type,
      );
      if (Number.isNaN(projectId)) {
        return res.status(400).json({ error: 'projectId required' });
      }
      if (!measureType) {
        return res
          .status(400)
          .json({ error: 'measureType must be flooring or wpc' });
      }

      const proj = await pool.query('SELECT id FROM projects WHERE id = $1', [
        projectId,
      ]);
      if (!proj.rows.length) {
        return res.status(404).json({ error: 'project not found' });
      }

      const existing = await pool.query(
        `SELECT measure_type FROM invoice_structure_projects WHERE project_id = $1`,
        [projectId],
      );
      if (existing.rows.length) {
        return res.status(409).json({
          error: 'measure_type already set',
          measure_type: existing.rows[0].measure_type,
        });
      }

      await pool.query(
        `INSERT INTO invoice_structure_projects (project_id, measure_type)
         VALUES ($1, $2)`,
        [projectId, measureType],
      );

      // عند أول اعتماد للنوع: انسخ هيكلة المشروعات إن كانت شجرة المستخلصات فارغة
      const imported = await importProjectLocationsToInvoiceStructure(
        pool,
        projectId,
        { onlyIfEmpty: true },
      );

      return res.json({
        project_id: projectId,
        measure_type: measureType,
        import: imported,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /**
   * تغيير نوع القياس (Flooring ↔ WPC) — المسؤول الرئيسي فقط.
   * مع تحذير قوي من الواجهة؛ هنا يُحدَّث النوع ويُصفَّر حقول النوع الآخر.
   */
  app.put('/invoice-structure/measure-type', async (req, res) => {
    try {
      const user = await requirePrimaryAppAdmin(pool, req, res);
      if (!user) return;

      const projectId = parseInt(
        String(req.body.projectId ?? req.body.project_id ?? ''),
        10,
      );
      const measureType = normalizeMeasureType(
        req.body.measureType ?? req.body.measure_type,
      );
      if (Number.isNaN(projectId)) {
        return res.status(400).json({ error: 'projectId required' });
      }
      if (!measureType) {
        return res
          .status(400)
          .json({ error: 'measureType must be flooring or wpc' });
      }

      const existing = await pool.query(
        `SELECT measure_type FROM invoice_structure_projects WHERE project_id = $1`,
        [projectId],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'measure_type not set' });
      }
      const previous = String(existing.rows[0].measure_type || '');
      if (previous === measureType) {
        return res.json({
          project_id: projectId,
          measure_type: measureType,
          previous_measure_type: previous,
          unchanged: true,
        });
      }

      await pool.query(
        `UPDATE invoice_structure_projects
         SET measure_type = $1
         WHERE project_id = $2`,
        [measureType, projectId],
      );

      // صفّر حقول النوع السابق حتى لا تبقى قيم غير متوافقة ظاهرة
      if (measureType === 'flooring') {
        await pool.query(
          `UPDATE invoice_structure_locations
           SET unit_value = NULL
           WHERE project_id = $1`,
          [projectId],
        );
      } else {
        await pool.query(
          `UPDATE invoice_structure_locations
           SET total_meters = NULL, meter_price = NULL
           WHERE project_id = $1`,
          [projectId],
        );
      }

      return res.json({
        project_id: projectId,
        measure_type: measureType,
        previous_measure_type: previous,
        unchanged: false,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /** استيراد هيكلة المشروعات لمشروع واحد → هيكلة المستخلصات */
  app.post('/invoice-structure/import-from-project', async (req, res) => {
    try {
      const user = await requireAppAdmin(pool, req, res);
      if (!user) return;

      const projectId = parseInt(
        String(req.body.projectId ?? req.body.project_id ?? ''),
        10,
      );
      if (Number.isNaN(projectId)) {
        return res.status(400).json({ error: 'projectId required' });
      }
      const onlyIfEmpty = req.body.onlyIfEmpty !== false;
      const force = req.body.force === true;

      const proj = await pool.query('SELECT id FROM projects WHERE id = $1', [
        projectId,
      ]);
      if (!proj.rows.length) {
        return res.status(404).json({ error: 'project not found' });
      }

      if (force) {
        await pool.query(
          `DELETE FROM invoice_structure_locations WHERE project_id = $1`,
          [projectId],
        );
      }

      const result = await importProjectLocationsToInvoiceStructure(
        pool,
        projectId,
        { onlyIfEmpty: force ? false : onlyIfEmpty },
      );
      return res.json(result);
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /** استيراد هيكلة المشروعات لكل المشاريع التي لا تملك مواقع مستخلصات بعد */
  app.post('/invoice-structure/import-from-project-all', async (req, res) => {
    try {
      const user = await requireAppAdmin(pool, req, res);
      if (!user) return;

      const projects = await pool.query(
        `SELECT id, name FROM projects ORDER BY id`,
      );
      const results = [];
      let importedProjects = 0;
      let importedNodes = 0;
      let skipped = 0;

      for (const p of projects.rows) {
        const projectId = parseInt(p.id, 10);
        const r = await importProjectLocationsToInvoiceStructure(
          pool,
          projectId,
          { onlyIfEmpty: true },
        );
        results.push({
          project_id: projectId,
          project_name: p.name || '',
          ...r,
        });
        if (r.skipped) skipped += 1;
        else {
          importedProjects += 1;
          importedNodes += r.imported || 0;
        }
      }

      return res.json({
        projects_total: projects.rows.length,
        imported_projects: importedProjects,
        imported_nodes: importedNodes,
        skipped,
        results,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/invoice-structure/locations', async (req, res) => {
    try {
      const user = await requireAppAdmin(pool, req, res);
      if (!user) return;

      const projectId = parseInt(
        String(req.body.projectId ?? req.body.project_id ?? ''),
        10,
      );
      const parentRaw = req.body.parentId ?? req.body.parent_id;
      const parentId =
        parentRaw == null || parentRaw === ''
          ? null
          : parseInt(String(parentRaw), 10);
      const name = isStr(req.body.name);
      const type = normalizeNodeType(req.body.type);
      const displayOrder = parseInt(
        String(req.body.display_order ?? req.body.displayOrder ?? '0'),
        10,
      );
      const totalMeters = isNumOrNull(
        req.body.total_meters ?? req.body.totalMeters,
      );
      const meterPrice = isNumOrNull(
        req.body.meter_price ?? req.body.meterPrice,
      );
      const unitValue = isNumOrNull(
        req.body.unit_value ?? req.body.unitValue,
      );

      if (Number.isNaN(projectId)) {
        return res.status(400).json({ error: 'projectId required' });
      }
      if (!name) return res.status(400).json({ error: 'name required' });
      if (!type) {
        return res.status(400).json({ error: 'type must be folder or work_site' });
      }
      if (parentId != null && Number.isNaN(parentId)) {
        return res.status(400).json({ error: 'invalid parentId' });
      }

      const mt = await pool.query(
        `SELECT measure_type FROM invoice_structure_projects WHERE project_id = $1`,
        [projectId],
      );
      if (!mt.rows.length) {
        return res.status(400).json({
          error: 'measure_type must be set before adding locations',
        });
      }

      if (parentId != null) {
        const parent = await pool.query(
          `SELECT id, project_id FROM invoice_structure_locations WHERE id = $1`,
          [parentId],
        );
        if (!parent.rows.length) {
          return res.status(400).json({ error: 'parent not found' });
        }
        if (parseInt(parent.rows[0].project_id, 10) !== projectId) {
          return res.status(400).json({ error: 'parent project mismatch' });
        }
      }

      const r = await pool.query(
        `INSERT INTO invoice_structure_locations (
          project_id, parent_id, name, type, display_order,
          total_meters, meter_price, unit_value
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
        RETURNING id`,
        [
          projectId,
          parentId,
          name,
          type,
          Number.isFinite(displayOrder) ? displayOrder : 0,
          totalMeters,
          meterPrice,
          unitValue,
        ],
      );
      return res.json(parseInt(r.rows[0].id, 10));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/invoice-structure/locations/:id', async (req, res) => {
    try {
      const user = await requireAppAdmin(pool, req, res);
      if (!user) return;

      const id = parseInt(String(req.params.id || ''), 10);
      if (Number.isNaN(id)) {
        return res.status(400).json({ error: 'invalid id' });
      }

      const existing = await pool.query(
        `SELECT * FROM invoice_structure_locations WHERE id = $1`,
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }
      const row = existing.rows[0];

      const name =
        req.body.name != null ? isStr(req.body.name) : row.name;
      if (!name) return res.status(400).json({ error: 'name required' });

      let displayOrder = row.display_order;
      if (
        req.body.display_order != null ||
        req.body.displayOrder != null
      ) {
        const o = parseInt(
          String(req.body.display_order ?? req.body.displayOrder),
          10,
        );
        if (Number.isFinite(o)) displayOrder = o;
      }

      const hasTotal =
        Object.prototype.hasOwnProperty.call(req.body, 'total_meters') ||
        Object.prototype.hasOwnProperty.call(req.body, 'totalMeters');
      const hasPrice =
        Object.prototype.hasOwnProperty.call(req.body, 'meter_price') ||
        Object.prototype.hasOwnProperty.call(req.body, 'meterPrice');
      const hasUnit =
        Object.prototype.hasOwnProperty.call(req.body, 'unit_value') ||
        Object.prototype.hasOwnProperty.call(req.body, 'unitValue');

      const totalMeters = hasTotal
        ? isNumOrNull(req.body.total_meters ?? req.body.totalMeters)
        : row.total_meters == null
          ? null
          : parseFloat(row.total_meters);
      const meterPrice = hasPrice
        ? isNumOrNull(req.body.meter_price ?? req.body.meterPrice)
        : row.meter_price == null
          ? null
          : parseFloat(row.meter_price);
      const unitValue = hasUnit
        ? isNumOrNull(req.body.unit_value ?? req.body.unitValue)
        : row.unit_value == null
          ? null
          : parseFloat(row.unit_value);

      await pool.query(
        `UPDATE invoice_structure_locations
         SET name = $1,
             display_order = $2,
             total_meters = $3,
             meter_price = $4,
             unit_value = $5,
             updated_at = NOW()
         WHERE id = $6`,
        [name, displayOrder, totalMeters, meterPrice, unitValue, id],
      );
      return res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/invoice-structure/locations/:id', async (req, res) => {
    try {
      const user = await requireAppAdmin(pool, req, res);
      if (!user) return;

      const id = parseInt(String(req.params.id || ''), 10);
      if (Number.isNaN(id)) {
        return res.status(400).json({ error: 'invalid id' });
      }
      await pool.query(
        `DELETE FROM invoice_structure_locations WHERE id = $1`,
        [id],
      );
      return res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureInvoiceStructureTables,
  registerInvoiceStructureRoutes,
  importProjectLocationsToInvoiceStructure,
};
