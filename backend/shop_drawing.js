const SHOP_DRAWING_PM_EMAIL = 'abdelrhmanellaithy828@gmail.com';
const SHOP_DRAWING_PRIMARY_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';
const SHOP_DRAWING_MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024;
const SHOP_DRAWING_MAX_ATTACHMENTS = 10;
const SHOP_DRAWING_DOC_SHOP = 'shop_drawing';
const SHOP_DRAWING_DOC_PO = 'po';

function shopDrawingNormalizeDocumentType(raw) {
  const t = String(raw ?? SHOP_DRAWING_DOC_SHOP).trim().toLowerCase();
  return t === SHOP_DRAWING_DOC_PO ? SHOP_DRAWING_DOC_PO : SHOP_DRAWING_DOC_SHOP;
}

function shopDrawingTypeLabel(documentType) {
  return documentType === SHOP_DRAWING_DOC_PO ? 'PO' : 'Shop-Drawing';
}

function shopDrawingNotifyTitle(documentType, suffix) {
  return `${shopDrawingTypeLabel(documentType)} — ${suffix}`;
}

function shopDrawingAppendDocumentTypeFilter(sql, documentType, params) {
  params.push(documentType);
  return `${sql} AND document_type = $${params.length}`;
}

function shopDrawingFormatArDateTime(iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const date = d.toLocaleDateString('ar-EG', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  const time = d.toLocaleTimeString('ar-EG', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  });
  return `${date} — ${time}`;
}

