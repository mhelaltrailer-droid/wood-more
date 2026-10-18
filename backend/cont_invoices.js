/**
 * Cont-Invoices — مستخلصات المقاول (مسودات + بنود كميات/أسعار).
 * المرحلة الحالية: إنشاء/تعديل/حذف للـ app_admin فقط. بدون تداول أو PDF.
 */

const { applyViewAsToUser } = require('./view_as');

function ciNum(raw, fallback = 0) {
  const n = parseFloat(String(raw ?? '').replace(/,/g, ''));
  return Number.isFinite(n) ? n : fallback;
}

function ciStr(raw) {
  return String(raw ?? '').trim();
}

function ciIsAppAdmin(user) {
  return !!user && String(user.role || '').trim() === 'app_admin';
}

async function ciGetUser(pool, userId, req) {
  const r = await pool.query(
    'SELECT id, name, email, role FROM users WHERE id = $1',
    [userId],
  );
  return applyViewAsToUser(r.rows[0] || null, req);
}

const CI_LINE_KINDS = new Set([
  'execution',
  'holiday',
  'transport',
  'deduction',
  'note_on_other',
]);

function ciNormalizeKind(raw) {
  const k = ciStr(raw.line_kind ?? raw.lineKind ?? 'execution').toLowerCase();
  return CI_LINE_KINDS.has(k) ? k : 'execution';
}

function ciExecutionDue(baseQty, unitPrice, prevPercent, percent) {
  const base = ciNum(baseQty) * ciNum(unitPrice);
  const delta = Math.max(0, ciNum(percent) - ciNum(prevPercent));
  return Math.round(base * (delta / 100) * 100) / 100;
}

function ciNormalizeLine(raw, index) {
  const kind = ciNormalizeKind(raw);
  const locationLabel = ciStr(raw.location_label ?? raw.locationLabel);
  const description = ciStr(raw.description);
  const unit = ciStr(raw.unit) || (kind === 'execution' ? 'م2' : 'مقط');
  const prevQty = ciNum(raw.prev_qty ?? raw.prevQty);
  const currentQty = ciNum(raw.current_qty ?? raw.currentQty);
  const baseQtyRaw = raw.base_qty ?? raw.baseQty;
  const baseQty =
    baseQtyRaw == null || baseQtyRaw === ''
      ? prevQty + currentQty
      : ciNum(baseQtyRaw);
  const totalQty = kind === 'execution' ? baseQty : prevQty + currentQty;
  const unitPrice = ciNum(raw.unit_price ?? raw.unitPrice);
  const prevPercent = ciNum(raw.prev_percent ?? raw.prevPercent, 0);
  const percent = ciNum(raw.percent, kind === 'execution' ? 0 : 100);
  const structureLocationIdRaw =
    raw.structure_location_id ?? raw.structureLocationId;
  const structureLocationId =
    structureLocationIdRaw == null || structureLocationIdRaw === ''
      ? null
      : parseInt(String(structureLocationIdRaw), 10);
  const counterpartyIdRaw =
    raw.counterparty_contractor_id ?? raw.counterpartyContractorId;
  const counterpartyContractorId =
    counterpartyIdRaw == null || counterpartyIdRaw === ''
      ? null
      : parseInt(String(counterpartyIdRaw), 10);
  const counterpartyContractorName = ciStr(
    raw.counterparty_contractor_name ?? raw.counterpartyContractorName,
  );
  const deductionKind = ciStr(raw.deduction_kind ?? raw.deductionKind);

  let lineTotal;
  if (kind === 'execution') {
    lineTotal = ciExecutionDue(baseQty, unitPrice, prevPercent, percent);
  } else if (kind === 'deduction') {
    const amt = Math.abs(ciNum(raw.amount ?? unitPrice ?? currentQty));
    lineTotal = -Math.round(amt * 100) / 100;
  } else {
    // holiday | transport | note_on_other
    const amt = Math.abs(ciNum(raw.amount ?? unitPrice ?? currentQty));
    lineTotal = Math.round(amt * 100) / 100;
  }

  const itemNoRaw = raw.item_no ?? raw.itemNo;
  const itemNo =
    itemNoRaw == null || itemNoRaw === ''
      ? index + 1
      : parseInt(String(itemNoRaw), 10) || index + 1;
  return {
    sort_order: index,
    item_no: itemNo,
    line_kind: kind,
    structure_location_id: Number.isFinite(structureLocationId)
      ? structureLocationId
      : null,
    location_label: locationLabel,
    description,
    unit,
    prev_qty: prevQty,
    current_qty: currentQty,
    total_qty: totalQty,
    base_qty: baseQty,
    unit_price: unitPrice,
    prev_percent: prevPercent,
    percent,
    deduction_kind: deductionKind,
    counterparty_contractor_id: Number.isFinite(counterpartyContractorId)
      ? counterpartyContractorId
      : null,
    counterparty_contractor_name: counterpartyContractorName,
    line_total: lineTotal,
  };
}

