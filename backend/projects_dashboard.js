const { formatArDateTimeEgypt } = require('./egypt_local_time');
const XLSX = require('xlsx');

const PD_PRIMARY_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';
const PD_MAX_FILE_BYTES = 10 * 1024 * 1024;

function pdIsPrimaryAdminEmail(email) {
  return String(email || '').trim().toLowerCase() === PD_PRIMARY_ADMIN_EMAIL;
}

function pdNowIso() {
  return new Date().toISOString();
}

function pdEstimateBase64PayloadBytes(dataUrl) {
  const raw = String(dataUrl || '');
  const comma = raw.indexOf(',');
  const b64 = comma >= 0 ? raw.slice(comma + 1) : raw;
  const padding = b64.endsWith('==') ? 2 : b64.endsWith('=') ? 1 : 0;
  return Math.floor((b64.length * 3) / 4) - padding;
}

function pdNormalizeFileData(fileMime, fileData) {
  const mime = String(fileMime || 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet').trim();
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
  const safeRows = Array.isArray(rows) && rows.length
    ? rows.map((row) => (Array.isArray(row) ? row : []).map((cell) => String(cell ?? '')))
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
  const r = await pool.query('SELECT id, name, email, role FROM users WHERE id = $1', [userId]);
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

async function ensureProjectsDashboardTables(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS projects_dashboard_sheet (
      id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
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
      ADD COLUMN IF NOT EXISTS rows_json TEXT NOT NULL DEFAULT '{"sheetName":"Sheet1","rows":[[""]]}'
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS projects_dashboard_notes (
      id SERIAL PRIMARY KEY,
      author_role TEXT NOT NULL CHECK (author_role IN ('technical_office', 'operation_manager')),
      user_id INTEGER NOT NULL REFERENCES users(id),
      user_name TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_projects_dashboard_notes_role_created
      ON projects_dashboard_notes (author_role, created_at DESC)
  `);
}

function registerProjectsDashboardRoutes(app, pool) {
  app.get('/projects-dashboard/sheet', async (req, res) => {
    try {
      const userId = parseInt(req.query.userId, 10);
      if (!userId) return res.status(400).json({ error: 'userId required' });
      const user = await pdGetUser(pool, userId);
      if (!pdCanAccess(user)) return res.status(403).json({ error: 'forbidden' });

      const includeData = String(req.query.includeData || 'true') !== 'false';
      const cols = includeData
        ? 'id, file_name, file_mime, file_data, rows_json, uploaded_by_user_id, uploaded_by_user_name, updated_by_user_id, updated_by_user_name, created_at, updated_at'
        : 'id, file_name, file_mime, rows_json, uploaded_by_user_id, uploaded_by_user_name, updated_by_user_id, updated_by_user_name, created_at, updated_at';

      const r = await pool.query(`SELECT ${cols} FROM projects_dashboard_sheet WHERE id = 1`);
      if (!r.rows.length) return res.status(404).json({ error: 'no_sheet' });

      res.json(pdMapSheetRow(r.rows[0], includeData));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
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
      } = req.body || {};

      const uid = parseInt(userId, 10);
      if (!uid) return res.status(400).json({ error: 'userId required' });

      const user = await pdGetUser(pool, uid);
      if (!pdCanEditSheet(user)) return res.status(403).json({ error: 'forbidden' });

      const existing = await pool.query('SELECT id FROM projects_dashboard_sheet WHERE id = 1');
      const isFirstUpload = existing.rows.length === 0;

      if (isFirstUpload && !pdCanUploadInitial(user)) {
        return res.status(403).json({ error: 'initial_upload_technical_office_only' });
      }

      const now = pdNowIso();
      const displayName = String(userName || user.name || '').trim() || '—';
      let outFileName = String(fileName || 'projects_dashboard.xlsx').trim();
      let outMime = String(fileMime || 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet').trim();
      let parsedRows;
      let parsedSheetName = String(sheetName || 'Sheet1').trim() || 'Sheet1';
      let outFileData;

      if (Array.isArray(rowsJson)) {
        if (!isFirstUpload && existing.rows.length === 0) {
          return res.status(400).json({ error: 'upload_file_first' });
        }
        parsedRows = rowsJson.map((row) =>
          (Array.isArray(row) ? row : []).map((cell) => String(cell ?? '')),
        );
        const xlsxBuffer = pdRowsToXlsxBuffer(parsedSheetName, parsedRows);
        outFileData = pdBufferToDataUrl(
          xlsxBuffer,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        if (!outFileName.toLowerCase().endsWith('.xlsx')) {
          outFileName = outFileName.replace(/\.[^.]+$/, '') + '.xlsx';
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
            id, file_name, file_mime, file_data, rows_json,
            uploaded_by_user_id, uploaded_by_user_name,
            updated_by_user_id, updated_by_user_name,
            created_at, updated_at
          ) VALUES (1, $1, $2, $3, $4, $5, $6, $5, $6, $7, $7)`,
          [outFileName, outMime, outFileData, rowsPayload, uid, displayName, now],
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
          WHERE id = 1`,
          [outFileName, outMime, outFileData, rowsPayload, uid, displayName, now],
        );
      }

      res.json({
        ok: true,
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
        `SELECT id, author_role, user_id, user_name, body, created_at
         FROM projects_dashboard_notes
         WHERE author_role = ANY($1::text[])
         ORDER BY created_at DESC`,
        [roles],
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

      const r = await pool.query(
        `SELECT id, author_role, user_id, user_name, body, created_at
         FROM projects_dashboard_notes
         WHERE author_role = $1
         ORDER BY created_at DESC
         LIMIT 1`,
        [authorRole],
      );
      if (!r.rows.length) return res.status(404).json({ error: 'no_notes' });
      res.json(pdMapNoteRow(r.rows[0]));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/projects-dashboard/notes', async (req, res) => {
    try {
      const { userId, userName, body } = req.body || {};
      const uid = parseInt(userId, 10);
      const text = String(body || '').trim();
      if (!uid || !text) return res.status(400).json({ error: 'userId and body required' });

      const user = await pdGetUser(pool, uid);
      const authorRole = pdNoteAuthorRole(user);
      if (!authorRole) return res.status(403).json({ error: 'forbidden' });

      const now = pdNowIso();
      const displayName = String(userName || user.name || '').trim() || '—';
      const ins = await pool.query(
        `INSERT INTO projects_dashboard_notes (author_role, user_id, user_name, body, created_at)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [authorRole, uid, displayName, text, now],
      );

      res.status(201).json({
        id: ins.rows[0].id,
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
      const requesterEmail = String(req.query.requesterEmail || req.body?.requesterEmail || '').trim();
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
};
