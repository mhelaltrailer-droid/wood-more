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

function ciLineTotal(prevQty, currentQty, unitPrice, percent) {
  const totalQty = ciNum(prevQty) + ciNum(currentQty);
  const pct = ciNum(percent, 100);
  return Math.round(totalQty * ciNum(unitPrice) * (pct / 100) * 100) / 100;
}

function ciNormalizeLine(raw, index) {
  const locationLabel = ciStr(raw.location_label ?? raw.locationLabel);
  const description = ciStr(raw.description);
  const unit = ciStr(raw.unit) || 'عدد';
  const prevQty = ciNum(raw.prev_qty ?? raw.prevQty);
  const currentQty = ciNum(raw.current_qty ?? raw.currentQty);
  const totalQty = prevQty + currentQty;
  const unitPrice = ciNum(raw.unit_price ?? raw.unitPrice);
  const percent = ciNum(raw.percent, 100);
  const lineTotal = ciLineTotal(prevQty, currentQty, unitPrice, percent);
  const itemNoRaw = raw.item_no ?? raw.itemNo;
  const itemNo =
    itemNoRaw == null || itemNoRaw === ''
      ? index + 1
      : parseInt(String(itemNoRaw), 10) || index + 1;
  return {
    sort_order: index,
    item_no: itemNo,
    location_label: locationLabel,
    description,
    unit,
    prev_qty: prevQty,
    current_qty: currentQty,
    total_qty: totalQty,
    unit_price: unitPrice,
    percent,
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
      location_label: l.location_label || '',
      description: l.description || '',
      unit: l.unit || 'عدد',
      prev_qty: ciNum(l.prev_qty),
      current_qty: ciNum(l.current_qty),
      total_qty: ciNum(l.total_qty),
      unit_price: ciNum(l.unit_price),
      percent: ciNum(l.percent, 100),
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
        invoice_id, sort_order, item_no, location_label, description, unit,
        prev_qty, current_qty, total_qty, unit_price, percent, line_total
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
      [
        invoiceId,
        line.sort_order,
        line.item_no,
        line.location_label,
        line.description,
        line.unit,
        line.prev_qty,
        line.current_qty,
        line.total_qty,
        line.unit_price,
        line.percent,
        line.line_total,
      ],
    );
  }
  return Math.round(total * 100) / 100;
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
}

function registerContInvoicesRoutes(app, pool) {
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
      const totalAmount = await ciReplaceLines(
        client,
        invoiceId,
        b.lines || [],
      );
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
      const totalAmount = await ciReplaceLines(client, id, b.lines || []);
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
