const crypto = require('crypto');
const express = require('express');
const { formatArDateTimeEgypt } = require('./egypt_local_time');
const XLSX = require('xlsx');

const PD_PRIMARY_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';
const PD_MAX_FILE_BYTES = 10 * 1024 * 1024;
const PD_VARIANT_WEBDAV = 'webdav';
const PD_VARIANT_UPLOAD = 'upload';
const PD_WEBDAV_TOKEN_TTL_MS = 24 * 60 * 60 * 1000;
const PD_WEBDAV_SECRET =
  process.env.PD_WEBDAV_SECRET ||
  process.env.DATABASE_URL ||
  'wood-more-pd-webdav-dev-secret';

/** @type {Map<string, { token: string, until: number, owner: string }>} */
const pdWebdavLocks = new Map();

function pdIsPrimaryAdminEmail(email) {
  return String(email || '').trim().toLowerCase() === PD_PRIMARY_ADMIN_EMAIL;
}

function pdNowIso() {
  return new Date().toISOString();
}

function pdNormalizeVariant(raw) {
  const v = String(raw || PD_VARIANT_WEBDAV).trim().toLowerCase();
  if (v === PD_VARIANT_UPLOAD) return PD_VARIANT_UPLOAD;
  return PD_VARIANT_WEBDAV;
}

function pdEstimateBase64PayloadBytes(dataUrl) {
  const raw = String(dataUrl || '');
  const comma = raw.indexOf(',');
  const b64 = comma >= 0 ? raw.slice(comma + 1) : raw;
  const padding = b64.endsWith('==') ? 2 : b64.endsWith('=') ? 1 : 0;
  return Math.floor((b64.length * 3) / 4) - padding;
}

function pdNormalizeFileData(fileMime, fileData) {
  const mime = String(
    fileMime || 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ).trim();
  let data = String(fileData || '').trim();
  if (!data) return { fileMime: mime, fileData: '' };
  if (!data.startsWith('data:')) {
    data = `data:${mime};base64,${data}`;
  }
  return { fileMime: mime, fileData: data };
}

function pdBase64ToBuffer(fileData) {
  let data = String(fileData || '').trim();
  const comma = data.indexOf(',');
  if (data.startsWith('data:') && comma >= 0) {
    data = data.slice(comma + 1);
  }
  return Buffer.from(data, 'base64');
}

function pdParseXlsxToRows(buffer) {
  const wb = XLSX.read(buffer, { type: 'buffer' });
  const sheetName = wb.SheetNames[0] || 'Sheet1';
  const sh = wb.Sheets[sheetName];
  const rows = XLSX.utils.sheet_to_json(sh, { header: 1, defval: '' });
  const normalized = rows.map((row) =>
    (Array.isArray(row) ? row : []).map((cell) => String(cell ?? '')),
  );
  let maxCols = 0;
  for (const row of normalized) {
    if (row.length > maxCols) maxCols = row.length;
  }
  if (maxCols === 0) {
    return { sheetName, rows: [['']] };
  }
  for (const row of normalized) {
    while (row.length < maxCols) row.push('');
  }
  if (normalized.length === 0) normalized.push(Array(maxCols).fill(''));
  return { sheetName, rows: normalized };
}

function pdRowsToXlsxBuffer(sheetName, rows) {
  const wb = XLSX.utils.book_new();
  const safeRows =
    Array.isArray(rows) && rows.length
      ? rows.map((row) =>
          (Array.isArray(row) ? row : []).map((cell) => String(cell ?? '')),
        )
      : [['']];
  const ws = XLSX.utils.aoa_to_sheet(safeRows);
  XLSX.utils.book_append_sheet(wb, ws, sheetName || 'Sheet1');
  return XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' });
}

function pdBufferToDataUrl(buffer, mime) {
  const b64 = buffer.toString('base64');
  return `data:${mime};base64,${b64}`;
}

async function pdGetUser(pool, userId) {
  const r = await pool.query('SELECT id, name, email, role FROM users WHERE id = $1', [
    userId,
  ]);
  return r.rows[0] || null;
}