function ciRowToJson(row, lines = []) {
  const totalAmount = ciNum(row.total_amount);
  const previouslyPaid = ciNum(row.previously_paid);
  const otherDeductions = ciNum(row.other_deductions);
  const amountDue =
    row.amount_due != null
      ? ciNum(row.amount_due)
      : Math.round((totalAmount - previouslyPaid - otherDeductions) * 100) / 100;
  return {
    id: parseInt(row.id, 10),
    contractor_id:
      row.contractor_id != null ? parseInt(row.contractor_id, 10) : null,
    contractor_name: row.contractor_name || '',
    project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
    project_name: row.project_name || '',
    statement_date: row.statement_date
      ? String(row.statement_date).slice(0, 10)
      : null,
    contract_type: row.contract_type || 'تركيب',
    previously_paid: previouslyPaid,
    other_deductions: otherDeductions,
    total_amount: totalAmount,
    amount_due: amountDue,
    notes: row.notes || '',
    status: row.status || 'draft',
    created_by_user_id:
      row.created_by_user_id != null
        ? parseInt(row.created_by_user_id, 10)
        : null,
    created_by_user_name: row.created_by_user_name || '',
    created_at: row.created_at,
    updated_at: row.updated_at,
    lines: lines.map((l) => ({
      id: l.id != null ? parseInt(l.id, 10) : null,
      sort_order: parseInt(l.sort_order, 10) || 0,
      item_no: l.item_no != null ? parseInt(l.item_no, 10) : null,
      line_kind: l.line_kind || 'execution',
      structure_location_id:
        l.structure_location_id != null
          ? parseInt(l.structure_location_id, 10)
          : null,
      location_label: l.location_label || '',
      description: l.description || '',
      unit: l.unit || 'عدد',
      prev_qty: ciNum(l.prev_qty),
      current_qty: ciNum(l.current_qty),
      total_qty: ciNum(l.total_qty),
      base_qty: ciNum(l.base_qty != null ? l.base_qty : l.total_qty),
      unit_price: ciNum(l.unit_price),
      prev_percent: ciNum(l.prev_percent, 0),
      percent: ciNum(l.percent, 100),
      deduction_kind: l.deduction_kind || '',
      counterparty_contractor_id:
        l.counterparty_contractor_id != null
          ? parseInt(l.counterparty_contractor_id, 10)
          : null,
      counterparty_contractor_name: l.counterparty_contractor_name || '',
      line_total: ciNum(l.line_total),
    })),
  };
}

async function ciLoadLines(pool, invoiceId) {
  const r = await pool.query(
    `SELECT * FROM cont_invoice_lines
     WHERE invoice_id = $1
     ORDER BY sort_order ASC, id ASC`,
    [invoiceId],
  );
  return r.rows;
}

