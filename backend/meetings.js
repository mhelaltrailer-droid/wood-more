const zlib = require('zlib');
const { formatArDateTimeEgypt } = require('./egypt_local_time');

const PRIMARY_APP_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';

const MEETINGS_ROLES = [
  'op_coordinator',
  'operation_manager',
  'site_engineer_manager',
  'technical_office',
];

const MEETING_FILE_TYPES = [
  'call_of_meeting',
  'meeting_agenda',
  'minutes_of_meeting',
  'meeting_resolution',
];

const MEETING_FILE_LABELS = {
  call_of_meeting: 'Call of Meeting',
  meeting_agenda: 'Meeting Agenda',
  minutes_of_meeting: 'Minutes Of Meeting',
  meeting_resolution: 'Meeting Resolution',
};

const MEETINGS_MAX_FILE_BYTES = 5 * 1024 * 1024;

function meetingFileLabel(fileType) {
  return MEETING_FILE_LABELS[fileType] || fileType;
}

function previousMeetingFileType(fileType) {
  const i = MEETING_FILE_TYPES.indexOf(fileType);
  return i > 0 ? MEETING_FILE_TYPES[i - 1] : null;
}

async function getMeetingsUser(pool, userId) {
  const id = parseInt(userId, 10);
  if (!Number.isFinite(id)) return null;
  const r = await pool.query(
    'SELECT id, name, email, role FROM users WHERE id = $1',
    [id],
  );
  return r.rows[0] || null;
}

function isPrimaryAppAdmin(user) {
  return !!user &&
    String(user.email || '').trim().toLowerCase() === PRIMARY_APP_ADMIN_EMAIL;
}

function canAccessMeetings(user) {
  if (!user) return false;
  if (isPrimaryAppAdmin(user)) return true;
  return MEETINGS_ROLES.includes(user.role);
}

function canUploadMeetings(user) {
  return !!user && user.role === 'op_coordinator';
}

function canDeleteMeetings(user) {
  return isPrimaryAppAdmin(user);
}

function isPdfFile({ fileName, mimeType }) {
  const mime = String(mimeType || '').toLowerCase();
  const name = String(fileName || '').toLowerCase();
  return mime === 'application/pdf' || name.endsWith('.pdf');
}

function stripBase64(raw) {
  const s = String(raw || '').trim();
  const i = s.indexOf('base64,');
  return i >= 0 ? s.slice(i + 7) : s;
}

function parseMeetingFilePayload(body) {
  const fileName = String(body.file_name || body.fileName || '').trim();
  const mimeType = String(body.mime_type || body.mimeType || 'application/pdf').trim();
  const dataBase64 = stripBase64(body.data_base64 || body.dataBase64 || '');
  const sizeBytes = parseInt(body.size_bytes || body.sizeBytes || 0, 10);
  return { fileName, mimeType, dataBase64, sizeBytes };
}

function validatePdfPayload(file) {
  if (!file.fileName || !file.dataBase64) {
    return 'أرفق ملف PDF';
  }
  if (!isPdfFile(file)) {
    return 'يُسمح بملف PDF فقط';
  }
  const approxBytes = file.sizeBytes > 0
    ? file.sizeBytes
    : Math.ceil((file.dataBase64.length * 3) / 4);
  if (approxBytes > MEETINGS_MAX_FILE_BYTES) {
    return 'الملف أكبر من 5 ميجا';
  }
  return null;
}

function packMeetingFileBytes(buffer) {
  const gzipped = zlib.gzipSync(buffer, { level: 9 });
  if (gzipped.length < buffer.length) {
    return { encoding: 'gzip', bytes: gzipped };
  }
  return { encoding: 'raw', bytes: buffer };
}

function unpackMeetingFileToBase64(row) {
  if (row.data_bytes) {
    const buf = Buffer.isBuffer(row.data_bytes)
      ? row.data_bytes
      : Buffer.from(row.data_bytes);
    const raw = row.storage_encoding === 'gzip' ? zlib.gunzipSync(buf) : buf;
    return raw.toString('base64');
  }
  return String(row.data_base64 || '');
}

