/**
 * بيانات صرف العهدة: إرسال من مهندس الموقع → اعتماد/رفض من مدير المشروعات المحدد.
 * إدخال مدير المشروعات يُحفظ معتمداً مباشرة مع خصم رصيده.
 */

const EXPENSE_APPROVER_EMAIL = 'abdelrhmanellaithy828@gmail.com';
const PRIMARY_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';

const STATUS_PENDING = 'pending';
const STATUS_APPROVED = 'approved';
const STATUS_REJECTED = 'rejected';

function esNormEmail(email) {
  return String(email || '')
    .trim()
    .toLowerCase();
}

function esIsApproverEmail(email) {
  return esNormEmail(email) === EXPENSE_APPROVER_EMAIL;
}

function esIsPrimaryAdminEmail(email) {
  return esNormEmail(email) === PRIMARY_ADMIN_EMAIL;
}

function esParseAmount(raw) {
  const n = parseFloat(String(raw ?? '').replace(/[^\d.]/g, ''));
  return Number.isFinite(n) ? n : 0;
}

function esRowToJson(row) {
  return {
    id: parseInt(row.id, 10),
    submitter_user_id: parseInt(row.submitter_user_id, 10),
    submitter_user_name: row.submitter_user_name || '',
    submitter_role: row.submitter_role || '',
    balance_user_id: parseInt(row.balance_user_id, 10),
    project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
    project_name: row.project_name || null,
    description: row.description || '',
    amount: parseFloat(row.amount) || 0,
    image_path: row.image_path || null,
    status: row.status || STATUS_PENDING,
    rejection_reason: row.rejection_reason || null,
    responded_by_user_id:
      row.responded_by_user_id != null
        ? parseInt(row.responded_by_user_id, 10)
        : null,
    responded_by_user_name: row.responded_by_user_name || null,
    responded_at: row.responded_at || null,
    created_at: row.created_at,
    source: row.source || 'engineer',
  };
}

async function esNotifyUser(pool, userId, fields) {
  const u = await pool.query('SELECT role FROM users WHERE id = $1', [userId]);
  if (!u.rows.length) return;
  const role = String(u.rows[0].role || 'site_engineer');
  await pool.query(
    `INSERT INTO notifications (
      recipient_user_id, recipient_role, title, body, event_type,
      actor_user_id, actor_user_name, project_name, created_at, is_read
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, FALSE)`,
    [
      userId,
      role,
      fields.title,
      fields.body,
      fields.event_type,
      fields.actor_user_id ?? null,
      fields.actor_user_name ?? null,
      fields.project_name ?? null,
      new Date().toISOString(),
    ],
  );
}

async function esNotifyApprover(pool, fields) {
  const r = await pool.query(
    'SELECT id, role FROM users WHERE LOWER(TRIM(email)) = $1 LIMIT 1',
    [EXPENSE_APPROVER_EMAIL],
  );
  if (!r.rows.length) return;
  const row = r.rows[0];
  await pool.query(
    `INSERT INTO notifications (
      recipient_user_id, recipient_role, title, body, event_type,
      actor_user_id, actor_user_name, project_name, created_at, is_read
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, FALSE)`,
    [
      parseInt(row.id, 10),
      String(row.role || 'site_engineer_manager'),
      fields.title,
      fields.body,
      fields.event_type,
      fields.actor_user_id ?? null,
      fields.actor_user_name ?? null,
      fields.project_name ?? null,
      new Date().toISOString(),
    ],
  );
}

async function esDeductBalance(pool, userId, amount) {
  if (!(amount > 0)) return;
  const bal = await pool.query(
    'SELECT balance FROM engineer_balance WHERE user_id = $1',
    [userId],
  );
  const current = bal.rows.length ? parseFloat(bal.rows[0].balance) || 0 : 0;
  await pool.query(
    `INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2)
     ON CONFLICT (user_id) DO UPDATE SET balance = $2`,
    [userId, current - amount],
  );
}

async function esRestoreBalance(pool, userId, amount) {
  if (!(amount > 0)) return;
  const bal = await pool.query(
    'SELECT balance FROM engineer_balance WHERE user_id = $1',
    [userId],
  );
  const current = bal.rows.length ? parseFloat(bal.rows[0].balance) || 0 : 0;
  await pool.query(
    `INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2)
     ON CONFLICT (user_id) DO UPDATE SET balance = $2`,
    [userId, current + amount],
  );
}

async function ensureExpenseStatementsTable(pool) {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS expense_statements (
        id SERIAL PRIMARY KEY,
        submitter_user_id INTEGER NOT NULL REFERENCES users(id),
        submitter_user_name TEXT NOT NULL,
        submitter_role TEXT NOT NULL DEFAULT '',
        balance_user_id INTEGER NOT NULL REFERENCES users(id),
        project_id INTEGER REFERENCES projects(id),
        project_name TEXT,
        description TEXT NOT NULL DEFAULT '',
        amount NUMERIC NOT NULL DEFAULT 0,
        image_path TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        rejection_reason TEXT,
        responded_by_user_id INTEGER REFERENCES users(id),
        responded_by_user_name TEXT,
        responded_at TEXT,
        created_at TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'engineer'
      )
    `);
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_expense_statements_status
       ON expense_statements (status)`,
    );
    await pool.query(
      `CREATE INDEX IF NOT EXISTS idx_expense_statements_created
       ON expense_statements (created_at DESC)`,
    );
    console.log('ensureExpenseStatementsTable: ok');
  } catch (e) {
    console.warn('ensureExpenseStatementsTable:', e.message);
  }
}