async function ciReplaceLines(client, invoiceId, rawLines) {
  await client.query('DELETE FROM cont_invoice_lines WHERE invoice_id = $1', [
    invoiceId,
  ]);
  const lines = Array.isArray(rawLines) ? rawLines : [];
  let total = 0;
  for (let i = 0; i < lines.length; i += 1) {
    const line = ciNormalizeLine(lines[i], i);
    total += line.line_total;
    await client.query(
      `INSERT INTO cont_invoice_lines (
        invoice_id, sort_order, item_no, line_kind, structure_location_id,
        location_label, description, unit,
        prev_qty, current_qty, total_qty, base_qty, unit_price,
        prev_percent, percent, deduction_kind,
        counterparty_contractor_id, counterparty_contractor_name, line_total
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)`,
      [
        invoiceId,
        line.sort_order,
        line.item_no,
        line.line_kind,
        line.structure_location_id,
        line.location_label,
        line.description,
        line.unit,
        line.prev_qty,
        line.current_qty,
        line.total_qty,
        line.base_qty,
        line.unit_price,
        line.prev_percent,
        line.percent,
        line.deduction_kind,
        line.counterparty_contractor_id,
        line.counterparty_contractor_name,
        line.line_total,
      ],
    );
  }
  return Math.round(total * 100) / 100;
}

async function ciSyncStructureFromLines(client, projectId, rawLines) {
  if (!Number.isFinite(projectId)) return;
  const lines = Array.isArray(rawLines) ? rawLines : [];
  for (const raw of lines) {
    const kind = ciNormalizeKind(raw);
    if (kind !== 'execution') continue;
    const locIdRaw = raw.structure_location_id ?? raw.structureLocationId;
    const locId =
      locIdRaw == null || locIdRaw === ''
        ? null
        : parseInt(String(locIdRaw), 10);
    if (!Number.isFinite(locId)) continue;
    const baseQty = ciNum(raw.base_qty ?? raw.baseQty);
    const unitPrice = ciNum(raw.unit_price ?? raw.unitPrice);
    const measure = await client.query(
      `SELECT measure_type FROM invoice_structure_projects WHERE project_id = $1`,
      [projectId],
    );
    const measureType = measure.rows[0]?.measure_type || 'flooring';
    if (measureType === 'wpc') {
      await client.query(
        `UPDATE invoice_structure_locations
         SET unit_value = $1, updated_at = NOW()
         WHERE id = $2 AND project_id = $3`,
        [unitPrice, locId, projectId],
      );
    } else {
      await client.query(
        `UPDATE invoice_structure_locations
         SET total_meters = $1, meter_price = $2, updated_at = NOW()
         WHERE id = $3 AND project_id = $4`,
        [baseQty, unitPrice, locId, projectId],
      );
    }
  }
}