function pdCanAccess(user) {
  if (!user) return false;
  const role = String(user.role || '');
  if (role === 'technical_office' || role === 'operation_manager') return true;
  if (role === 'app_admin' && pdIsPrimaryAdminEmail(user.email)) return true;
  return false;
}

function pdCanEditSheet(user) {
  return pdCanAccess(user);
}

function pdCanUploadInitial(user) {
  return user && String(user.role) === 'technical_office';
}

function pdNoteAuthorRole(user) {
  const role = String(user?.role || '');
  if (role === 'technical_office') return 'technical_office';
  if (role === 'operation_manager') return 'operation_manager';
  if (role === 'app_admin' && pdIsPrimaryAdminEmail(user.email)) return 'operation_manager';
  return null;
}

function pdMapNoteRow(row) {
  const createdAt = row.created_at;
  return {
    id: row.id,
    authorRole: row.author_role,
    userId: row.user_id,
    userName: row.user_name,
    body: row.body,
    createdAt,
    createdAtDisplay: formatArDateTimeEgypt(createdAt),
    variant: row.variant || PD_VARIANT_WEBDAV,
  };
}

function pdMapSheetRow(row, includeData) {
  let rowsJson = [];
  let sheetName = 'Sheet1';
  try {
    const parsed = JSON.parse(row.rows_json || '{}');
    rowsJson = Array.isArray(parsed.rows) ? parsed.rows : [];
    sheetName = parsed.sheetName || 'Sheet1';
  } catch (_) {
    rowsJson = [['']];
  }
  return {
    id: row.id,
    variant: row.variant || PD_VARIANT_WEBDAV,
    fileName: row.file_name,
    fileMime: row.file_mime,
    fileData: includeData ? row.file_data : null,
    sheetName,
    rowsJson,
    uploadedByUserId: row.uploaded_by_user_id,
    uploadedByUserName: row.uploaded_by_user_name,
    updatedByUserId: row.updated_by_user_id,
    updatedByUserName: row.updated_by_user_name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    updatedAtDisplay: formatArDateTimeEgypt(row.updated_at),
  };
}

function pdCreateWebdavToken(userId, variant) {
  const exp = Date.now() + PD_WEBDAV_TOKEN_TTL_MS;
  const payload = `${userId}:${variant}:${exp}`;
  const sig = crypto.createHmac('sha256', PD_WEBDAV_SECRET).update(payload).digest('hex');
  return `${exp}.${sig}`;
}

function pdVerifyWebdavToken(userId, variant, token) {
  const raw = String(token || '').trim();
  const dot = raw.indexOf('.');
  if (dot < 0) return false;
  const exp = parseInt(raw.slice(0, dot), 10);
  const sig = raw.slice(dot + 1);
  if (!exp || !sig || Date.now() > exp) return false;
  const payload = `${userId}:${variant}:${exp}`;
  const expected = crypto.createHmac('sha256', PD_WEBDAV_SECRET).update(payload).digest('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected));
  } catch (_) {
    return false;
  }
}

async function pdAuthFromQuery(pool, req, variant) {
  const userId = parseInt(req.query.userId, 10);
  const token = String(req.query.token || '').trim();
  if (!userId || !token) return { ok: false, status: 401, error: 'auth_required' };
  if (!pdVerifyWebdavToken(userId, variant, token)) {
    return { ok: false, status: 401, error: 'invalid_token' };
  }
  const user = await pdGetUser(pool, userId);
  if (!pdCanAccess(user)) return { ok: false, status: 403, error: 'forbidden' };
  return { ok: true, user, userId };
}

async function pdGetSheetRow(pool, variant, includeData = false) {
  const cols = includeData
    ? 'id, variant, file_name, file_mime, file_data, rows_json, uploaded_by_user_id, uploaded_by_user_name, updated_by_user_id, updated_by_user_name, created_at, updated_at'
    : 'id, variant, file_name, file_mime, rows_json, uploaded_by_user_id, uploaded_by_user_name, updated_by_user_id, updated_by_user_name, created_at, updated_at';
  const r = await pool.query(
    `SELECT ${cols} FROM projects_dashboard_sheet WHERE variant = $1`,
    [variant],
  );
  return r.rows[0] || null;
}