function registerExpenseStatementsRoutes(app, pool, { runNotificationSafely } = {}) {
  const safeNotify = async (label, fn) => {
    if (typeof runNotificationSafely === 'function') {
      await runNotificationSafely(label, fn);
    } else {
      try {
        await fn();
      } catch (e) {
        console.warn(label, e.message);
      }
    }
  };

  app.post('/expense-statements', async (req, res) => {
    try {
      const b = req.body || {};
      const userId = parseInt(b.userId, 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const u = await pool.query(
        'SELECT id, name, email, role FROM users WHERE id = $1',
        [userId],
      );
      if (!u.rows.length) {
        return res.status(404).json({ error: 'user not found' });
      }
      const user = u.rows[0];
      const expenses = Array.isArray(b.expenses) ? b.expenses : [];
      const items = expenses
        .map((e) => ({
          description: String(e.description || e.بيان || '').trim(),
          amount: esParseAmount(e.amount),
          image_path: e.image_path || e.imagePath || null,
        }))
        .filter(
          (e) =>
            e.description ||
            e.amount !== 0 ||
            (e.image_path && String(e.image_path).trim()),
        );
      if (!items.length) {
        return res.status(400).json({ error: 'أضف بند صرف واحداً على الأقل' });
      }

      const autoApprove = b.autoApprove === true || b.auto_approve === true;
      const projectIdRaw = b.projectId ?? b.project_id;
      let projectId =
        projectIdRaw != null && String(projectIdRaw).trim() !== ''
          ? parseInt(projectIdRaw, 10)
          : null;
      const projectName =
        (b.projectName || b.project_name || '').toString().trim() || null;

      // مشروع اخر: اسم يدوي فقط — لا يُحفظ معرّف وهمي بسبب FK على projects
      if (projectId != null && (Number.isNaN(projectId) || projectId < 0)) {
        projectId = null;
      }

      if (!autoApprove && projectId == null && !projectName) {
        return res.status(400).json({ error: 'اختر المشروع' });
      }

      const now = new Date().toISOString();
      const status = autoApprove ? STATUS_APPROVED : STATUS_PENDING;
      const source = autoApprove ? 'manager_direct' : 'engineer';
      const ids = [];

      for (const item of items) {
        const ins = await pool.query(
          `INSERT INTO expense_statements (
            submitter_user_id, submitter_user_name, submitter_role,
            balance_user_id, project_id, project_name,
            description, amount, image_path, status,
            responded_by_user_id, responded_by_user_name, responded_at,
            created_at, source
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
          RETURNING id`,
          [
            userId,
            user.name,
            user.role || '',
            userId,
            Number.isNaN(projectId) || projectId == null ? null : projectId,
            projectName,
            item.description,
            item.amount,
            item.image_path,
            status,
            autoApprove ? userId : null,
            autoApprove ? user.name : null,
            autoApprove ? now : null,
            now,
            source,
          ],
        );
        const id = parseInt(ins.rows[0].id, 10);
        ids.push(id);
        if (autoApprove && item.amount > 0) {
          await esDeductBalance(pool, userId, item.amount);
        }
      }

      if (!autoApprove) {
        await safeNotify('expense_statement_submitted', async () => {
          await esNotifyApprover(pool, {
            title: 'بيان صرف جديد بانتظار الاعتماد',
            body:
              `قام "${user.name}" بإرسال ${ids.length} بند صرف` +
              (projectName ? ` — مشروع "${projectName}"` : '') +
              ' بانتظار اعتمادكم.',
            event_type: 'expense_statement_submitted',
            actor_user_id: userId,
            actor_user_name: user.name,
            project_name: projectName,
          });
        });
      }

      res.json({ ok: true, ids, count: ids.length, status });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/expense-statements', async (req, res) => {
    try {
      const statusParam = String(req.query.status || 'all').trim().toLowerCase();
      let sql =
        'SELECT * FROM expense_statements WHERE 1=1';
      const params = [];
      if (statusParam && statusParam !== 'all') {
        const statuses = statusParam
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean);
        if (statuses.length === 1) {
          params.push(statuses[0]);
          sql += ` AND status = $${params.length}`;
        } else if (statuses.length > 1) {
          params.push(statuses);
          sql += ` AND status = ANY($${params.length}::text[])`;
        }
      }
      sql += ' ORDER BY created_at DESC, id DESC';
      const r = await pool.query(sql, params);
      res.json(r.rows.map(esRowToJson));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/expense-statements/:id/respond', async (req, res) => {
    try {
      const id = parseInt(req.params.id, 10);
      const b = req.body || {};
      const actorId = parseInt(b.userId, 10);
      const decision = String(b.decision || '').trim().toLowerCase();
      const reason = String(b.reason || '').trim();

      if (Number.isNaN(id) || Number.isNaN(actorId)) {
        return res.status(400).json({ error: 'id and userId required' });
      }
      if (decision !== 'approve' && decision !== 'reject') {
        return res.status(400).json({ error: 'decision must be approve or reject' });
      }
      if (decision === 'reject' && !reason) {
        return res.status(400).json({ error: 'سبب الرفض مطلوب' });
      }

      const actor = await pool.query(
        'SELECT id, name, email, role FROM users WHERE id = $1',
        [actorId],
      );
      if (!actor.rows.length) {
        return res.status(404).json({ error: 'user not found' });
      }
      if (!esIsApproverEmail(actor.rows[0].email)) {
        return res.status(403).json({ error: 'غير مصرح بالاعتماد أو الرفض' });
      }

      const cur = await pool.query(
        'SELECT * FROM expense_statements WHERE id = $1',
        [id],
      );
      if (!cur.rows.length) {
        return res.status(404).json({ error: 'البيان غير موجود' });
      }
      const row = cur.rows[0];
      if (row.status !== STATUS_PENDING) {
        return res.status(400).json({ error: 'تم البت في هذا البيان مسبقاً' });
      }

      const now = new Date().toISOString();
      const actorName = actor.rows[0].name;
      const amount = parseFloat(row.amount) || 0;
      const projectName = row.project_name || null;
      const submitterId = parseInt(row.submitter_user_id, 10);
      const balanceUserId = parseInt(row.balance_user_id, 10);

      if (decision === 'approve') {
        await pool.query(
          `UPDATE expense_statements SET
            status = $1,
            responded_by_user_id = $2,
            responded_by_user_name = $3,
            responded_at = $4,
            rejection_reason = NULL
           WHERE id = $5`,
          [STATUS_APPROVED, actorId, actorName, now, id],
        );
        if (amount > 0) {
          await esDeductBalance(pool, balanceUserId, amount);
        }
        await safeNotify('expense_statement_approved', async () => {
          await esNotifyUser(pool, submitterId, {
            title: 'تم اعتماد بيان الصرف',
            body:
              `تم اعتماد بيان الصرف الخاص بكم من مدير المشروعات` +
              (row.description
                ? `\nالبيان: ${row.description}`
                : '') +
              `\nالمبلغ: ${amount.toFixed(2)}` +
              (projectName ? `\nالمشروع: ${projectName}` : ''),
            event_type: 'expense_statement_approved',
            actor_user_id: actorId,
            actor_user_name: actorName,
            project_name: projectName,
          });
        });
      } else {
        await pool.query(
          `UPDATE expense_statements SET
            status = $1,
            rejection_reason = $2,
            responded_by_user_id = $3,
            responded_by_user_name = $4,
            responded_at = $5
           WHERE id = $6`,
          [STATUS_REJECTED, reason, actorId, actorName, now, id],
        );
        await safeNotify('expense_statement_rejected', async () => {
          await esNotifyUser(pool, submitterId, {
            title: 'تم رفض بيان الصرف',
            body:
              `تم رفض بيان الصرف الخاص بكم من مدير المشروعات ويجب إعادة إدخاله مرة أخرى.\n` +
              `سبب الرفض: ${reason}` +
              (row.description ? `\nالبيان: ${row.description}` : '') +
              `\nالمبلغ: ${amount.toFixed(2)}`,
            event_type: 'expense_statement_rejected',
            actor_user_id: actorId,
            actor_user_name: actorName,
            project_name: projectName,
          });
        });
      }

      const updated = await pool.query(
        'SELECT * FROM expense_statements WHERE id = $1',
        [id],
      );
      res.json(esRowToJson(updated.rows[0]));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/expense-statements/:id', async (req, res) => {
    try {
      const id = parseInt(req.params.id, 10);
      const actorId = parseInt(req.query.userId, 10);
      if (Number.isNaN(id) || Number.isNaN(actorId)) {
        return res.status(400).json({ error: 'id and userId required' });
      }
      const actor = await pool.query(
        'SELECT id, email FROM users WHERE id = $1',
        [actorId],
      );
      if (!actor.rows.length || !esIsPrimaryAdminEmail(actor.rows[0].email)) {
        return res.status(403).json({ error: 'غير مصرح بالحذف' });
      }
      const cur = await pool.query(
        'SELECT * FROM expense_statements WHERE id = $1',
        [id],
      );
      if (!cur.rows.length) {
        return res.status(404).json({ error: 'البيان غير موجود' });
      }
      const row = cur.rows[0];
      if (row.status === STATUS_APPROVED) {
        const amount = parseFloat(row.amount) || 0;
        if (amount > 0) {
          await esRestoreBalance(
            pool,
            parseInt(row.balance_user_id, 10),
            amount,
          );
        }
      }
      await pool.query('DELETE FROM expense_statements WHERE id = $1', [id]);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureExpenseStatementsTable,
  registerExpenseStatementsRoutes,
  EXPENSE_APPROVER_EMAIL,
  PRIMARY_ADMIN_EMAIL,
};