async function ciUpsertPendingFromLines(client, {
  invoiceId,
  projectId,
  beneficiaryContractorId,
  beneficiaryContractorName,
  rawLines,
}) {
  await client.query(
    `DELETE FROM cont_invoice_pending_cross
     WHERE source_invoice_id = $1 AND applied_invoice_id IS NULL`,
    [invoiceId],
  );
  const lines = Array.isArray(rawLines) ? rawLines : [];
  for (const raw of lines) {
    const kind = ciNormalizeKind(raw);
    if (kind !== 'note_on_other') continue;
    const line = ciNormalizeLine(raw, 0);
    if (!(line.line_total > 0) || !line.counterparty_contractor_name) continue;
    await client.query(
      `INSERT INTO cont_invoice_pending_cross (
        project_id, source_invoice_id,
        beneficiary_contractor_id, beneficiary_contractor_name,
        target_contractor_id, target_contractor_name,
        amount, description
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
      [
        Number.isFinite(projectId) ? projectId : null,
        invoiceId,
        Number.isFinite(beneficiaryContractorId) ? beneficiaryContractorId : null,
        beneficiaryContractorName || '',
        line.counterparty_contractor_id,
        line.counterparty_contractor_name,
        line.line_total,
        line.description ||
          `يوميات ملاحظات بالخصم (من ${beneficiaryContractorName || 'مقاول'})`,
      ],
    );
  }
}

async function ciApplyPendingToInvoice(client, {
  invoiceId,
  projectId,
  contractorId,
  contractorName,
  existingLines,
}) {
  const params = [];
  const where = ['applied_invoice_id IS NULL'];
  if (Number.isFinite(contractorId) && contractorName) {
    params.push(contractorId, contractorName);
    where.push(
      `(target_contractor_id = $1 OR LOWER(TRIM(target_contractor_name)) = LOWER(TRIM($2)))`,
    );
  } else if (Number.isFinite(contractorId)) {
    params.push(contractorId);
    where.push(`target_contractor_id = $1`);
  } else if (contractorName) {
    params.push(contractorName);
    where.push(`LOWER(TRIM(target_contractor_name)) = LOWER(TRIM($1))`);
  } else {
    return existingLines;
  }
  if (Number.isFinite(projectId)) {
    params.push(projectId);
    where.push(`(project_id IS NULL OR project_id = $${params.length})`);
  }
  const pending = await client.query(
    `SELECT * FROM cont_invoice_pending_cross
     WHERE ${where.join(' AND ')}
     ORDER BY id ASC`,
    params,
  );
  if (!pending.rows.length) return existingLines;

  const out = Array.isArray(existingLines) ? [...existingLines] : [];
  for (const row of pending.rows) {
    out.push({
      line_kind: 'deduction',
      location_label: '',
      description: row.description || 'خصم معلّق من مقاول آخر',
      unit: 'مقط',
      base_qty: 1,
      unit_price: ciNum(row.amount),
      amount: ciNum(row.amount),
      percent: 100,
      prev_percent: 0,
      deduction_kind: 'أخرى',
    });
    await client.query(
      `UPDATE cont_invoice_pending_cross
       SET applied_invoice_id = $1, applied_at = NOW()
       WHERE id = $2`,
      [invoiceId, row.id],
    );
  }
  return out;
}

async function ensureContInvoicesTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_invoices (
      id SERIAL PRIMARY KEY,
      contractor_id INTEGER REFERENCES contractors(id) ON DELETE SET NULL,
      contractor_name TEXT NOT NULL DEFAULT '',
      project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
      project_name TEXT NOT NULL DEFAULT '',
      statement_date DATE,
      contract_type TEXT NOT NULL DEFAULT 'تركيب',
      previously_paid NUMERIC(14,2) NOT NULL DEFAULT 0,
      other_deductions NUMERIC(14,2) NOT NULL DEFAULT 0,
      total_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      amount_due NUMERIC(14,2) NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT 'draft',
      created_by_user_id INTEGER,
      created_by_user_name TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_invoice_lines (
      id SERIAL PRIMARY KEY,
      invoice_id INTEGER NOT NULL REFERENCES cont_invoices(id) ON DELETE CASCADE,
      sort_order INTEGER NOT NULL DEFAULT 0,
      item_no INTEGER,
      location_label TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      unit TEXT NOT NULL DEFAULT 'عدد',
      prev_qty NUMERIC(14,4) NOT NULL DEFAULT 0,
      current_qty NUMERIC(14,4) NOT NULL DEFAULT 0,
      total_qty NUMERIC(14,4) NOT NULL DEFAULT 0,
      unit_price NUMERIC(14,4) NOT NULL DEFAULT 0,
      percent NUMERIC(8,2) NOT NULL DEFAULT 100,
      line_total NUMERIC(14,2) NOT NULL DEFAULT 0
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_invoices_status
    ON cont_invoices (status, updated_at DESC)
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_invoice_lines_invoice
    ON cont_invoice_lines (invoice_id, sort_order)
  `);
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS line_kind TEXT NOT NULL DEFAULT 'execution'`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS structure_location_id INTEGER`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS base_qty NUMERIC(14,4) NOT NULL DEFAULT 0`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS prev_percent NUMERIC(8,2) NOT NULL DEFAULT 0`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS deduction_kind TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS counterparty_contractor_id INTEGER`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS counterparty_contractor_name TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_invoice_pending_cross (
      id SERIAL PRIMARY KEY,
      project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
      source_invoice_id INTEGER REFERENCES cont_invoices(id) ON DELETE CASCADE,
      beneficiary_contractor_id INTEGER,
      beneficiary_contractor_name TEXT NOT NULL DEFAULT '',
      target_contractor_id INTEGER,
      target_contractor_name TEXT NOT NULL DEFAULT '',
      amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      description TEXT NOT NULL DEFAULT '',
      applied_invoice_id INTEGER REFERENCES cont_invoices(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      applied_at TIMESTAMPTZ
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_pending_cross_target
    ON cont_invoice_pending_cross (target_contractor_id, applied_invoice_id)
  `);
}