function pdWebdavLockKey(variant, fileName) {
  return `${variant}:${fileName}`;
}

function pdWebdavDateHeader(iso) {
  try {
    return new Date(iso).toUTCString();
  } catch (_) {
    return new Date().toUTCString();
  }
}

function pdWebdavPropfindResponse({ href, fileName, updatedAt, contentLength }) {
  const lastMod = pdWebdavDateHeader(updatedAt);
  return `<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>${href}</D:href>
    <D:propstat>
      <D:prop>
        <D:displayname>${fileName}</D:displayname>
        <D:getlastmodified>${lastMod}</D:getlastmodified>
        <D:getcontentlength>${contentLength}</D:getcontentlength>
        <D:resourcetype/>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>`;
}

async function ensureProjectsDashboardTables(pool) {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS projects_dashboard_sheet (
        id SERIAL PRIMARY KEY,
        variant TEXT NOT NULL DEFAULT 'webdav',
        file_name TEXT NOT NULL,
        file_mime TEXT NOT NULL DEFAULT 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        file_data TEXT NOT NULL,
        rows_json TEXT NOT NULL DEFAULT '{"sheetName":"Sheet1","rows":[[""]]}',
        uploaded_by_user_id INTEGER NOT NULL REFERENCES users(id),
        uploaded_by_user_name TEXT NOT NULL,
        updated_by_user_id INTEGER REFERENCES users(id),
        updated_by_user_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      ALTER TABLE projects_dashboard_sheet
        DROP CONSTRAINT IF EXISTS projects_dashboard_sheet_id_check
    `);
    await pool.query(`
      ALTER TABLE projects_dashboard_sheet
        ADD COLUMN IF NOT EXISTS variant TEXT NOT NULL DEFAULT 'webdav'
    `);
    await pool.query(`
      ALTER TABLE projects_dashboard_sheet
        ADD COLUMN IF NOT EXISTS rows_json TEXT NOT NULL DEFAULT '{"sheetName":"Sheet1","rows":[[""]]}'
    `);
    await pool.query(`
      UPDATE projects_dashboard_sheet SET variant = 'webdav'
      WHERE variant IS NULL OR variant = ''
    `);
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_dashboard_sheet_variant
        ON projects_dashboard_sheet (variant)
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS projects_dashboard_notes (
        id SERIAL PRIMARY KEY,
        variant TEXT NOT NULL DEFAULT 'webdav',
        author_role TEXT NOT NULL CHECK (author_role IN ('technical_office', 'operation_manager')),
        user_id INTEGER NOT NULL REFERENCES users(id),
        user_name TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      ALTER TABLE projects_dashboard_notes
        ADD COLUMN IF NOT EXISTS variant TEXT NOT NULL DEFAULT 'webdav'
    `);
    await pool.query(`
      UPDATE projects_dashboard_notes SET variant = 'webdav'
      WHERE variant IS NULL OR variant = ''
    `);
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_projects_dashboard_notes_role_created
        ON projects_dashboard_notes (author_role, created_at DESC)
    `);
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_projects_dashboard_notes_variant_role_created
        ON projects_dashboard_notes (variant, author_role, created_at DESC)
    `);
    console.log('ensureProjectsDashboardTables: ok');
  } catch (e) {
    console.warn('ensureProjectsDashboardTables:', e.message);
  }
}