async function ensureShopDrawingTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS shop_drawings (
      id SERIAL PRIMARY KEY,
      project_id INTEGER REFERENCES projects(id),
      project_name TEXT NOT NULL DEFAULT '',
      notes TEXT,
      status TEXT NOT NULL DEFAULT 'pending_pm',
      created_by_user_id INTEGER NOT NULL REFERENCES users(id),
      created_by_user_name TEXT NOT NULL DEFAULT '',
      current_assignee_user_id INTEGER REFERENCES users(id),
      current_assignee_user_name TEXT,
      return_reason TEXT,
      document_type TEXT NOT NULL DEFAULT 'shop_drawing',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      approved_at TEXT
    )
  `);
  await pool.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'shop_drawings' AND column_name = 'document_type'
      ) THEN
        ALTER TABLE shop_drawings
          ADD COLUMN document_type TEXT NOT NULL DEFAULT 'shop_drawing';
      END IF;
    END $$
  `).catch(() => {});
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_shop_drawings_document_type_status
    ON shop_drawings (document_type, status)
  `).catch(() => {});
  await pool.query(`
    CREATE TABLE IF NOT EXISTS shop_drawing_attachments (
      id SERIAL PRIMARY KEY,
      drawing_id INTEGER NOT NULL REFERENCES shop_drawings(id) ON DELETE CASCADE,
      file_name TEXT NOT NULL,
      mime_type TEXT NOT NULL,
      data_base64 TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at TEXT NOT NULL
    )
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS shop_drawing_actions (
      id SERIAL PRIMARY KEY,
      drawing_id INTEGER NOT NULL REFERENCES shop_drawings(id) ON DELETE CASCADE,
      actor_user_id INTEGER NOT NULL REFERENCES users(id),
      actor_user_name TEXT NOT NULL,
      action TEXT NOT NULL,
      comment TEXT,
      created_at TEXT NOT NULL
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_shop_drawings_status_assignee
    ON shop_drawings (status, current_assignee_user_id)
  `).catch(() => {});
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_shop_drawings_creator_status
    ON shop_drawings (created_by_user_id, status)
  `).catch(() => {});
  await pool.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'shop_darwing_notifications' AND column_name = 'shop_drawing_id'
      ) THEN
        ALTER TABLE shop_darwing_notifications ADD COLUMN shop_drawing_id INTEGER;
      END IF;
    END $$
  `).catch(() => {});
  await pool.query(`
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'shop_drawings' AND column_name = 'external_url'
      ) THEN
        ALTER TABLE shop_drawings ADD COLUMN external_url TEXT;
      END IF;
    END $$
  `).catch(() => {});
  console.log('ensureShopDrawingTables: ok');
}

async function shopDrawingGetUser(pool, userId) {
  const r = await pool.query('SELECT id, name, email, role FROM users WHERE id = $1', [userId]);
  return r.rows[0] || null;
}

async function shopDrawingGetPmUser(pool) {
  const r = await pool.query(
    `SELECT id, name, email, role FROM users
     WHERE LOWER(TRIM(email)) = $1 LIMIT 1`,
    [SHOP_DRAWING_PM_EMAIL.toLowerCase()],
  );
  return r.rows[0] || null;
}

async function shopDrawingGetBellRecipientIds(pool) {
  const r = await pool.query(
    `SELECT id FROM users
     WHERE role = 'operation_manager'
        OR LOWER(TRIM(email)) = $1`,
    [SHOP_DRAWING_PRIMARY_ADMIN_EMAIL.toLowerCase()],
  );
  return r.rows.map((row) => parseInt(row.id, 10));
}

function shopDrawingIsBellUser(user) {
  if (!user) return false;
  const email = String(user.email || '').trim().toLowerCase();
  return (
    String(user.role || '') === 'operation_manager' ||
    email === SHOP_DRAWING_PRIMARY_ADMIN_EMAIL.toLowerCase()
  );
}

function shopDrawingIsModuleNotificationUser(user) {
  if (!user) return false;
  const email = String(user.email || '').trim().toLowerCase();
  return (
    String(user.role || '') === 'technical_office' ||
    email === SHOP_DRAWING_PM_EMAIL.toLowerCase()
  );
}

async function shopDrawingInsertAction(pool, fields) {
  const now = fields.createdAt || new Date().toISOString();
  await pool.query(
    `INSERT INTO shop_drawing_actions (
      drawing_id, actor_user_id, actor_user_name, action, comment, created_at
    ) VALUES ($1,$2,$3,$4,$5,$6)`,
    [
      fields.drawingId,
      fields.actorUserId,
      fields.actorUserName,
      fields.action,
      fields.comment || null,
      now,
    ],
  );
}

async function shopDrawingNotifyBellUsers(pool, runNotificationSafely, fields) {
  await runNotificationSafely('shopDrawingNotifyBellUsers', async () => {
    const ids = await shopDrawingGetBellRecipientIds(pool);
    const now = new Date().toISOString();
    for (const recipientId of ids) {
      await pool.query(
        `INSERT INTO shop_darwing_notifications (
          recipient_user_id, title, body, shop_drawing_id, created_at, is_read
        ) VALUES ($1,$2,$3,$4,$5,FALSE)`,
        [recipientId, fields.title, fields.body, fields.shopDrawingId ?? null, now],
      );
    }
  });
}

async function shopDrawingNotifyModuleUser(pool, runNotificationSafely, userId, fields) {
  await runNotificationSafely('shopDrawingNotifyModuleUser', async () => {
    const now = new Date().toISOString();
    await pool.query(
      `INSERT INTO shop_darwing_notifications (
        recipient_user_id, title, body, shop_drawing_id, created_at, is_read
      ) VALUES ($1,$2,$3,$4,$5,FALSE)`,
      [userId, fields.title, fields.body, fields.shopDrawingId ?? null, now],
    );
  });
}

function shopDrawingMapRow(row, attachments = [], actions = []) {
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
    document_type: shopDrawingNormalizeDocumentType(row.document_type),
    external_url: row.external_url || null,
    created_at: row.created_at,
    updated_at: row.updated_at,
    approved_at: row.approved_at || null,
    attachments,
    actions,
  };
}

async function shopDrawingLoadActionsForDrawings(pool, drawingIds) {
  if (!drawingIds.length) return new Map();
  const r = await pool.query(
    `SELECT * FROM shop_drawing_actions
     WHERE drawing_id = ANY($1::int[])
     ORDER BY drawing_id, created_at ASC, id ASC`,
    [drawingIds],
  );
  const byDrawing = new Map();
  for (const a of r.rows) {
    const drawingId = parseInt(a.drawing_id, 10);
    if (!byDrawing.has(drawingId)) byDrawing.set(drawingId, []);
    byDrawing.get(drawingId).push({
      id: parseInt(a.id, 10),
      actor_user_id: parseInt(a.actor_user_id, 10),
      actor_user_name: a.actor_user_name,
      action: a.action,
      comment: a.comment,
      created_at: a.created_at,
    });
  }
  return byDrawing;
}

async function shopDrawingMapRowsWithActions(pool, rows) {
  const ids = rows.map((row) => parseInt(row.id, 10));
  const actionsByDrawing = await shopDrawingLoadActionsForDrawings(pool, ids);
  return rows.map((row) => {
    const drawingId = parseInt(row.id, 10);
    return shopDrawingMapRow(row, [], actionsByDrawing.get(drawingId) || []);
  });
}

async function shopDrawingLoadDetail(pool, drawingId) {
  const r = await pool.query('SELECT * FROM shop_drawings WHERE id = $1', [drawingId]);
  if (r.rows.length === 0) return null;
  const row = r.rows[0];
  const att = await pool.query(
    `SELECT id, file_name, mime_type, size_bytes, created_at
     FROM shop_drawing_attachments WHERE drawing_id = $1 ORDER BY id`,
    [drawingId],
  );
  const act = await pool.query(
    `SELECT * FROM shop_drawing_actions WHERE drawing_id = $1 ORDER BY created_at ASC, id ASC`,
    [drawingId],
  );
  return shopDrawingMapRow(
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

async function shopDrawingResolveProject(pool, body) {
  const projectIdRaw = body.projectId ?? body.project_id;
  const manualName = String(body.projectName ?? body.project_name ?? '').trim();
  const hasProjectId = projectIdRaw != null &&
    projectIdRaw !== '' &&
    projectIdRaw !== -1 &&
    projectIdRaw !== 'other';

  if (!hasProjectId) {
    if (!manualName) return { error: 'project_name_required' };
    return {
      project_id: null,
      project_name: manualName,
    };
  }

  const projectId = parseInt(String(projectIdRaw), 10);
  if (Number.isNaN(projectId)) {
    return { error: 'project_required' };
  }
  const pr = await pool.query('SELECT id, name FROM projects WHERE id = $1', [projectId]);
  if (pr.rows.length === 0) return { error: 'project_not_found' };
  return {
    project_id: parseInt(pr.rows[0].id, 10),
    project_name: String(pr.rows[0].name || ''),
  };
}

function shopDrawingNormalizeExternalUrl(raw) {
  const url = String(raw ?? '').trim();
  if (!url) return null;
  let normalized = url;
  if (!/^https?:\/\//i.test(normalized)) {
    normalized = `https://${normalized}`;
  }
  try {
    const parsed = new URL(normalized);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return { error: 'invalid_url' };
    }
    if (!parsed.host) return { error: 'invalid_url' };
    return { url: parsed.toString() };
  } catch (_) {
    return { error: 'invalid_url' };
  }
}

