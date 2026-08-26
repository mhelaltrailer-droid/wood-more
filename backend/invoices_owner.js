const { formatArDateTimeEgypt } = require('./egypt_local_time');

const IO_CREATOR_EMAIL = 'ah-amin';
const IO_PRIMARY_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';
const IO_MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024;
const IO_MAX_ATTACHMENTS = 4;

const IO_STATUS = {
  PENDING_QS: 'pending_qs',
  PENDING_TO: 'pending_technical_office',
  PENDING_PM: 'pending_projects_manager',
  PENDING_FINANCE: 'pending_finance',
  PENDING_OM: 'pending_operation_manager',
  RETURNED_CREATOR: 'returned_to_creator',
  APPROVED: 'approved',
};

/** ترتيب الاعتماد: بعد الإنشاء يبدأ من QS. */
const IO_FLOW = [
  { status: IO_STATUS.PENDING_QS, role: 'qs' },
  { status: IO_STATUS.PENDING_TO, role: 'technical_office' },
  { status: IO_STATUS.PENDING_PM, role: 'projects_manager' },
  { status: IO_STATUS.PENDING_FINANCE, role: 'finance' },
  { status: IO_STATUS.PENDING_OM, role: 'operation_manager' },
];

const ioFormatArDateTime = formatArDateTimeEgypt;