function registerProjectsDashboardRoutes(app, pool, deps = {}) {
  const notifyFileUpload = deps.notifyFileUpload || (async () => {});

  async function pdNotifySheetUpload(variant, userId, userName) {
    const r = await pool.query(
      'SELECT id, file_name FROM projects_dashboard_sheet WHERE variant = $1',
      [variant],
    );
    if (r.rows.length === 0) return;
    const row = r.rows[0];
    await notifyFileUpload(pool, userId, userName, {
      title: 'رفع شيت Projects Dashboard',
      body:
        `قام "${userName}" برفع/تحديث شيت "${row.file_name}" — نسخة: ${variant}`,
      eventType: 'projects_dashboard_upload',
      attachmentSource: 'projects_dashboard',
      attachmentRecordId: parseInt(row.id, 10),
      attachmentCount: 1,
    });
  }

  app.get('/projects-dashboard/sheet', async (req, res) => {
    try {
      const userId = parseInt(req.query.userId, 10);
      if (!userId) return res.status(400).json({ error: 'userId required' });
      const user = await pdGetUser(pool, userId);
      if (!pdCanAccess(user)) return res.status(403).json({ error: 'forbidden' });

      const variant = pdNormalizeVariant(req.query.variant);
      const includeData = String(req.query.includeData || 'false') === 'true';
      const row = await pdGetSheetRow(pool, variant, includeData);
      if (!row) return res.status(404).json({ error: 'no_sheet' });

      res.json(pdMapSheetRow(row, includeData));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/projects-dashboard/sheet/download', async (req, res) => {
    try {
      const userId = parseInt(req.query.userId, 10);
      if (!userId) return res.status(400).json({ error: 'userId required' });
      const user = await pdGetUser(pool, userId);
      if (!pdCanAccess(user)) return res.status(403).json({ error: 'forbidden' });

      const variant = pdNormalizeVariant(req.query.variant);
      const row = await pdGetSheetRow(pool, variant, true);
      if (!row) return res.status(404).json({ error: 'no_sheet' });

      const buffer = pdBase64ToBuffer(row.file_data);
      const fileName = row.file_name || 'projects_dashboard.xlsx';
      res.setHeader(
        'Content-Type',
        row.file_mime ||
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      res.setHeader('Content-Length', buffer.length);
      res.send(buffer);
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/projects-dashboard/webdav/token', async (req, res) => {
    try {
      const userId = parseInt((req.body || {}).userId, 10);
      if (!userId) return res.status(400).json({ error: 'userId required' });
      const user = await pdGetUser(pool, userId);
      if (!pdCanEditSheet(user)) return res.status(403).json({ error: 'forbidden' });

      const variant = pdNormalizeVariant((req.body || {}).variant);
      if (variant !== PD_VARIANT_WEBDAV) {
        return res.status(400).json({ error: 'webdav_token_webdav_only' });
      }

      const row = await pdGetSheetRow(pool, variant, false);
      if (!row) return res.status(404).json({ error: 'no_sheet' });

      const token = pdCreateWebdavToken(userId, variant);
      const fileName = row.file_name || 'projects_dashboard.xlsx';
      const base =
        process.env.PD_PUBLIC_API_BASE_URL ||
        `${req.protocol}://${req.get('host')}`;
      const webdavUrl =
        `${base.replace(/\/$/, '')}/projects-dashboard/webdav/${encodeURIComponent(fileName)}` +
        `?userId=${userId}&token=${encodeURIComponent(token)}&variant=${variant}`;

      res.json({
        token,
        fileName,
        webdavUrl,
        officeUri: `ms-excel:ofe|u|${webdavUrl}`,
        expiresInMs: PD_WEBDAV_TOKEN_TTL_MS,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  const webdavRaw = express.raw({
    type: () => true,
    limit: PD_MAX_FILE_BYTES + 1024,
  });

  app.all('/projects-dashboard/webdav/:fileName', webdavRaw, async (req, res) => {
    try {
      const variant = pdNormalizeVariant(req.query.variant);
      if (variant !== PD_VARIANT_WEBDAV) {
        return res.status(400).send('webdav variant only');
      }

      const auth = await pdAuthFromQuery(pool, req, variant);
      if (!auth.ok) return res.status(auth.status).send(auth.error);

      const fileName = decodeURIComponent(req.params.fileName || '');
      const row = await pdGetSheetRow(pool, variant, true);
      if (!row) return res.status(404).send('no_sheet');
      if (row.file_name !== fileName) {
        return res.status(404).send('file_name_mismatch');
      }

      const href = req.originalUrl.split('?')[0];
      const buffer = pdBase64ToBuffer(row.file_data);
      const lockKey = pdWebdavLockKey(variant, fileName);

      if (req.method === 'OPTIONS') {
        res.setHeader('DAV', '1,2');
        res.setHeader('Allow', 'OPTIONS, GET, HEAD, PUT, PROPFIND, LOCK, UNLOCK');
        return res.status(200).end();
      }

      if (req.method === 'PROPFIND') {
        const xml = pdWebdavPropfindResponse({
          href,
          fileName,
          updatedAt: row.updated_at,
          contentLength: buffer.length,
        });
        res.setHeader('Content-Type', 'application/xml; charset=utf-8');
        return res.status(207).send(xml);
      }

      if (req.method === 'HEAD' || req.method === 'GET') {
        res.setHeader(
          'Content-Type',
          row.file_mime ||
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        res.setHeader('Content-Length', buffer.length);
        res.setHeader('Last-Modified', pdWebdavDateHeader(row.updated_at));
        res.setHeader('DAV', '1,2');
        if (req.method === 'HEAD') return res.status(200).end();
        return res.send(buffer);
      }

      if (req.method === 'LOCK') {
        const token = `opaquelocktoken:${crypto.randomUUID()}`;
        const until = Date.now() + 30 * 60 * 1000;
        pdWebdavLocks.set(lockKey, {
          token,
          until,
          owner: String(auth.userId),
        });
        res.setHeader('Lock-Token', `<${token}>`);
        res.setHeader('Content-Type', 'application/xml; charset=utf-8');
        return res.status(200).send(`<?xml version="1.0" encoding="utf-8"?>
<D:prop xmlns:D="DAV:">
  <D:lockdiscovery>
    <D:activelock>
      <D:locktype><D:write/></D:locktype>
      <D:lockscope><D:exclusive/></D:lockscope>
      <D:timeout>Second-1800</D:timeout>
      <D:locktoken><D:href>${token}</D:href></D:locktoken>
    </D:activelock>
  </D:lockdiscovery>
</D:prop>`);
      }

      if (req.method === 'UNLOCK') {
        pdWebdavLocks.delete(lockKey);
        return res.status(204).end();
      }

      if (req.method === 'PUT') {
        const lock = pdWebdavLocks.get(lockKey);
        const lockToken = String(req.headers['if'] || req.headers['lock-token'] || '');
        if (lock && lock.until > Date.now() && !lockToken.includes(lock.token)) {
          return res.status(423).send('locked');
        }

        const body = req.body;
        let putBuffer;
        if (Buffer.isBuffer(body)) {
          putBuffer = body;
        } else if (body instanceof Uint8Array) {
          putBuffer = Buffer.from(body);
        } else if (typeof body === 'string') {
          putBuffer = Buffer.from(body, 'binary');
        } else {
          return res.status(400).send('empty_body');
        }

        if (!putBuffer.length) return res.status(400).send('empty_body');
        if (putBuffer.length > PD_MAX_FILE_BYTES) {
          return res.status(413).send('file_too_large');
        }

        const parsed = pdParseXlsxToRows(putBuffer);
        const outFileData = pdBufferToDataUrl(
          putBuffer,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        const rowsPayload = JSON.stringify({
          sheetName: parsed.sheetName,
          rows: parsed.rows,
        });
        const now = pdNowIso();
        const displayName = String(auth.user.name || '').trim() || '—';

        await pool.query(
          `UPDATE projects_dashboard_sheet SET
            file_data = $1,
            rows_json = $2,
            updated_by_user_id = $3,
            updated_by_user_name = $4,
            updated_at = $5
          WHERE variant = $6`,
          [outFileData, rowsPayload, auth.userId, displayName, now, variant],
        );

        await pdNotifySheetUpload(variant, auth.userId, displayName);

        pdWebdavLocks.delete(lockKey);
        res.setHeader('Last-Modified', pdWebdavDateHeader(now));
        return res.status(204).end();
      }

      res.setHeader('Allow', 'OPTIONS, GET, HEAD, PUT, PROPFIND, LOCK, UNLOCK');
      return res.status(405).send('method_not_allowed');
    } catch (e) {
      res.status(500).send(String(e.message));
    }
  });

  app.put('/projects-dashboard/sheet', async (req, res) => {
    try {
      const {
        userId,
        userName,
        fileName,
        fileMime,
        fileData,
        rowsJson,
        sheetName,
        variant: bodyVariant,
      } = req.body || {};

      const uid = parseInt(userId, 10);
      if (!uid) return res.status(400).json({ error: 'userId required' });

      const user = await pdGetUser(pool, uid);
      if (!pdCanEditSheet(user)) return res.status(403).json({ error: 'forbidden' });

      const variant = pdNormalizeVariant(bodyVariant);
      const existing = await pool.query(
        'SELECT id FROM projects_dashboard_sheet WHERE variant = $1',
        [variant],
      );
      const isFirstUpload = existing.rows.length === 0;

      if (isFirstUpload && !pdCanUploadInitial(user)) {
        return res.status(403).json({ error: 'initial_upload_technical_office_only' });
      }

      const now = pdNowIso();
      const displayName = String(userName || user.name || '').trim() || '—';
      let outFileName = String(
        fileName ||
          (variant === PD_VARIANT_UPLOAD
            ? 'projects_dashboard_plus1.xlsx'
            : 'projects_dashboard.xlsx'),
      ).trim();
      let outMime = String(
        fileMime || 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ).trim();
      let parsedRows;
      let parsedSheetName = String(sheetName || 'Sheet1').trim() || 'Sheet1';
      let outFileData;

      if (Array.isArray(rowsJson)) {
        parsedRows = rowsJson.map((row) =>
          (Array.isArray(row) ? row : []).map((cell) => String(cell ?? '')),
        );
        const xlsxBuffer = pdRowsToXlsxBuffer(parsedSheetName, parsedRows);
        outFileData = pdBufferToDataUrl(
          xlsxBuffer,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (!outFileName.toLowerCase().endsWith('.xlsx')) {
          outFileName = `${outFileName.replace(/\.[^.]+$/, '')}.xlsx`;
        }
        outMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      } else if (fileData) {
        const lowerName = outFileName.toLowerCase();
        if (!lowerName.endsWith('.xlsx') && !lowerName.endsWith('.xls')) {
          return res.status(400).json({ error: 'invalid_extension' });
        }
        const norm = pdNormalizeFileData(outMime, fileData);
        if (!norm.fileData) return res.status(400).json({ error: 'empty_file' });
        if (pdEstimateBase64PayloadBytes(norm.fileData) > PD_MAX_FILE_BYTES) {
          return res.status(413).json({ error: 'file_too_large' });
        }
        const buffer = pdBase64ToBuffer(norm.fileData);
        const parsed = pdParseXlsxToRows(buffer);
        parsedRows = parsed.rows;
        parsedSheetName = parsed.sheetName;
        outFileData = norm.fileData;
        outMime = norm.fileMime;
      } else {
        return res.status(400).json({ error: 'fileData or rowsJson required' });
      }

      const rowsPayload = JSON.stringify({
        sheetName: parsedSheetName,
        rows: parsedRows,
      });

      if (isFirstUpload) {
        await pool.query(
          `INSERT INTO projects_dashboard_sheet (
            variant, file_name, file_mime, file_data, rows_json,
            uploaded_by_user_id, uploaded_by_user_name,
            updated_by_user_id, updated_by_user_name,
            created_at, updated_at
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $6, $7, $8, $8)`,
          [
            variant,
            outFileName,
            outMime,
            outFileData,
            rowsPayload,
            uid,
            displayName,
            now,
          ],
        );
      } else {
        await pool.query(
          `UPDATE projects_dashboard_sheet SET
            file_name = $1,
            file_mime = $2,
            file_data = $3,
            rows_json = $4,
            updated_by_user_id = $5,
            updated_by_user_name = $6,
            updated_at = $7
          WHERE variant = $8`,
          [outFileName, outMime, outFileData, rowsPayload, uid, displayName, now, variant],
        );
      }

      await pdNotifySheetUpload(variant, uid, displayName);

      res.json({
        ok: true,
        variant,
        updatedAt: now,
        updatedAtDisplay: formatArDateTimeEgypt(now),
        sheetName: parsedSheetName,
        rowsJson: parsedRows,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/projects-dashboard/notes', async (req, res) => {
    try {
      const userId = parseInt(req.query.userId, 10);
      if (!userId) return res.status(400).json({ error: 'userId required' });
      const user = await pdGetUser(pool, userId);
      if (!pdCanAccess(user)) return res.status(403).json({ error: 'forbidden' });

      const variant = pdNormalizeVariant(req.query.variant);
      const authorRole = String(req.query.authorRole || '').trim();
      let roles = [];
      if (authorRole === 'all') {
        if (!(String(user.role) === 'app_admin' && pdIsPrimaryAdminEmail(user.email))) {
          return res.status(403).json({ error: 'forbidden' });
        }
        roles = ['technical_office', 'operation_manager'];
      } else if (authorRole === 'technical_office' || authorRole === 'operation_manager') {
        roles = [authorRole];
      } else {
        return res.status(400).json({ error: 'authorRole required' });
      }

      const r = await pool.query(
        `SELECT id, variant, author_role, user_id, user_name, body, created_at
         FROM projects_dashboard_notes
         WHERE variant = $1 AND author_role = ANY($2::text[])
         ORDER BY created_at DESC`,
        [variant, roles],
      );
      res.json(r.rows.map(pdMapNoteRow));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/projects-dashboard/notes/latest', async (req, res) => {
    try {
      const userId = parseInt(req.query.userId, 10);
      const authorRole = String(req.query.authorRole || '').trim();
      if (!userId || !authorRole) {
        return res.status(400).json({ error: 'userId and authorRole required' });
      }
      if (authorRole !== 'technical_office' && authorRole !== 'operation_manager') {
        return res.status(400).json({ error: 'invalid authorRole' });
      }

      const user = await pdGetUser(pool, userId);
      if (!pdCanAccess(user)) return res.status(403).json({ error: 'forbidden' });

      const variant = pdNormalizeVariant(req.query.variant);
      const r = await pool.query(
        `SELECT id, variant, author_role, user_id, user_name, body, created_at
         FROM projects_dashboard_notes
         WHERE variant = $1 AND author_role = $2
         ORDER BY created_at DESC
         LIMIT 1`,
        [variant, authorRole],
      );
      if (!r.rows.length) return res.status(404).json({ error: 'no_notes' });
      res.json(pdMapNoteRow(r.rows[0]));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/projects-dashboard/notes', async (req, res) => {
    try {
      const { userId, userName, body, variant: bodyVariant } = req.body || {};
      const uid = parseInt(userId, 10);
      const text = String(body || '').trim();
      if (!uid || !text) return res.status(400).json({ error: 'userId and body required' });

      const user = await pdGetUser(pool, uid);
      const authorRole = pdNoteAuthorRole(user);
      if (!authorRole) return res.status(403).json({ error: 'forbidden' });

      const variant = pdNormalizeVariant(bodyVariant);
      const now = pdNowIso();
      const displayName = String(userName || user.name || '').trim() || '—';
      const ins = await pool.query(
        `INSERT INTO projects_dashboard_notes (variant, author_role, user_id, user_name, body, created_at)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id`,
        [variant, authorRole, uid, displayName, text, now],
      );

      res.status(201).json({
        id: ins.rows[0].id,
        variant,
        authorRole,
        userId: uid,
        userName: displayName,
        body: text,
        createdAt: now,
        createdAtDisplay: formatArDateTimeEgypt(now),
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/projects-dashboard/notes/:id', async (req, res) => {
    try {
      const noteId = parseInt(req.params.id, 10);
      const requesterEmail = String(
        req.query.requesterEmail || req.body?.requesterEmail || '',
      ).trim();
      if (!noteId) return res.status(400).json({ error: 'invalid id' });
      if (!pdIsPrimaryAdminEmail(requesterEmail)) {
        return res.status(403).json({ error: 'forbidden' });
      }

      const del = await pool.query(
        'DELETE FROM projects_dashboard_notes WHERE id = $1 RETURNING id',
        [noteId],
      );
      if (!del.rows.length) return res.status(404).json({ error: 'not_found' });
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureProjectsDashboardTables,
  registerProjectsDashboardRoutes,
  PD_PRIMARY_ADMIN_EMAIL,
  PD_VARIANT_WEBDAV,
  PD_VARIANT_UPLOAD,
};