function shopDrawingValidateAttachmentsList(attachments) {
  if (!Array.isArray(attachments)) {
    return { error: 'invalid_attachments' };
  }
  if (attachments.length === 0) return { ok: true, empty: true };
  if (attachments.length > SHOP_DRAWING_MAX_ATTACHMENTS) {
    return { error: 'too_many_attachments' };
  }
  for (const a of attachments) {
    const mime = String(a.mime_type ?? a.mimeType ?? '').toLowerCase();
    const name = String(a.file_name ?? a.fileName ?? '').toLowerCase();
    const size = parseInt(String(a.size_bytes ?? a.sizeBytes ?? '0'), 10);
    const isPdf = mime === 'application/pdf' || name.endsWith('.pdf');
    const isDmg = mime === 'application/x-apple-diskimage' ||
      (mime === 'application/octet-stream' && name.endsWith('.dmg')) ||
      name.endsWith('.dmg');
    const isImage = mime.startsWith('image/') ||
      name.endsWith('.jpg') || name.endsWith('.jpeg') ||
      name.endsWith('.png') || name.endsWith('.gif') || name.endsWith('.webp');
    if (!isPdf && !isDmg && !isImage) return { error: 'invalid_file_type' };
    if (size <= 0 || size > SHOP_DRAWING_MAX_ATTACHMENT_BYTES) {
      return { error: 'file_too_large' };
    }
    const data = String(a.data_base64 ?? a.dataBase64 ?? '').trim();
    if (!data) return { error: 'attachment_data_required' };
  }
  return { ok: true, empty: false };
}

function shopDrawingValidateContent(attachments, externalUrlRaw) {
  const urlResult = shopDrawingNormalizeExternalUrl(externalUrlRaw);
  if (urlResult?.error) return urlResult;
  const attResult = shopDrawingValidateAttachmentsList(
    Array.isArray(attachments) ? attachments : [],
  );
  if (attResult.error) return attResult;
  const hasUrl = urlResult?.url != null;
  const hasFiles = Array.isArray(attachments) && attachments.length > 0;
  if (!hasUrl && !hasFiles) {
    return { error: 'file_or_url_required' };
  }
  return { ok: true, externalUrl: urlResult?.url ?? null };
}

function shopDrawingValidateAttachments(attachments) {
  return shopDrawingValidateContent(attachments, null);
}

async function shopDrawingInsertAttachments(pool, drawingId, attachments, now) {
  for (const a of attachments) {
    await pool.query(
      `INSERT INTO shop_drawing_attachments (
        drawing_id, file_name, mime_type, data_base64, size_bytes, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6)`,
      [
        drawingId,
        String(a.file_name ?? a.fileName ?? 'file'),
        String(a.mime_type ?? a.mimeType ?? 'application/octet-stream'),
        String(a.data_base64 ?? a.dataBase64 ?? ''),
        parseInt(String(a.size_bytes ?? a.sizeBytes ?? '0'), 10),
        now,
      ],
    );
  }
}

async function shopDrawingDeleteAttachments(pool, drawingId) {
  await pool.query('DELETE FROM shop_drawing_attachments WHERE drawing_id = $1', [drawingId]);
}

function shopDrawingNotificationBody(actorName, verb, projectName, whenIso) {
  const when = shopDrawingFormatArDateTime(whenIso);
  return `قام ${actorName} ب${verb} رسمة مشروع «${projectName}» — يوم ${when}`;
}