function registerContInvoicesRoutes(app, pool) {
  /**
   * آخر نسبة تنفيذ لموقع في هيكلة المستخلصات (لنفس المقاول/المشروع).
   */
  app.get('/cont-invoices/location-progress', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const projectId = parseInt(String(req.query.projectId || ''), 10);
      const structureLocationId = parseInt(
        String(req.query.structureLocationId || ''),
        10,
      );
      const contractorIdRaw = req.query.contractorId;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const contractorName = ciStr(req.query.contractorName);
      const excludeIdRaw = req.query.excludeId;
      const excludeId =
        excludeIdRaw == null || excludeIdRaw === ''
          ? null
          : parseInt(String(excludeIdRaw), 10);

      if (!Number.isFinite(projectId) || !Number.isFinite(structureLocationId)) {
        return res.status(400).json({
          error: 'projectId and structureLocationId required',
        });
      }

      const params = [projectId, structureLocationId];
      let sql = `
        SELECT l.percent, l.prev_percent, l.base_qty, l.unit_price, l.line_total,
               i.id AS invoice_id, i.statement_date
        FROM cont_invoice_lines l
        INNER JOIN cont_invoices i ON i.id = l.invoice_id
        WHERE i.project_id = $1
          AND l.structure_location_id = $2
          AND l.line_kind = 'execution'`;
      if (Number.isFinite(contractorId) && contractorName) {
        params.push(contractorId, contractorName);
        sql += ` AND (i.contractor_id = $3 OR LOWER(TRIM(i.contractor_name)) = LOWER(TRIM($4)))`;
      } else if (Number.isFinite(contractorId)) {
        params.push(contractorId);
        sql += ` AND i.contractor_id = $3`;
      } else if (contractorName) {
        params.push(contractorName);
        sql += ` AND LOWER(TRIM(i.contractor_name)) = LOWER(TRIM($3))`;
      }
      if (Number.isFinite(excludeId)) {
        params.push(excludeId);
        sql += ` AND i.id <> $${params.length}`;
      }
      sql += `
        ORDER BY COALESCE(i.statement_date, i.created_at::date) DESC, i.id DESC, l.id DESC
        LIMIT 1`;

      const r = await pool.query(sql, params);
      if (!r.rows.length) {
        return res.json({
          has_previous: false,
          prev_percent: 0,
          base_qty: null,
          unit_price: null,
        });
      }
      const row = r.rows[0];
      return res.json({
        has_previous: true,
        prev_percent: ciNum(row.percent),
        base_qty: ciNum(row.base_qty),
        unit_price: ciNum(row.unit_price),
        from_invoice_id: parseInt(row.invoice_id, 10),
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /**
   * السابق صرفه المقترح لمقاول:
   * - أول مستخلص → 0 (إدخال يدوي)
   * - بعد ذلك → إجمالي آخر مستخلص لنفس المقاول
   */
  app.get('/cont-invoices/previous-paid', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const contractorIdRaw = req.query.contractorId ?? req.query.contractor_id;
      const contractorName = ciStr(
        req.query.contractorName ?? req.query.contractor_name,
      );
      const excludeIdRaw = req.query.excludeId ?? req.query.exclude_id;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const excludeId =
        excludeIdRaw == null || excludeIdRaw === ''
          ? null
          : parseInt(String(excludeIdRaw), 10);

      if (!Number.isFinite(contractorId) && !contractorName) {
        return res.json({
          previously_paid: 0,
          has_previous: false,
          from_invoice_id: null,
          from_total_amount: 0,
        });
      }

      const whereParts = [];
      const qparams = [];
      if (Number.isFinite(contractorId) && contractorName) {
        qparams.push(contractorId, contractorName);
        whereParts.push(
          `(contractor_id = $1 OR LOWER(TRIM(contractor_name)) = LOWER(TRIM($2)))`,
        );
        if (Number.isFinite(excludeId)) {
          qparams.push(excludeId);
          whereParts.push(`id <> $3`);
        }
      } else if (Number.isFinite(contractorId)) {
        qparams.push(contractorId);
        whereParts.push(`contractor_id = $1`);
        if (Number.isFinite(excludeId)) {
          qparams.push(excludeId);
          whereParts.push(`id <> $2`);
        }
      } else {
        qparams.push(contractorName);
        whereParts.push(
          `LOWER(TRIM(contractor_name)) = LOWER(TRIM($1))`,
        );
        if (Number.isFinite(excludeId)) {
          qparams.push(excludeId);
          whereParts.push(`id <> $2`);
        }
      }

      const r = await pool.query(
        `SELECT id, total_amount, previously_paid, amount_due, statement_date
         FROM cont_invoices
         WHERE ${whereParts.join(' AND ')}
         ORDER BY
           COALESCE(statement_date, created_at::date) DESC,
           updated_at DESC,
           id DESC
         LIMIT 1`,
        qparams,
      );

      if (!r.rows.length) {
        return res.json({
          previously_paid: 0,
          has_previous: false,
          from_invoice_id: null,
          from_total_amount: 0,
        });
      }
      const row = r.rows[0];
      const totalAmount = ciNum(row.total_amount);
      return res.json({
        previously_paid: totalAmount,
        has_previous: true,
        from_invoice_id: parseInt(row.id, 10),
        from_total_amount: totalAmount,
        statement_date: row.statement_date
          ? String(row.statement_date).slice(0, 10)
          : null,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/cont-invoices', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const r = await pool.query(
        `SELECT * FROM cont_invoices
         ORDER BY updated_at DESC, id DESC`,
      );
      res.json(r.rows.map((row) => ciRowToJson(row)));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/cont-invoices/:id', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      const id = parseInt(String(req.params.id || ''), 10);
      if (Number.isNaN(userId) || Number.isNaN(id)) {
        return res.status(400).json({ error: 'userId and id required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const r = await pool.query('SELECT * FROM cont_invoices WHERE id = $1', [
        id,
      ]);
      if (!r.rows.length) return res.status(404).json({ error: 'not found' });
      const lines = await ciLoadLines(pool, id);
      res.json(ciRowToJson(r.rows[0], lines));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/cont-invoices', async (req, res) => {
    const client = await pool.connect();
    try {
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const contractorName = ciStr(b.contractor_name ?? b.contractorName);
      const projectName = ciStr(b.project_name ?? b.projectName);
      if (!contractorName) {
        return res.status(400).json({ error: 'contractor_name required' });
      }
      if (!projectName) {
        return res.status(400).json({ error: 'project_name required' });
      }

      const contractorIdRaw = b.contractor_id ?? b.contractorId;
      const projectIdRaw = b.project_id ?? b.projectId;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const projectId =
        projectIdRaw == null || projectIdRaw === ''
          ? null
          : parseInt(String(projectIdRaw), 10);
      const statementDate = ciStr(b.statement_date ?? b.statementDate) || null;
      const contractType =
        ciStr(b.contract_type ?? b.contractType) || 'تركيب';
      const previouslyPaid = ciNum(b.previously_paid ?? b.previouslyPaid);
      const otherDeductions = ciNum(b.other_deductions ?? b.otherDeductions);
      const notes = ciStr(b.notes);

      await client.query('BEGIN');
      const ins = await client.query(
        `INSERT INTO cont_invoices (
          contractor_id, contractor_name, project_id, project_name,
          statement_date, contract_type, previously_paid, other_deductions,
          notes, status, created_by_user_id, created_by_user_name
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'draft',$10,$11)
        RETURNING *`,
        [
          Number.isFinite(contractorId) ? contractorId : null,
          contractorName,
          Number.isFinite(projectId) ? projectId : null,
          projectName,
          statementDate,
          contractType,
          previouslyPaid,
          otherDeductions,
          notes,
          userId,
          user.name || '',
        ],
      );
      const invoiceId = parseInt(ins.rows[0].id, 10);
      let linesPayload = b.lines || [];
      linesPayload = await ciApplyPendingToInvoice(client, {
        invoiceId,
        projectId: Number.isFinite(projectId) ? projectId : null,
        contractorId: Number.isFinite(contractorId) ? contractorId : null,
        contractorName,
        existingLines: linesPayload,
      });
      const totalAmount = await ciReplaceLines(client, invoiceId, linesPayload);
      await ciSyncStructureFromLines(
        client,
        Number.isFinite(projectId) ? projectId : null,
        linesPayload,
      );
      await ciUpsertPendingFromLines(client, {
        invoiceId,
        projectId: Number.isFinite(projectId) ? projectId : null,
        beneficiaryContractorId: Number.isFinite(contractorId)
          ? contractorId
          : null,
        beneficiaryContractorName: contractorName,
        rawLines: linesPayload,
      });
      const amountDue =
        Math.round((totalAmount - previouslyPaid - otherDeductions) * 100) /
        100;
      const upd = await client.query(
        `UPDATE cont_invoices
         SET total_amount = $1, amount_due = $2, updated_at = NOW()
         WHERE id = $3
         RETURNING *`,
        [totalAmount, amountDue, invoiceId],
      );
      await client.query('COMMIT');
      const lines = await ciLoadLines(pool, invoiceId);
      res.status(201).json(ciRowToJson(upd.rows[0], lines));
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  app.put('/cont-invoices/:id', async (req, res) => {
    const client = await pool.connect();
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) {
        return res.status(400).json({ error: 'id and userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const existing = await pool.query(
        'SELECT id FROM cont_invoices WHERE id = $1',
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }

      const contractorName = ciStr(b.contractor_name ?? b.contractorName);
      const projectName = ciStr(b.project_name ?? b.projectName);
      if (!contractorName) {
        return res.status(400).json({ error: 'contractor_name required' });
      }
      if (!projectName) {
        return res.status(400).json({ error: 'project_name required' });
      }

      const contractorIdRaw = b.contractor_id ?? b.contractorId;
      const projectIdRaw = b.project_id ?? b.projectId;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const projectId =
        projectIdRaw == null || projectIdRaw === ''
          ? null
          : parseInt(String(projectIdRaw), 10);
      const statementDate = ciStr(b.statement_date ?? b.statementDate) || null;
      const contractType =
        ciStr(b.contract_type ?? b.contractType) || 'تركيب';
      const previouslyPaid = ciNum(b.previously_paid ?? b.previouslyPaid);
      const otherDeductions = ciNum(b.other_deductions ?? b.otherDeductions);
      const notes = ciStr(b.notes);

      await client.query('BEGIN');
      await client.query(
        `UPDATE cont_invoices SET
          contractor_id = $1,
          contractor_name = $2,
          project_id = $3,
          project_name = $4,
          statement_date = $5,
          contract_type = $6,
          previously_paid = $7,
          other_deductions = $8,
          notes = $9,
          updated_at = NOW()
         WHERE id = $10`,
        [
          Number.isFinite(contractorId) ? contractorId : null,
          contractorName,
          Number.isFinite(projectId) ? projectId : null,
          projectName,
          statementDate,
          contractType,
          previouslyPaid,
          otherDeductions,
          notes,
          id,
        ],
      );
      const linesPayload = b.lines || [];
      const totalAmount = await ciReplaceLines(client, id, linesPayload);
      await ciSyncStructureFromLines(
        client,
        Number.isFinite(projectId) ? projectId : null,
        linesPayload,
      );
      await ciUpsertPendingFromLines(client, {
        invoiceId: id,
        projectId: Number.isFinite(projectId) ? projectId : null,
        beneficiaryContractorId: Number.isFinite(contractorId)
          ? contractorId
          : null,
        beneficiaryContractorName: contractorName,
        rawLines: linesPayload,
      });
      const amountDue =
        Math.round((totalAmount - previouslyPaid - otherDeductions) * 100) /
        100;
      const upd = await client.query(
        `UPDATE cont_invoices
         SET total_amount = $1, amount_due = $2, updated_at = NOW()
         WHERE id = $3
         RETURNING *`,
        [totalAmount, amountDue, id],
      );
      await client.query('COMMIT');
      const lines = await ciLoadLines(pool, id);
      res.json(ciRowToJson(upd.rows[0], lines));
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  app.delete('/cont-invoices/:id', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) {
        return res.status(400).json({ error: 'id and userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const r = await pool.query(
        'DELETE FROM cont_invoices WHERE id = $1 RETURNING id',
        [id],
      );
      if (!r.rows.length) return res.status(404).json({ error: 'not found' });
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureContInvoicesTables,
  registerContInvoicesRoutes,
};