async function insertCompressedMeetingFile(pool, {
  meetingId,
  fileType,
  fileName,
  mimeType,
  dataBase64,
  uploadedByUserId,
  uploadedAt,
}) {
  const raw = Buffer.from(dataBase64, 'base64');
  const packed = packMeetingFileBytes(raw);
  await pool.query(
    `INSERT INTO meeting_files (
       meeting_id, file_type, file_name, mime_type, data_base64,
       data_bytes, storage_encoding, size_bytes, uploaded_by_user_id, uploaded_at
     ) VALUES ($1, $2, $3, $4, NULL, $5, $6, $7, $8, $9)`,
    [
      meetingId,
      fileType,
      fileName,
      mimeType || 'application/pdf',
      packed.bytes,
      packed.encoding,
      raw.length,
      uploadedByUserId,
      uploadedAt,
    ],
  );
}

async function ensureMeetingsTables(pool) {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS meetings (
        id SERIAL PRIMARY KEY,
        meeting_number TEXT NOT NULL,
        subject TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        created_by_user_id INTEGER NOT NULL REFERENCES users(id),
        created_by_user_name TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_meetings_meeting_number
      ON meetings (meeting_number)
    `).catch(() => {});
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_meetings_created_at
      ON meetings (created_at DESC)
    `).catch(() => {});
    await pool.query(`
      CREATE TABLE IF NOT EXISTS meeting_files (
        id SERIAL PRIMARY KEY,
        meeting_id INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
        file_type TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        data_base64 TEXT,
        data_bytes BYTEA,
        storage_encoding TEXT NOT NULL DEFAULT 'raw',
        size_bytes INTEGER NOT NULL DEFAULT 0,
        uploaded_by_user_id INTEGER REFERENCES users(id),
        uploaded_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = current_schema()
            AND table_name = 'meeting_files' AND column_name = 'data_bytes'
        ) THEN
          ALTER TABLE meeting_files ADD COLUMN data_bytes BYTEA;
        END IF;
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = current_schema()
            AND table_name = 'meeting_files' AND column_name = 'storage_encoding'
        ) THEN
          ALTER TABLE meeting_files
            ADD COLUMN storage_encoding TEXT NOT NULL DEFAULT 'raw';
        END IF;
      END $$
    `).catch(() => {});
    await pool.query(
      'ALTER TABLE meeting_files ALTER COLUMN data_base64 DROP NOT NULL',
    ).catch(() => {});
    const legacy = await pool.query(
      `SELECT id, data_base64 FROM meeting_files
       WHERE data_bytes IS NULL
         AND data_base64 IS NOT NULL
         AND length(data_base64) > 0`,
    ).catch(() => ({ rows: [] }));
    for (const row of legacy.rows || []) {
      try {
        const raw = Buffer.from(String(row.data_base64), 'base64');
        const packed = packMeetingFileBytes(raw);
        await pool.query(
          `UPDATE meeting_files
           SET data_bytes = $2, storage_encoding = $3, data_base64 = NULL,
               size_bytes = CASE WHEN size_bytes > 0 THEN size_bytes ELSE $4 END
           WHERE id = $1`,
          [row.id, packed.bytes, packed.encoding, raw.length],
        );
      } catch (_) {}
    }
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_meeting_files_meeting_type
      ON meeting_files (meeting_id, file_type)
    `).catch(() => {});
    await pool.query(`
      CREATE TABLE IF NOT EXISTS meeting_notifications (
        id SERIAL PRIMARY KEY,
        recipient_user_id INTEGER NOT NULL REFERENCES users(id),
        meeting_id INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
        file_type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read BOOLEAN NOT NULL DEFAULT FALSE,
        read_at TEXT
      )
    `);
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_meeting_notifications_recipient_created
      ON meeting_notifications (recipient_user_id, created_at DESC)
    `).catch(() => {});
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_meeting_notifications_recipient_unread
      ON meeting_notifications (recipient_user_id, is_read)
    `).catch(() => {});
    console.log('ensureMeetingsTables: ok');
  } catch (e) {
    console.warn('ensureMeetingsTables:', e.message);
  }
}

async function loadMeetingFilesMeta(pool, meetingIds) {
  if (!meetingIds.length) return new Map();
  const r = await pool.query(
    `SELECT meeting_id, file_type, file_name, uploaded_at
     FROM meeting_files
     WHERE meeting_id = ANY($1::int[])`,
    [meetingIds],
  );
  const map = new Map();
  for (const row of r.rows) {
    const list = map.get(row.meeting_id) || [];
    list.push({
      file_type: row.file_type,
      file_name: row.file_name,
      uploaded_at: row.uploaded_at,
    });
    map.set(row.meeting_id, list);
  }
  return map;
}

function mapMeetingRow(row, files) {
  const slots = {};
  for (const type of MEETING_FILE_TYPES) {
    slots[type] = null;
  }
  for (const f of files || []) {
    slots[f.file_type] = {
      file_type: f.file_type,
      file_name: f.file_name,
      uploaded_at: f.uploaded_at,
      label: meetingFileLabel(f.file_type),
    };
  }
  return {
    id: row.id,
    meeting_number: row.meeting_number,
    subject: row.subject,
    scheduled_at: row.scheduled_at,
    created_by_user_id: row.created_by_user_id,
    created_by_user_name: row.created_by_user_name,
    created_at: row.created_at,
    files: slots,
  };
}

async function notifyMeetingFile(pool, {
  actorUserId,
  meetingId,
  fileType,
  title,
  body,
}) {
  await pool.query(
    `INSERT INTO meeting_notifications (
       recipient_user_id, meeting_id, file_type, title, body, created_at, is_read
     )
     SELECT id, $1, $2, $3, $4, $5, FALSE
     FROM users
     WHERE id <> $7
       AND (
         role = ANY($6::text[])
         OR lower(trim(email)) = $8
       )`,
    [
      meetingId,
      fileType,
      title,
      body,
      new Date().toISOString(),
      MEETINGS_ROLES,
      actorUserId,
      PRIMARY_APP_ADMIN_EMAIL,
    ],
  );
}

function registerMeetingsRoutes(app, pool, { runNotificationSafely } = {}) {
  const notifySafely = typeof runNotificationSafely === 'function'
    ? (fn) => runNotificationSafely('meetingsNotify', fn)
    : async (fn) => { await fn(); };

  app.get('/meetings', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canAccessMeetings(user)) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
      const q = String(req.query.q || '').trim();
      const params = [];
      let sql = `
        SELECT id, meeting_number, subject, scheduled_at,
               created_by_user_id, created_by_user_name, created_at
        FROM meetings
      `;
      if (q) {
        params.push(`%${q}%`);
        sql += ` WHERE meeting_number ILIKE $1 OR subject ILIKE $1`;
      }
      sql += ' ORDER BY created_at DESC, id DESC';
      const r = await pool.query(sql, params);
      const filesMap = await loadMeetingFilesMeta(pool, r.rows.map((row) => row.id));
      res.json(r.rows.map((row) => mapMeetingRow(row, filesMap.get(row.id) || [])));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/meetings/:id', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canAccessMeetings(user)) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
      const id = parseInt(req.params.id, 10);
      const r = await pool.query(
        `SELECT id, meeting_number, subject, scheduled_at,
                created_by_user_id, created_by_user_name, created_at
         FROM meetings WHERE id = $1`,
        [id],
      );
      if (!r.rows[0]) return res.status(404).json({ error: 'الاجتماع غير موجود' });
      const filesMap = await loadMeetingFilesMeta(pool, [id]);
      res.json(mapMeetingRow(r.rows[0], filesMap.get(id) || []));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.post('/meetings', async (req, res) => {
    try {
      const body = req.body || {};
      const user = await getMeetingsUser(pool, body.userId);
      if (!canUploadMeetings(user)) {
        return res.status(403).json({ error: 'رفع الاجتماعات متاح لـ Op-Coordinator فقط' });
      }
      const meetingNumber = String(body.meeting_number || body.meetingNumber || '').trim();
      const subject = String(body.subject || '').trim();
      const scheduledAt = String(body.scheduled_at || body.scheduledAt || '').trim();
      if (!subject) return res.status(400).json({ error: 'موضوع الاجتماع إلزامي' });
      if (!meetingNumber) return res.status(400).json({ error: 'رقم الاجتماع إلزامي' });
      if (!scheduledAt) return res.status(400).json({ error: 'تاريخ ووقت الانعقاد إلزاميان' });
      const file = parseMeetingFilePayload(body);
      const fileErr = validatePdfPayload(file);
      if (fileErr) return res.status(400).json({ error: fileErr });

      const now = new Date().toISOString();
      let meetingId;
      try {
        const ins = await pool.query(
          `INSERT INTO meetings (
             meeting_number, subject, scheduled_at,
             created_by_user_id, created_by_user_name, created_at
           ) VALUES ($1, $2, $3, $4, $5, $6)
           RETURNING id, meeting_number, subject, scheduled_at,
                     created_by_user_id, created_by_user_name, created_at`,
          [meetingNumber, subject, scheduledAt, user.id, user.name, now],
        );
        meetingId = ins.rows[0].id;
        await insertCompressedMeetingFile(pool, {
          meetingId,
          fileType: 'call_of_meeting',
          fileName: file.fileName,
          mimeType: file.mimeType,
          dataBase64: file.dataBase64,
          uploadedByUserId: user.id,
          uploadedAt: now,
        });
        const when = formatArDateTimeEgypt(scheduledAt) || scheduledAt;
        await notifySafely(() => notifyMeetingFile(pool, {
          actorUserId: user.id,
          meetingId,
          fileType: 'call_of_meeting',
          title: 'موعد اجتماع جديد',
          body: `قام ${user.name} بتحديد موعد اجتماع جديد يوم ${when}\n${subject}`,
        }));
        const filesMap = await loadMeetingFilesMeta(pool, [meetingId]);
        return res.status(201).json(mapMeetingRow(ins.rows[0], filesMap.get(meetingId) || []));
      } catch (e) {
        if (String(e.message || '').includes('idx_meetings_meeting_number')
          || e.code === '23505') {
          return res.status(400).json({ error: 'رقم الاجتماع مستخدم مسبقاً' });
        }
        throw e;
      }
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/meetings/:id/files/:fileType', async (req, res) => {
    try {
      const body = req.body || {};
      const user = await getMeetingsUser(pool, body.userId);
      if (!canUploadMeetings(user)) {
        return res.status(403).json({ error: 'رفع الاجتماعات متاح لـ Op-Coordinator فقط' });
      }
      const meetingId = parseInt(req.params.id, 10);
      const fileType = String(req.params.fileType || '').trim();
      if (!MEETING_FILE_TYPES.includes(fileType)) {
        return res.status(400).json({ error: 'نوع الملف غير صالح' });
      }
      const meeting = await pool.query(
        'SELECT id, meeting_number, subject, scheduled_at FROM meetings WHERE id = $1',
        [meetingId],
      );
      if (!meeting.rows[0]) return res.status(404).json({ error: 'الاجتماع غير موجود' });

      const existing = await pool.query(
        'SELECT file_type FROM meeting_files WHERE meeting_id = $1',
        [meetingId],
      );
      const have = new Set(existing.rows.map((r) => r.file_type));
      const replacing = have.has(fileType);
      if (!replacing) {
        const prev = previousMeetingFileType(fileType);
        if (prev && !have.has(prev)) {
          return res.status(400).json({
            error: `يجب رفع ${meetingFileLabel(prev)} أولاً`,
          });
        }
      }

      const file = parseMeetingFilePayload(body);
      const fileErr = validatePdfPayload(file);
      if (fileErr) return res.status(400).json({ error: fileErr });

      const now = new Date().toISOString();
      await pool.query(
        'DELETE FROM meeting_files WHERE meeting_id = $1 AND file_type = $2',
        [meetingId, fileType],
      );
      await insertCompressedMeetingFile(pool, {
        meetingId,
        fileType,
        fileName: file.fileName,
        mimeType: file.mimeType,
        dataBase64: file.dataBase64,
        uploadedByUserId: user.id,
        uploadedAt: now,
      });

      const row = meeting.rows[0];
      const when = formatArDateTimeEgypt(row.scheduled_at) || row.scheduled_at;
      const label = meetingFileLabel(fileType);
      const action = replacing ? 'باستبدال' : 'بإرفاق';
      const title = replacing ? `استبدال ${label}` : label;
      const bodyText = fileType === 'call_of_meeting' && !replacing
        ? `قام ${user.name} بتحديد موعد اجتماع جديد يوم ${when}\n${row.subject}`
        : `قام ${user.name} ${action} ${label} لاجتماع رقم ${row.meeting_number} يوم ${when}\n${row.subject}`;

      await notifySafely(() => notifyMeetingFile(pool, {
        actorUserId: user.id,
        meetingId,
        fileType,
        title,
        body: bodyText,
      }));

      const full = await pool.query(
        `SELECT id, meeting_number, subject, scheduled_at,
                created_by_user_id, created_by_user_name, created_at
         FROM meetings WHERE id = $1`,
        [meetingId],
      );
      const filesMap = await loadMeetingFilesMeta(pool, [meetingId]);
      res.json(mapMeetingRow(full.rows[0], filesMap.get(meetingId) || []));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/meetings/:id/files/:fileType', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canAccessMeetings(user)) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
      const meetingId = parseInt(req.params.id, 10);
      const fileType = String(req.params.fileType || '').trim();
      const r = await pool.query(
        `SELECT file_name, mime_type, data_base64, data_bytes,
                storage_encoding, size_bytes
         FROM meeting_files
         WHERE meeting_id = $1 AND file_type = $2`,
        [meetingId, fileType],
      );
      if (!r.rows[0]) return res.status(404).json({ error: 'الملف غير موجود' });
      const row = r.rows[0];
      res.json({
        file_name: row.file_name,
        mime_type: row.mime_type,
        data_base64: unpackMeetingFileToBase64(row),
        size_bytes: row.size_bytes,
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/meetings/:id/files/:fileType', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canDeleteMeetings(user)) {
        return res.status(403).json({ error: 'الحذف متاح للمسؤول الرئيسي فقط' });
      }
      const meetingId = parseInt(req.params.id, 10);
      const fileType = String(req.params.fileType || '').trim();
      if (!MEETING_FILE_TYPES.includes(fileType)) {
        return res.status(400).json({ error: 'نوع الملف غير صالح' });
      }
      const meeting = await pool.query(
        'SELECT id FROM meetings WHERE id = $1',
        [meetingId],
      );
      if (!meeting.rows[0]) return res.status(404).json({ error: 'الاجتماع غير موجود' });
      const del = await pool.query(
        'DELETE FROM meeting_files WHERE meeting_id = $1 AND file_type = $2',
        [meetingId, fileType],
      );
      if (!del.rowCount) return res.status(404).json({ error: 'الملف غير موجود' });
      const full = await pool.query(
        `SELECT id, meeting_number, subject, scheduled_at,
                created_by_user_id, created_by_user_name, created_at
         FROM meetings WHERE id = $1`,
        [meetingId],
      );
      const filesMap = await loadMeetingFilesMeta(pool, [meetingId]);
      res.json(mapMeetingRow(full.rows[0], filesMap.get(meetingId) || []));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/meetings/:id', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canDeleteMeetings(user)) {
        return res.status(403).json({ error: 'الحذف متاح للمسؤول الرئيسي فقط' });
      }
      const meetingId = parseInt(req.params.id, 10);
      const del = await pool.query('DELETE FROM meetings WHERE id = $1', [meetingId]);
      if (!del.rowCount) return res.status(404).json({ error: 'الاجتماع غير موجود' });
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/meetings-notifications', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canAccessMeetings(user)) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
      const r = await pool.query(
        `SELECT id, recipient_user_id, meeting_id, file_type, title, body,
                created_at, is_read, read_at
         FROM meeting_notifications
         WHERE recipient_user_id = $1
         ORDER BY created_at DESC, id DESC
         LIMIT 200`,
        [user.id],
      );
      res.json(r.rows);
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/meetings-notifications/unread-count', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canAccessMeetings(user)) {
        return res.json({ count: 0 });
      }
      const r = await pool.query(
        `SELECT COUNT(*)::int AS count
         FROM meeting_notifications
         WHERE recipient_user_id = $1 AND is_read = FALSE`,
        [user.id],
      );
      res.json({ count: r.rows[0]?.count || 0 });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/meetings-notifications/read-all', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, (req.body || {}).userId);
      if (!canAccessMeetings(user)) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
      await pool.query(
        `UPDATE meeting_notifications
         SET is_read = TRUE, read_at = $2
         WHERE recipient_user_id = $1 AND is_read = FALSE`,
        [user.id, new Date().toISOString()],
      );
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.put('/meetings-notifications/:id/read', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, (req.body || {}).userId);
      if (!canAccessMeetings(user)) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
      await pool.query(
        `UPDATE meeting_notifications
         SET is_read = TRUE, read_at = $3
         WHERE id = $1 AND recipient_user_id = $2`,
        [parseInt(req.params.id, 10), user.id, new Date().toISOString()],
      );
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.delete('/meetings-notifications/:id', async (req, res) => {
    try {
      const user = await getMeetingsUser(pool, req.query.userId);
      if (!canAccessMeetings(user)) {
        return res.status(403).json({ error: 'غير مصرح' });
      }
      await pool.query(
        'DELETE FROM meeting_notifications WHERE id = $1 AND recipient_user_id = $2',
        [parseInt(req.params.id, 10), user.id],
      );
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  ensureMeetingsTables,
  registerMeetingsRoutes,
  MEETINGS_ROLES,
  MEETING_FILE_TYPES,
};