function registerShopDrawingRoutes(app, pool, deps) {
  const { runNotificationSafely } = deps;

  async function assertBellUser(userId) {
    const user = await shopDrawingGetUser(pool, userId);
    if (!shopDrawingIsBellUser(user)) {
      const err = new Error('forbidden');
      err.status = 403;
      throw err;
    }
    return user;
  }

  async function assertModuleNotificationUser(userId) {
    const user = await shopDrawingGetUser(pool, userId);
    if (!shopDrawingIsModuleNotificationUser(user)) {
      const err = new Error('forbidden');
      err.status = 403;
      throw err;
    }
    return user;
  }

  app.get('/shop-drawing/pending-count', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
      const user = await shopDrawingGetUser(pool, userId);
      if (!user) return res.status(404).json({ error: 'user not found' });

      let sql;
      let params;
      const email = String(user.email || '').trim().toLowerCase();
      if (String(user.role) === 'technical_office') {
        sql = `SELECT COUNT(*)::int AS count FROM shop_drawings
               WHERE created_by_user_id = $1 AND status = 'returned_to_to'`;
        params = [userId];
      } else if (email === SHOP_DRAWING_PM_EMAIL.toLowerCase()) {
        sql = `SELECT COUNT(*)::int AS count FROM shop_drawings
               WHERE status = 'pending_pm' AND current_assignee_user_id = $1`;
        params = [userId];
      } else if (String(user.role) === 'operation_manager') {
        sql = `SELECT COUNT(*)::int AS count FROM shop_drawings WHERE status = 'pending_om'`;
        params = [];
      } else if (email === SHOP_DRAWING_PRIMARY_ADMIN_EMAIL.toLowerCase()) {
        sql = `SELECT COUNT(*)::int AS count FROM shop_drawings WHERE status = 'pending_om'`;
        params = [];
      } else {
        return res.json({ count: 0 });
      }

      const r = params.length
        ? await pool.query(sql, params)
        : await pool.query(sql);
      res.json({ count: r.rows[0]?.count ?? 0 });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/shop-drawing/inbox', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      const tab = String(req.query.tab || 'pending').trim().toLowerCase();
      const documentType = shopDrawingNormalizeDocumentType(
        req.query.documentType ?? req.query.document_type,
      );
      if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
      const user = await shopDrawingGetUser(pool, userId);
      if (!user) return res.status(404).json({ error: 'user not found' });

      const email = String(user.email || '').trim().toLowerCase();
      const role = String(user.role || '');
      let sql;
      let params;

      if (tab === 'pending') {
        if (role === 'technical_office') {
          sql = `SELECT * FROM shop_drawings
                 WHERE created_by_user_id = $1 AND status = 'returned_to_to'`;
          params = [userId];
        } else if (email === SHOP_DRAWING_PM_EMAIL.toLowerCase()) {
          sql = `SELECT * FROM shop_drawings
                 WHERE status = 'pending_pm' AND current_assignee_user_id = $1`;
          params = [userId];
        } else if (role === 'operation_manager' || email === SHOP_DRAWING_PRIMARY_ADMIN_EMAIL.toLowerCase()) {
          sql = `SELECT * FROM shop_drawings WHERE status = 'pending_om'`;
          params = [];
        } else {
          return res.status(403).json({ error: 'forbidden' });
        }
      } else if (tab === 'sent') {
        if (role !== 'technical_office') return res.status(403).json({ error: 'forbidden' });
        sql = `SELECT * FROM shop_drawings
               WHERE created_by_user_id = $1 AND status IN ('pending_pm', 'pending_om')`;
        params = [userId];
      } else if (tab === 'approved') {
        const canView =
          role === 'technical_office' ||
          role === 'top_management' ||
          email === SHOP_DRAWING_PM_EMAIL.toLowerCase() ||
          role === 'operation_manager' ||
          email === SHOP_DRAWING_PRIMARY_ADMIN_EMAIL.toLowerCase();
        if (!canView) return res.status(403).json({ error: 'forbidden' });
        sql = `SELECT * FROM shop_drawings WHERE status = 'approved'`;
        params = [];
      } else if (tab === 'all') {
        const canViewAll =
          role === 'operation_manager' ||
          role === 'top_management' ||
          email === SHOP_DRAWING_PRIMARY_ADMIN_EMAIL.toLowerCase();
        if (!canViewAll) return res.status(403).json({ error: 'forbidden' });
        sql = `SELECT * FROM shop_drawings WHERE 1=1`;
        params = [];
      } else {
        return res.status(400).json({ error: 'invalid tab' });
      }

      sql = shopDrawingAppendDocumentTypeFilter(sql, documentType, params);
      if (tab === 'approved') {
        sql += ' ORDER BY approved_at DESC NULLS LAST, updated_at DESC';
      } else {
        sql += ' ORDER BY updated_at DESC';
      }

      const r = params.length ? await pool.query(sql, params) : await pool.query(sql);
      const includeActions =
        role === 'top_management' && (tab === 'approved' || tab === 'all');
      if (includeActions) {
        res.json(await shopDrawingMapRowsWithActions(pool, r.rows));
      } else {
        res.json(r.rows.map((row) => shopDrawingMapRow(row)));
      }
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/shop-drawing/module-notifications', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      const documentType = shopDrawingNormalizeDocumentType(
        req.query.documentType ?? req.query.document_type,
      );
      if (!Number.isInteger(userId)) return res.status(400).json({ error: 'userId required' });
      await assertModuleNotificationUser(userId);
      const r = await pool.query(
        `SELECT n.* FROM shop_darwing_notifications n
         LEFT JOIN shop_drawings sd ON sd.id = n.shop_drawing_id
         WHERE n.recipient_user_id = $1
           AND (
             sd.document_type = $2
             OR (n.shop_drawing_id IS NULL AND $2 = $3)
           )
         ORDER BY n.created_at DESC`,
        [userId, documentType, SHOP_DRAWING_DOC_SHOP],
      );
      res.json(
        r.rows.map((row) => ({
          id: parseInt(row.id, 10),
          recipient_user_id: parseInt(row.recipient_user_id, 10),
          title: row.title,
          body: row.body,
          shop_drawing_id: row.shop_drawing_id != null ? parseInt(row.shop_drawing_id, 10) : null,
          created_at: row.created_at,
          is_read: row.is_read === true,
          read_at: row.read_at,
        })),
      );
    } catch (e) {
      res.status(e.status || 500).json({ error: String(e.message) });
    }
  });

  app.get('/shop-drawing/module-notifications/unread-count', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      const documentType = shopDrawingNormalizeDocumentType(
        req.query.documentType ?? req.query.document_type,
      );
      if (!Number.isInteger(userId)) return res.status(400).json({ error: 'userId required' });
      await assertModuleNotificationUser(userId);
      const r = await pool.query(
        `SELECT COUNT(*)::int AS count FROM shop_darwing_notifications n
         LEFT JOIN shop_drawings sd ON sd.id = n.shop_drawing_id
         WHERE n.recipient_user_id = $1 AND n.is_read = FALSE
           AND (
             sd.document_type = $2
             OR (n.shop_drawing_id IS NULL AND $2 = $3)
           )`,
        [userId, documentType, SHOP_DRAWING_DOC_SHOP],
      );
      res.json({ count: parseInt(r.rows[0]?.count || '0', 10) });
    } catch (e) {
      res.status(e.status || 500).json({ error: String(e.message) });
    }
  });

  app.put('/shop-drawing/module-notifications/:id/read', async (req, res) => {
    try {
      const notificationId = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.body?.userId || req.query?.userId || ''), 10);
      if (!Number.isInteger(notificationId) || !Number.isInteger(userId)) {
        return res.status(400).json({ error: 'invalid' });
      }
      await assertModuleNotificationUser(userId);
      await pool.query(
        'UPDATE shop_darwing_notifications SET is_read = TRUE, read_at = $1 WHERE id = $2 AND recipient_user_id = $3',
        [new Date().toISOString(), notificationId, userId],
      );
      res.json({ ok: true });
    } catch (e) {
      res.status(e.status || 500).json({ error: String(e.message) });
    }
  });

  app.get('/shop-drawing/:id', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
      const detail = await shopDrawingLoadDetail(pool, id);
      if (!detail) return res.status(404).json({ error: 'not found' });
      res.json(detail);
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/shop-drawing/:id/attachments/:attachmentId', async (req, res) => {
    try {
      const drawingId = parseInt(String(req.params.id || ''), 10);
      const attachmentId = parseInt(String(req.params.attachmentId || ''), 10);
      if (Number.isNaN(drawingId) || Number.isNaN(attachmentId)) {
        return res.status(400).json({ error: 'invalid' });
      }
      const r = await pool.query(
        `SELECT file_name, mime_type, data_base64 FROM shop_drawing_attachments
         WHERE id = $1 AND drawing_id = $2`,
        [attachmentId, drawingId],
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

  app.post('/shop-drawing', async (req, res) => {
    try {
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
      const actor = await shopDrawingGetUser(pool, userId);
      if (!actor || String(actor.role) !== 'technical_office') {
        return res.status(403).json({ error: 'forbidden' });
      }
      const pm = await shopDrawingGetPmUser(pool);
      if (!pm) return res.status(400).json({ error: 'pm_not_configured' });

      const project = await shopDrawingResolveProject(pool, b);
      if (project.error) return res.status(400).json({ error: project.error });
      const notes = b.notes != null ? String(b.notes).trim() : '';
      const attachments = Array.isArray(b.attachments) ? b.attachments : [];
      const documentType = shopDrawingNormalizeDocumentType(
        b.documentType ?? b.document_type,
      );
      const contentCheck = shopDrawingValidateContent(
        attachments,
        b.externalUrl ?? b.external_url,
      );
      if (contentCheck.error) return res.status(400).json({ error: contentCheck.error });

      const now = new Date().toISOString();
      const ins = await pool.query(
        `INSERT INTO shop_drawings (
          project_id, project_name, notes, status, document_type, external_url,
          created_by_user_id, created_by_user_name,
          current_assignee_user_id, current_assignee_user_name,
          created_at, updated_at
        ) VALUES ($1,$2,$3,'pending_pm',$4,$5,$6,$7,$8,$9,$10,$10) RETURNING id`,
        [
          project.project_id,
          project.project_name,
          notes || null,
          documentType,
          contentCheck.externalUrl,
          userId,
          actor.name,
          parseInt(pm.id, 10),
          pm.name,
          now,
        ],
      );
      const drawingId = parseInt(ins.rows[0].id, 10);
      if (attachments.length > 0) {
        await shopDrawingInsertAttachments(pool, drawingId, attachments, now);
      }
      await shopDrawingInsertAction(pool, {
        drawingId,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'created',
        createdAt: now,
      });

      const title = shopDrawingNotifyTitle(documentType, 'طلب جديد');
      const body = shopDrawingNotificationBody(
        actor.name,
        'رفع',
        project.project_name,
        now,
      );
      await shopDrawingNotifyModuleUser(pool, runNotificationSafely, parseInt(pm.id, 10), {
        title,
        body,
        shopDrawingId: drawingId,
      });
      await shopDrawingNotifyBellUsers(pool, runNotificationSafely, {
        title,
        body,
        shopDrawingId: drawingId,
      });

      res.status(201).json(await shopDrawingLoadDetail(pool, drawingId));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/shop-drawing/:id', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const b = req.body || {};
      const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });

      const rq = await pool.query('SELECT * FROM shop_drawings WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
      const row = rq.rows[0];
      if (parseInt(row.created_by_user_id, 10) !== userId) {
        return res.status(403).json({ error: 'forbidden' });
      }
      if (String(row.status) !== 'returned_to_to') {
        return res.status(400).json({ error: 'not_editable' });
      }

      const actor = await shopDrawingGetUser(pool, userId);
      const pm = await shopDrawingGetPmUser(pool);
      if (!pm) return res.status(400).json({ error: 'pm_not_configured' });

      const project = await shopDrawingResolveProject(pool, b);
      if (project.error) return res.status(400).json({ error: project.error });
      const notes = b.notes != null ? String(b.notes).trim() : '';
      const attachments = Array.isArray(b.attachments) ? b.attachments : [];
      const contentCheck = shopDrawingValidateContent(
        attachments,
        b.externalUrl ?? b.external_url,
      );
      if (contentCheck.error) return res.status(400).json({ error: contentCheck.error });

      const now = new Date().toISOString();
      await pool.query(
        `UPDATE shop_drawings SET project_id=$1, project_name=$2, notes=$3,
         status='pending_pm', return_reason=NULL, external_url=$4,
         current_assignee_user_id=$5, current_assignee_user_name=$6,
         updated_at=$7 WHERE id=$8`,
        [
          project.project_id,
          project.project_name,
          notes || null,
          contentCheck.externalUrl,
          parseInt(pm.id, 10),
          pm.name,
          now,
          id,
        ],
      );
      await shopDrawingDeleteAttachments(pool, id);
      if (attachments.length > 0) {
        await shopDrawingInsertAttachments(pool, id, attachments, now);
      }
      await shopDrawingInsertAction(pool, {
        drawingId: id,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'resubmit',
        createdAt: now,
      });

      const title = shopDrawingNotifyTitle(
        shopDrawingNormalizeDocumentType(row.document_type),
        'إعادة إرسال',
      );
      const body = shopDrawingNotificationBody(
        actor.name,
        'إعادة إرسال',
        project.project_name,
        now,
      );
      await shopDrawingNotifyModuleUser(pool, runNotificationSafely, parseInt(pm.id, 10), {
        title,
        body,
        shopDrawingId: id,
      });
      await shopDrawingNotifyBellUsers(pool, runNotificationSafely, {
        title,
        body,
        shopDrawingId: id,
      });

      res.json(await shopDrawingLoadDetail(pool, id));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/shop-drawing/:id/pm-approve', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.body?.userId ?? req.body?.user_id ?? ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });

      const actor = await shopDrawingGetUser(pool, userId);
      const email = String(actor?.email || '').trim().toLowerCase();
      if (!actor || email !== SHOP_DRAWING_PM_EMAIL.toLowerCase()) {
        return res.status(403).json({ error: 'forbidden' });
      }

      const rq = await pool.query('SELECT * FROM shop_drawings WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
      const row = rq.rows[0];
      if (String(row.status) !== 'pending_pm') {
        return res.status(400).json({ error: 'invalid_status' });
      }
      if (parseInt(row.current_assignee_user_id, 10) !== userId) {
        return res.status(403).json({ error: 'not_assignee' });
      }

      const now = new Date().toISOString();
      await pool.query(
        `UPDATE shop_drawings SET status='pending_om', current_assignee_user_id=NULL,
         current_assignee_user_name=NULL, updated_at=$1 WHERE id=$2`,
        [now, id],
      );
      await shopDrawingInsertAction(pool, {
        drawingId: id,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'pm_approve',
        createdAt: now,
      });

      const projectName = String(row.project_name || '');
      const docType = shopDrawingNormalizeDocumentType(row.document_type);
      const title = shopDrawingNotifyTitle(docType, 'بانتظار اعتمادكم');
      const body = shopDrawingNotificationBody(
        actor.name,
        'اعتماد وإرسال',
        projectName,
        now,
      );
      await shopDrawingNotifyBellUsers(pool, runNotificationSafely, {
        title,
        body,
        shopDrawingId: id,
      });
      await shopDrawingNotifyModuleUser(pool, runNotificationSafely, parseInt(row.created_by_user_id, 10), {
        title: shopDrawingNotifyTitle(docType, 'اعتماد مدير المشروعات'),
        body: `تم اعتماد طلب مشروع «${projectName}» من ${actor.name} — يوم ${shopDrawingFormatArDateTime(now)}`,
        shopDrawingId: id,
      });

      res.json(await shopDrawingLoadDetail(pool, id));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/shop-drawing/:id/pm-return', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.body?.userId ?? req.body?.user_id ?? ''), 10);
      const reason = String(req.body?.reason ?? req.body?.comment ?? '').trim();
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });
      if (!reason) return res.status(400).json({ error: 'reason_required' });

      const actor = await shopDrawingGetUser(pool, userId);
      const email = String(actor?.email || '').trim().toLowerCase();
      if (!actor || email !== SHOP_DRAWING_PM_EMAIL.toLowerCase()) {
        return res.status(403).json({ error: 'forbidden' });
      }

      const rq = await pool.query('SELECT * FROM shop_drawings WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
      const row = rq.rows[0];
      if (String(row.status) !== 'pending_pm') {
        return res.status(400).json({ error: 'invalid_status' });
      }

      const creatorId = parseInt(row.created_by_user_id, 10);
      const now = new Date().toISOString();
      const creator = await shopDrawingGetUser(pool, creatorId);
      await pool.query(
        `UPDATE shop_drawings SET status='returned_to_to', return_reason=$1,
         current_assignee_user_id=$2, current_assignee_user_name=$3, updated_at=$4
         WHERE id=$5`,
        [reason, creatorId, creator?.name || row.created_by_user_name, now, id],
      );
      await shopDrawingInsertAction(pool, {
        drawingId: id,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'pm_return',
        comment: reason,
        createdAt: now,
      });

      const projectName = String(row.project_name || '');
      const docType = shopDrawingNormalizeDocumentType(row.document_type);
      const title = shopDrawingNotifyTitle(docType, 'إعادة للمراجعة');
      const body = `أعاد ${actor.name} طلب مشروع «${projectName}» للمراجعة.\nالسبب: ${reason}\nيوم ${shopDrawingFormatArDateTime(now)}`;
      await shopDrawingNotifyModuleUser(pool, runNotificationSafely, creatorId, {
        title,
        body,
        shopDrawingId: id,
      });
      await shopDrawingNotifyBellUsers(pool, runNotificationSafely, {
        title,
        body,
        shopDrawingId: id,
      });

      res.json(await shopDrawingLoadDetail(pool, id));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/shop-drawing/:id/om-approve', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.body?.userId ?? req.body?.user_id ?? ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });

      const actor = await shopDrawingGetUser(pool, userId);
      if (!actor || String(actor.role) !== 'operation_manager') {
        return res.status(403).json({ error: 'forbidden' });
      }

      const rq = await pool.query('SELECT * FROM shop_drawings WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
      const row = rq.rows[0];
      if (String(row.status) !== 'pending_om') {
        return res.status(400).json({ error: 'invalid_status' });
      }

      const now = new Date().toISOString();
      await pool.query(
        `UPDATE shop_drawings SET status='approved', approved_at=$1, updated_at=$1 WHERE id=$2`,
        [now, id],
      );
      await shopDrawingInsertAction(pool, {
        drawingId: id,
        actorUserId: userId,
        actorUserName: actor.name,
        action: 'om_approve',
        createdAt: now,
      });

      const projectName = String(row.project_name || '');
      const docType = shopDrawingNormalizeDocumentType(row.document_type);
      const pm = await shopDrawingGetPmUser(pool);
      const title = shopDrawingNotifyTitle(docType, 'معتمد');
      const body = `تم اعتماد وحفظ طلب مشروع «${projectName}» — يوم ${shopDrawingFormatArDateTime(now)}`;
      await shopDrawingNotifyModuleUser(pool, runNotificationSafely, parseInt(row.created_by_user_id, 10), {
        title,
        body,
        shopDrawingId: id,
      });
      if (pm) {
        await shopDrawingNotifyModuleUser(pool, runNotificationSafely, parseInt(pm.id, 10), {
          title,
          body,
          shopDrawingId: id,
        });
      }
      await shopDrawingNotifyBellUsers(pool, runNotificationSafely, {
        title,
        body: shopDrawingNotificationBody(actor.name, 'اعتماد نهائي لـ', projectName, now),
        shopDrawingId: id,
      });

      res.json(await shopDrawingLoadDetail(pool, id));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/shop-drawing/:id', async (req, res) => {
    try {
      const id = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.query.userId ?? req.body?.userId ?? ''), 10);
      if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });

      const actor = await shopDrawingGetUser(pool, userId);
      const email = String(actor?.email || '').trim().toLowerCase();
      if (!actor || email !== SHOP_DRAWING_PRIMARY_ADMIN_EMAIL.toLowerCase()) {
        return res.status(403).json({ error: 'forbidden_delete' });
      }

      const rq = await pool.query('SELECT status, project_name FROM shop_drawings WHERE id = $1', [id]);
      if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });

      await pool.query('DELETE FROM shop_drawings WHERE id = $1', [id]);
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  // Bell notification endpoints (مدير العمليات + مسؤول التطبيق)
  app.get('/shop-darwing-notification', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (!Number.isInteger(userId)) return res.status(400).json({ error: 'userId required' });
      await assertBellUser(userId);
      const r = await pool.query(
        `SELECT * FROM shop_darwing_notifications
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
          shop_drawing_id: row.shop_drawing_id != null ? parseInt(row.shop_drawing_id, 10) : null,
          created_at: row.created_at,
          is_read: row.is_read === true,
          read_at: row.read_at,
        })),
      );
    } catch (e) {
      res.status(e.status || 500).json({ error: String(e.message) });
    }
  });

  app.get('/shop-darwing-notification/unread-count', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (!Number.isInteger(userId)) return res.status(400).json({ error: 'userId required' });
      await assertBellUser(userId);
      const r = await pool.query(
        'SELECT COUNT(*)::int AS count FROM shop_darwing_notifications WHERE recipient_user_id = $1 AND is_read = FALSE',
        [userId],
      );
      res.json({ count: parseInt(r.rows[0]?.count || '0', 10) });
    } catch (e) {
      res.status(e.status || 500).json({ error: String(e.message) });
    }
  });

  app.put('/shop-darwing-notification/:id/read', async (req, res) => {
    try {
      const notificationId = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.body?.userId || req.query?.userId || ''), 10);
      if (!Number.isInteger(notificationId) || !Number.isInteger(userId)) {
        return res.status(400).json({ error: 'notification id and userId are required' });
      }
      await assertBellUser(userId);
      await pool.query(
        'UPDATE shop_darwing_notifications SET is_read = TRUE, read_at = $1 WHERE id = $2 AND recipient_user_id = $3',
        [new Date().toISOString(), notificationId, userId],
      );
      res.json({ ok: true });
    } catch (e) {
      res.status(e.status || 500).json({ error: String(e.message) });
    }
  });

  // حذف إشعار الجرس من قائمة المستخدم نفسه فقط (مدير العمليات + مسؤول التطبيق)
  app.delete('/shop-darwing-notification/:id', async (req, res) => {
    try {
      const notificationId = parseInt(String(req.params.id || ''), 10);
      const userId = parseInt(String(req.body?.userId || req.query?.userId || ''), 10);
      if (!Number.isInteger(notificationId) || !Number.isInteger(userId)) {
        return res.status(400).json({ error: 'notification id and userId are required' });
      }
      await assertBellUser(userId);
      const r = await pool.query(
        'DELETE FROM shop_darwing_notifications WHERE id = $1 AND recipient_user_id = $2',
        [notificationId, userId],
      );
      if (r.rowCount === 0) return res.status(404).json({ error: 'not found' });
      res.json({ ok: true });
    } catch (e) {
      res.status(e.status || 500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureShopDrawingTables,
  registerShopDrawingRoutes,
  shopDrawingIsBellUser,
  SHOP_DRAWING_PRIMARY_ADMIN_EMAIL,
};