async function ensureInvoicesOwnerTables(pool) {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS invoices_owner (
        id SERIAL PRIMARY KEY,
        project_id INTEGER REFERENCES projects(id),
        project_name TEXT NOT NULL DEFAULT '',
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'pending_qs',
        created_by_user_id INTEGER NOT NULL REFERENCES users(id),
        created_by_user_name TEXT NOT NULL DEFAULT '',
        current_assignee_user_id INTEGER REFERENCES users(id),
        current_assignee_user_name TEXT,
        return_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        approved_at TEXT
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS invoices_owner_attachments (
        id SERIAL PRIMARY KEY,
        invoice_id INTEGER NOT NULL REFERENCES invoices_owner(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        data_base64 TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS invoices_owner_actions (
        id SERIAL PRIMARY KEY,
        invoice_id INTEGER NOT NULL REFERENCES invoices_owner(id) ON DELETE CASCADE,
        actor_user_id INTEGER NOT NULL REFERENCES users(id),
        actor_user_name TEXT NOT NULL,
        action TEXT NOT NULL,
        comment TEXT,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS invoices_owner_notifications (
        id SERIAL PRIMARY KEY,
        recipient_user_id INTEGER NOT NULL REFERENCES users(id),
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        invoice_id INTEGER REFERENCES invoices_owner(id) ON DELETE CASCADE,
        created_at TEXT NOT NULL,
        is_read BOOLEAN NOT NULL DEFAULT FALSE,
        read_at TEXT
      )
    `);
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_invoices_owner_status_assignee
      ON invoices_owner (status, current_assignee_user_id)
    `).catch(() => {});
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_invoices_owner_creator_status
      ON invoices_owner (created_by_user_id, status)
    `).catch(() => {});
    console.log('ensureInvoicesOwnerTables: ok');
  } catch (e) {
    console.warn('ensureInvoicesOwnerTables:', e.message);
  }
}

function ioIsCreatorEmail(email) {
  return String(email || '').trim().toLowerCase() === IO_CREATOR_EMAIL;
}

function ioIsCreatorUser(user) {
  return !!user && ioIsCreatorEmail(user.email);
}

function ioIsPrimaryAdmin(user) {
  if (!user) return false;
  return String(user.email || '').trim().toLowerCase() === IO_PRIMARY_ADMIN_EMAIL;
}

function ioIsOperationManager(user) {
  if (!user) return false;
  return String(user.role || '').trim() === 'operation_manager';
}

/** سجل التداول: المسؤول الأساسي + مدير العمليات فقط. */
function ioCanViewActivityLog(user) {
  return ioIsPrimaryAdmin(user) || ioIsOperationManager(user);
}

function ioCanAccessModule(user) {
  if (!user) return false;
  if (ioIsCreatorUser(user) || ioIsPrimaryAdmin(user)) return true;
  const role = String(user.role || '').trim();
  return (
    role === 'qs' ||
    role === 'technical_office' ||
    role === 'projects_manager' ||
    role === 'finance' ||
    role === 'operation_manager'
  );
}

function ioFlowIndexForStatus(status) {
  return IO_FLOW.findIndex((s) => s.status === status);
}

function ioRoleForStatus(status) {
  const step = IO_FLOW.find((s) => s.status === status);
  return step ? step.role : null;
}

async function ioGetUser(pool, userId) {
  const r = await pool.query('SELECT id, name, email, role FROM users WHERE id = $1', [userId]);
  return r.rows[0] || null;
}

async function ioGetUserByRole(pool, role) {
  const r = await pool.query(
    `SELECT id, name, email, role FROM users
     WHERE role = $1
     ORDER BY id ASC
     LIMIT 1`,
    [role],
  );
  return r.rows[0] || null;
}

async function ioResolveAssigneeForStatus(pool, status, row) {
  if (status === IO_STATUS.RETURNED_CREATOR) {
    return {
      id: parseInt(row.created_by_user_id, 10),
      name: row.created_by_user_name || '',
    };
  }
  if (status === IO_STATUS.APPROVED) {
    return { id: null, name: null };
  }
  const role = ioRoleForStatus(status);
  if (!role) return null;
  const user = await ioGetUserByRole(pool, role);
  if (!user) return null;
  return { id: parseInt(user.id, 10), name: user.name };
}

function ioCanActOnStatus(user, status, row) {
  if (!user || !row) return false;
  const userId = parseInt(user.id, 10);
  if (status === IO_STATUS.RETURNED_CREATOR) {
    return parseInt(row.created_by_user_id, 10) === userId && ioIsCreatorUser(user);
  }
  if (status === IO_STATUS.APPROVED) return false;
  const role = ioRoleForStatus(status);
  if (!role) return false;
  if (String(user.role || '').trim() !== role) return false;
  const assigneeId = row.current_assignee_user_id != null
    ? parseInt(row.current_assignee_user_id, 10)
    : null;
  if (assigneeId != null && assigneeId !== userId) {
    // أي مستخدم بنفس دور الخطوة يمكنه التصرف إن تطابق الدور.
  }
  return true;
}

async function ioInsertAction(pool, fields) {
  const now = fields.createdAt || new Date().toISOString();
  await pool.query(
    `INSERT INTO invoices_owner_actions (
      invoice_id, actor_user_id, actor_user_name, action, comment, created_at
    ) VALUES ($1,$2,$3,$4,$5,$6)`,
    [
      fields.invoiceId,
      fields.actorUserId,
      fields.actorUserName,
      fields.action,
      fields.comment || null,
      now,
    ],
  );
}

async function ioNotifyUser(pool, runNotificationSafely, userId, fields) {
  if (userId == null || Number.isNaN(userId)) return;
  await runNotificationSafely('invoicesOwnerNotify', async () => {
    const now = new Date().toISOString();
    await pool.query(
      `INSERT INTO invoices_owner_notifications (
        recipient_user_id, title, body, invoice_id, created_at, is_read
      ) VALUES ($1,$2,$3,$4,$5,FALSE)`,
      [userId, fields.title, fields.body, fields.invoiceId ?? null, now],
    );
  });
}

function ioMapRow(row, attachments = [], actions = []) {
  return {
    id: parseInt(row.id, 10),
    project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
    project_name: row.project_name || '',
    notes: row.notes || '',
    status: row.status,
    created_by_user_id: parseInt(row.created_by_user_id, 10),
    created_by_user_name: row.created_by_user_name || '',
    current_assignee_user_id: row.current_assignee_user_id != null
      ? parseInt(row.current_assignee_user_id, 10)
      : null,
    current_assignee_user_name: row.current_assignee_user_name || null,
    return_reason: row.return_reason || null,
    created_at: row.created_at,
    updated_at: row.updated_at,
    approved_at: row.approved_at || null,
    attachments,
    actions,
  };
}

async function ioLoadDetail(pool, invoiceId) {
  const r = await pool.query('SELECT * FROM invoices_owner WHERE id = $1', [invoiceId]);
  if (r.rows.length === 0) return null;
  const row = r.rows[0];
  const att = await pool.query(
    `SELECT id, file_name, mime_type, size_bytes, created_at
     FROM invoices_owner_attachments WHERE invoice_id = $1 ORDER BY id`,
    [invoiceId],
  );
  const act = await pool.query(
    `SELECT * FROM invoices_owner_actions WHERE invoice_id = $1 ORDER BY created_at ASC, id ASC`,
    [invoiceId],
  );
  return ioMapRow(
    row,
    att.rows.map((a) => ({
      id: parseInt(a.id, 10),
      file_name: a.file_name,
      mime_type: a.mime_type,
      size_bytes: parseInt(a.size_bytes, 10),
      created_at: a.created_at,
    })),
    act.rows.map((a) => ({
      id: parseInt(a.id, 10),
      actor_user_id: parseInt(a.actor_user_id, 10),
      actor_user_name: a.actor_user_name,
      action: a.action,
      comment: a.comment,
      created_at: a.created_at,
    })),
  );
}

async function ioResolveProject(pool, body) {
  const projectIdRaw = body.projectId ?? body.project_id;
  const manualName = String(body.projectName ?? body.project_name ?? '').trim();
  const hasProjectId = projectIdRaw != null &&
    projectIdRaw !== '' &&
    projectIdRaw !== -1 &&
    projectIdRaw !== 'other';

  if (!hasProjectId) {
    if (!manualName) return { error: 'project_name_required' };
    return { project_id: null, project_name: manualName };
  }

  const projectId = parseInt(String(projectIdRaw), 10);
  if (Number.isNaN(projectId)) return { error: 'project_required' };
  const pr = await pool.query('SELECT id, name FROM projects WHERE id = $1', [projectId]);
  if (pr.rows.length === 0) return { error: 'project_not_found' };
  return {
    project_id: parseInt(pr.rows[0].id, 10),
    project_name: String(pr.rows[0].name || ''),
  };
}

function ioIsAllowedFile(mime, name) {
  const m = String(mime || '').toLowerCase();
  const n = String(name || '').toLowerCase();
  const isPdf = m === 'application/pdf' || n.endsWith('.pdf');
  const isExcel =
    m === 'application/vnd.ms-excel' ||
    m === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
    m === 'application/vnd.ms-excel.sheet.macroenabled.12' ||
    n.endsWith('.xls') ||
    n.endsWith('.xlsx') ||
    n.endsWith('.xlsm');
  return isPdf || isExcel;
}

function ioValidateAttachments(attachments) {
  if (!Array.isArray(attachments)) return { error: 'invalid_attachments' };
  if (attachments.length === 0) return { error: 'attachments_required' };
  if (attachments.length > IO_MAX_ATTACHMENTS) return { error: 'too_many_attachments' };
  for (const a of attachments) {
    const mime = String(a.mime_type ?? a.mimeType ?? '');
    const name = String(a.file_name ?? a.fileName ?? '');
    const size = parseInt(String(a.size_bytes ?? a.sizeBytes ?? '0'), 10);
    if (!ioIsAllowedFile(mime, name)) return { error: 'invalid_file_type' };
    if (size <= 0 || size > IO_MAX_ATTACHMENT_BYTES) return { error: 'file_too_large' };
    const data = String(a.data_base64 ?? a.dataBase64 ?? '').trim();
    if (!data) return { error: 'attachment_data_required' };
  }
  return { ok: true };
}

async function ioInsertAttachments(pool, invoiceId, attachments, now) {
  for (const a of attachments) {
    await pool.query(
      `INSERT INTO invoices_owner_attachments (
        invoice_id, file_name, mime_type, data_base64, size_bytes, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6)`,
      [
        invoiceId,
        String(a.file_name ?? a.fileName ?? 'file'),
        String(a.mime_type ?? a.mimeType ?? 'application/octet-stream'),
        String(a.data_base64 ?? a.dataBase64 ?? ''),
        parseInt(String(a.size_bytes ?? a.sizeBytes ?? '0'), 10),
        now,
      ],
    );
  }
}

async function ioDeleteAttachments(pool, invoiceId) {
  await pool.query('DELETE FROM invoices_owner_attachments WHERE invoice_id = $1', [invoiceId]);
}

function ioNotificationBody(actorName, verb, projectName, whenIso) {
  const when = ioFormatArDateTime(whenIso);
  return `قام ${actorName} ب${verb} مستخلص «${projectName}» — يوم ${when}`;
}

function ioPendingStatusForRole(role) {
  const step = IO_FLOW.find((s) => s.role === role);
  return step ? step.status : null;
}

function registerInvoicesOwnerRoutes(app, pool, deps) {
  const { runNotificationSafely } = deps;

  app.get('/invoices-owner/pending-count', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
      const user = await ioGetUser(pool, userId);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ioCanAccessModule(user)) return res.json({ count: 0 });

      let sql;
      let params;
      if (ioIsCreatorUser(user)) {
        sql = `SELECT COUNT(*)::int AS count FROM invoices_owner
               WHERE created_by_user_id = $1 AND status = $2`;
        params = [userId, IO_STATUS.RETURNED_CREATOR];
      } else if (ioIsPrimaryAdmin(user)) {
        // اطلاع فقط — لا عدّاد إجراءات معلّقة
        return res.json({ count: 0 });
      } else {
        const status = ioPendingStatusForRole(String(user.role || ''));
        if (!status) return res.json({ count: 0 });
        sql = `SELECT COUNT(*)::int AS count FROM invoices_owner WHERE status = $1`;
        params = [status];
      }
      const r = await pool.query(sql, params);
      res.json({ count: r.rows[0]?.count ?? 0 });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/invoices-owner/inbox', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      const tab = String(req.query.tab || 'pending').trim().toLowerCase();
      if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
      const user = await ioGetUser(pool, userId);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ioCanAccessModule(user)) return res.status(403).json({ error: 'forbidden' });

      const role = String(user.role || '');
      let sql;
      let params;

      if (tab === 'pending') {
        if (ioIsCreatorUser(user)) {
          sql = `SELECT * FROM invoices_owner
                 WHERE created_by_user_id = $1 AND status = $2`;
          params = [userId, IO_STATUS.RETURNED_CREATOR];
        } else if (ioIsPrimaryAdmin(user)) {
          sql = `SELECT * FROM invoices_owner WHERE status <> $1`;
          params = [IO_STATUS.APPROVED];
        } else {
          const status = ioPendingStatusForRole(role);
          if (!status) return res.status(403).json({ error: 'forbidden' });
          sql = `SELECT * FROM invoices_owner WHERE status = $1`;
          params = [status];
        }
      } else if (tab === 'sent') {
        if (!ioIsCreatorUser(user)) return res.status(403).json({ error: 'forbidden' });
        sql = `SELECT * FROM invoices_owner
               WHERE created_by_user_id = $1
                 AND status NOT IN ($2, $3)`;
        params = [userId, IO_STATUS.RETURNED_CREATOR, IO_STATUS.APPROVED];
      } else if (tab === 'approved') {
        sql = `SELECT * FROM invoices_owner WHERE status = $1`;
        params = [IO_STATUS.APPROVED];
      } else if (tab === 'all') {
        sql = `SELECT * FROM invoices_owner WHERE 1=1`;
        params = [];
      } else {
        return res.status(400).json({ error: 'invalid tab' });
      }

      if (tab === 'approved') {
        sql += ' ORDER BY approved_at DESC NULLS LAST, updated_at DESC';
      } else {
        sql += ' ORDER BY updated_at DESC';
      }

      const r = params.length ? await pool.query(sql, params) : await pool.query(sql);
      res.json(r.rows.map((row) => ioMapRow(row)));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/invoices-owner/notifications', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (!Number.isInteger(userId)) return res.status(400).json({ error: 'userId required' });
      const user = await ioGetUser(pool, userId);
      if (!ioCanAccessModule(user)) return res.status(403).json({ error: 'forbidden' });
      const r = await pool.query(
        `SELECT * FROM invoices_owner_notifications
         WHERE recipient_user_id = $1
         ORDER BY created_at DESC`,
        [userId],
      );
      res.json(
        r.rows.map((row) => ({
          id: parseInt(row.id, 10),
          recipient_user_id: parseInt(row.recipient_user_id, 10),
          title: row.title,
          body: row.body,
          invoice_id: row.invoice_id != null ? parseInt(row.invoice_id, 10) : null,
          created_at: row.created_at,
          is_read: row.is_read === true,
          read_at: row.read_at,
        })),
      );
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/invoices-owner/notifications/unread-count', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (!Number.isInteger(userId)) return res.status(400).json({ error: 'userId required' });
      const user = await ioGetUser(pool, userId);
      if (!ioCanAccessModule(user)) return res.json({ count: 0 });
      const r = await pool.query(
        `SELECT COUNT(*)::int AS count FROM invoices_owner_notifications
         WHERE recipient_user_id = $1 AND is_read = FALSE`,
        [userId],
      );
      res.json({ count: parseInt(r.rows[0]?.count || '0', 10) });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/invoices-owner/notifications/:id/read', async (req, res) => {
    try {
      const notificationId = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.body?.userId || req.query?.userId || ''), 10);
      if (!Number.isInteger(notificationId) || !Number.isInteger(userId)) {
        return res.status(400).json({ error: 'invalid' });
      }
      const user = await ioGetUser(pool, userId);
      if (!ioCanAccessModule(user)) return res.status(403).json({ error: 'forbidden' });
      await pool.query(
        `UPDATE invoices_owner_notifications
         SET is_read = TRUE, read_at = $1
         WHERE id = $2 AND recipient_user_id = $3`,
        [new Date().toISOString(), notificationId, userId],
      );
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/invoices-owner/activity-log', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
      const user = await ioGetUser(pool, userId);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ioCanViewActivityLog(user)) return res.status(403).json({ error: 'forbidden' });

      const r = await pool.query(
        `SELECT a.id, a.invoice_id, a.actor_user_id, a.actor_user_name,
                a.action, a.comment, a.created_at,
                i.project_name, i.status AS invoice_status
         FROM invoices_owner_actions a
         INNER JOIN invoices_owner i ON i.id = a.invoice_id
         ORDER BY a.created_at DESC, a.id DESC
         LIMIT 500`,
      );
      res.json(
        r.rows.map((row) => ({
          id: parseInt(row.id, 10),
          invoice_id: parseInt(row.invoice_id, 10),
          actor_user_id: parseInt(row.actor_user_id, 10),
          actor_user_name: row.actor_user_name,
          action: row.action,
          comment: row.comment || null,
          created_at: row.created_at,
          project_name: row.project_name || '',
          invoice_status: row.invoice_status || '',
        })),
      );
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/invoices-owner/:id', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
      const detail = await ioLoadDetail(pool, id);
      if (!detail) return res.status(404).json({ error: 'not found' });
      res.json(detail);
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/invoices-owner/:id/attachments/:attachmentId', async (req, res) => {
    try {
      const invoiceId = parseInt(String(req.params.id || ''), 10);
      const attachmentId = parseInt(String(req.params.attachmentId || ''), 10);
      if (Number.isNaN(invoiceId) || Number.isNaN(attachmentId)) {
        return res.status(400).json({ error: 'invalid' });
      }
      const r = await pool.query(
        `SELECT file_name, mime_type, data_base64 FROM invoices_owner_attachments
         WHERE id = $1 AND invoice_id = $2`,
        [attachmentId, invoiceId],
      );
      if (r.rows.length === 0) return res.status(404).json({ error: 'not found' });
      res.json({
        file_name: r.rows[0].file_name,
        mime_type: r.rows[0].mime_type,
        data_base64: r.rows[0].data_base64,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/invoices-owner', async (req, res) => {
    try {
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
      const actor = await ioGetUser(pool, userId);
      if (!actor || !ioIsCreatorUser(actor)) {
        return res.status(403).json({ error: 'forbidden' });
      }

      const qs = await ioGetUserByRole(pool, 'qs');
      if (!qs) return res.status(400).json({ error: 'qs_not_configured' });

      const project = await ioResolveProject(pool, b);
      if (project.error) return res.status(400).json({ error: project.error });
      const notes = b.notes != null ? String(b.notes).trim() : '';
      const attachments = Array.isArray(b.attachments) ? b.attachments : [];
      const attCheck = ioValidateAttachments(attachments);
      if (attCheck.error) return res.status(400).json({ error: attCheck.error });

      const now = new Date().toISOString();
      const ins = await pool.query(
        `INSERT INTO invoices_owner (
          project_id, project_name, notes, status,
          created_by_user_id, created_by_user_name,
          current_assignee_user_id, current_assignee_user_name,
          created_at, updated_at
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$9) RETURNING id`,
        [
          project.project_id,
          project.project_name,
          notes || null,
          IO_STATUS.PENDING_QS,
          userId,
          actor.name,
          parseInt(qs.id, 10),
          qs.name,
          now,
        ],
      );
      const invoiceId = parseInt(ins.rows[0].id, 10);
      await ioInsertAttachments(pool, invoiceId, attachments, now);
      await ioInsertAction(pool, {
        invoiceId,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'created',
        comment: notes || null,
        createdAt: now,
      });

      const title = 'Invoices (Owner) — طلب جديد';
      const body = ioNotificationBody(actor.name, 'رفع', project.project_name, now);
      await ioNotifyUser(pool, runNotificationSafely, parseInt(qs.id, 10), {
        title,
        body,
        invoiceId,
      });

      res.status(201).json(await ioLoadDetail(pool, invoiceId));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/invoices-owner/:id', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });

      const rq = await pool.query('SELECT * FROM invoices_owner WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
      const row = rq.rows[0];
      if (parseInt(row.created_by_user_id, 10) !== userId) {
        return res.status(403).json({ error: 'forbidden' });
      }
      if (String(row.status) !== IO_STATUS.RETURNED_CREATOR) {
        return res.status(400).json({ error: 'not_editable' });
      }

      const actor = await ioGetUser(pool, userId);
      if (!actor || !ioIsCreatorUser(actor)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      const qs = await ioGetUserByRole(pool, 'qs');
      if (!qs) return res.status(400).json({ error: 'qs_not_configured' });

      const project = await ioResolveProject(pool, b);
      if (project.error) return res.status(400).json({ error: project.error });
      const notes = b.notes != null ? String(b.notes).trim() : '';
      const attachments = Array.isArray(b.attachments) ? b.attachments : [];
      const attCheck = ioValidateAttachments(attachments);
      if (attCheck.error) return res.status(400).json({ error: attCheck.error });

      const now = new Date().toISOString();
      await pool.query(
        `UPDATE invoices_owner SET project_id=$1, project_name=$2, notes=$3,
         status=$4, return_reason=NULL,
         current_assignee_user_id=$5, current_assignee_user_name=$6,
         updated_at=$7 WHERE id=$8`,
        [
          project.project_id,
          project.project_name,
          notes || null,
          IO_STATUS.PENDING_QS,
          parseInt(qs.id, 10),
          qs.name,
          now,
          id,
        ],
      );
      await ioDeleteAttachments(pool, id);
      await ioInsertAttachments(pool, id, attachments, now);
      await ioInsertAction(pool, {
        invoiceId: id,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'resubmit',
        comment: notes || null,
        createdAt: now,
      });

      const title = 'Invoices (Owner) — إعادة إرسال';
      const body = ioNotificationBody(actor.name, 'إعادة إرسال', project.project_name, now);
      await ioNotifyUser(pool, runNotificationSafely, parseInt(qs.id, 10), {
        title,
        body,
        invoiceId: id,
      });

      res.json(await ioLoadDetail(pool, id));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/invoices-owner/:id/approve', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      const approveNotes = String(b.notes ?? b.comment ?? '').trim();
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });

      const rq = await pool.query('SELECT * FROM invoices_owner WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
      const row = rq.rows[0];
      const actor = await ioGetUser(pool, userId);
      if (!ioCanActOnStatus(actor, row.status, row)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      if (String(row.status) === IO_STATUS.RETURNED_CREATOR) {
        return res.status(400).json({ error: 'use_resubmit' });
      }
      if (String(row.status) === IO_STATUS.APPROVED) {
        return res.status(400).json({ error: 'already_approved' });
      }

      const idx = ioFlowIndexForStatus(row.status);
      if (idx < 0) return res.status(400).json({ error: 'invalid_status' });

      const now = new Date().toISOString();
      let nextStatus;
      let assigneeId = null;
      let assigneeName = null;
      let approvedAt = null;

      if (idx === IO_FLOW.length - 1) {
        nextStatus = IO_STATUS.APPROVED;
        approvedAt = now;
      } else {
        nextStatus = IO_FLOW[idx + 1].status;
        const assignee = await ioResolveAssigneeForStatus(pool, nextStatus, row);
        if (!assignee || assignee.id == null) {
          return res.status(400).json({ error: 'next_assignee_not_configured' });
        }
        assigneeId = assignee.id;
        assigneeName = assignee.name;
      }

      await pool.query(
        `UPDATE invoices_owner SET
         status=$1, return_reason=NULL,
         current_assignee_user_id=$2, current_assignee_user_name=$3,
         approved_at=COALESCE($4, approved_at), updated_at=$5
         WHERE id=$6`,
        [nextStatus, assigneeId, assigneeName, approvedAt, now, id],
      );
      await ioInsertAction(pool, {
        invoiceId: id,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'approve',
        comment: approveNotes || null,
        createdAt: now,
      });

      const title = nextStatus === IO_STATUS.APPROVED
        ? 'Invoices (Owner) — معتمد'
        : 'Invoices (Owner) — بانتظار اعتمادكم';
      const body = ioNotificationBody(
        actor.name,
        nextStatus === IO_STATUS.APPROVED ? 'اعتماد' : 'اعتماد وإحالة',
        row.project_name,
        now,
      );
      if (assigneeId != null) {
        await ioNotifyUser(pool, runNotificationSafely, assigneeId, {
          title,
          body,
          invoiceId: id,
        });
      } else {
        await ioNotifyUser(pool, runNotificationSafely, parseInt(row.created_by_user_id, 10), {
          title,
          body,
          invoiceId: id,
        });
      }

      res.json(await ioLoadDetail(pool, id));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/invoices-owner/:id/return', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      const reason = String(b.reason ?? b.comment ?? '').trim();
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });
      if (!reason) return res.status(400).json({ error: 'reason_required' });

      const rq = await pool.query('SELECT * FROM invoices_owner WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
      const row = rq.rows[0];
      const actor = await ioGetUser(pool, userId);
      if (!ioCanActOnStatus(actor, row.status, row)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      if (String(row.status) === IO_STATUS.RETURNED_CREATOR ||
          String(row.status) === IO_STATUS.APPROVED) {
        return res.status(400).json({ error: 'cannot_return' });
      }

      const idx = ioFlowIndexForStatus(row.status);
      if (idx < 0) return res.status(400).json({ error: 'invalid_status' });

      let prevStatus;
      if (idx === 0) {
        prevStatus = IO_STATUS.RETURNED_CREATOR;
      } else {
        prevStatus = IO_FLOW[idx - 1].status;
      }

      const assignee = await ioResolveAssigneeForStatus(pool, prevStatus, row);
      if (!assignee || assignee.id == null) {
        return res.status(400).json({ error: 'prev_assignee_not_configured' });
      }

      const now = new Date().toISOString();
      await pool.query(
        `UPDATE invoices_owner SET
         status=$1, return_reason=$2,
         current_assignee_user_id=$3, current_assignee_user_name=$4,
         updated_at=$5
         WHERE id=$6`,
        [prevStatus, reason, assignee.id, assignee.name, now, id],
      );
      await ioInsertAction(pool, {
        invoiceId: id,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'return',
        comment: reason,
        createdAt: now,
      });

      const title = 'Invoices (Owner) — إعادة + مراجعة';
      const body = `${ioNotificationBody(actor.name, 'إعادة', row.project_name, now)}\nالسبب: ${reason}`;
      await ioNotifyUser(pool, runNotificationSafely, assignee.id, {
        title,
        body,
        invoiceId: id,
      });

      res.json(await ioLoadDetail(pool, id));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/invoices-owner/:id/attachments/:attachmentId', async (req, res) => {
    try {
      const invoiceId = parseInt(String(req.params.id || ''), 10);
      const attachmentId = parseInt(String(req.params.attachmentId || ''), 10);
      const userId = parseInt(String(req.query.userId || req.body?.userId || ''), 10);
      if (Number.isNaN(invoiceId) || Number.isNaN(attachmentId) || Number.isNaN(userId)) {
        return res.status(400).json({ error: 'invalid' });
      }
      const actor = await ioGetUser(pool, userId);
      if (!ioIsPrimaryAdmin(actor)) return res.status(403).json({ error: 'forbidden' });

      const del = await pool.query(
        `DELETE FROM invoices_owner_attachments
         WHERE id = $1 AND invoice_id = $2
         RETURNING id`,
        [attachmentId, invoiceId],
      );
      if (del.rows.length === 0) return res.status(404).json({ error: 'not found' });

      const now = new Date().toISOString();
      await pool.query(
        `UPDATE invoices_owner SET updated_at = $1 WHERE id = $2`,
        [now, invoiceId],
      );
      await ioInsertAction(pool, {
        invoiceId,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'delete_attachment',
        comment: `attachment#${attachmentId}`,
        createdAt: now,
      });

      res.json(await ioLoadDetail(pool, invoiceId));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/invoices-owner/:id', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.query.userId || req.body?.userId || ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) {
        return res.status(400).json({ error: 'invalid' });
      }
      const actor = await ioGetUser(pool, userId);
      if (!ioIsPrimaryAdmin(actor)) return res.status(403).json({ error: 'forbidden' });

      const rq = await pool.query('SELECT id FROM invoices_owner WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });

      await pool.query('DELETE FROM invoices_owner WHERE id = $1', [id]);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureInvoicesOwnerTables,
  registerInvoicesOwnerRoutes,
  IO_CREATOR_EMAIL,
  IO_PRIMARY_ADMIN_EMAIL,
  IO_STATUS,
  IO_MAX_ATTACHMENTS,
  IO_MAX_ATTACHMENT_BYTES,
};
