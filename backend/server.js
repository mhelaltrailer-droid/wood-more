require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { splitSqlChunks } = require('./scripts/lib/xlsx_project_locations');
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
app.use(cors());
app.use(express.json({ limit: '30mb' }));
const PRIMARY_APP_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';

async function ensureActivityLogsTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS activity_logs (
        id SERIAL PRIMARY KEY,
        created_at TEXT NOT NULL,
        action_type TEXT NOT NULL,
        action_label TEXT NOT NULL DEFAULT '',
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        user_id INTEGER,
        user_name TEXT,
        user_email TEXT,
        status_code INTEGER NOT NULL DEFAULT 200,
        details TEXT
      )
    `);
    await pool.query(`ALTER TABLE activity_logs ADD COLUMN IF NOT EXISTS action_label TEXT NOT NULL DEFAULT ''`).catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at)').catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id)').catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_activity_logs_action_type ON activity_logs(action_type)').catch(() => {});
    console.log('ensureActivityLogsTable: ok');
  } catch (e) {
    console.warn('ensureActivityLogsTable:', e.message);
  }
}

async function ensureExecutedPlansTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS executed_plans (
        id SERIAL PRIMARY KEY,
        source_plan_id INTEGER REFERENCES detailed_reports(id) ON DELETE SET NULL,
        user_id INTEGER NOT NULL REFERENCES users(id),
        user_name TEXT NOT NULL,
        project_id INTEGER REFERENCES projects(id),
        project_name TEXT,
        plan_date TEXT NOT NULL,
        status TEXT NOT NULL CHECK (status IN ('confirmed', 'confirmed_edited', 'postponed')),
        modification_summary TEXT,
        postpone_reason_key TEXT,
        postpone_reason_label TEXT,
        postpone_custom_reason TEXT,
        postpone_notes TEXT,
        postpone_reopen_date TEXT,
        plan_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS postpone_reason_key TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS postpone_reason_label TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS postpone_custom_reason TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS postpone_notes TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS postpone_reopen_date TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS engineer_fine_target TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS sem_fine_target TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS sem_fine_amount TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS sem_no_fine_reason TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS sem_resolved_at TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE executed_plans ADD COLUMN IF NOT EXISTS sem_resolved_by_user_id INTEGER`).catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_executed_plans_plan_date ON executed_plans(plan_date)').catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_executed_plans_user_id ON executed_plans(user_id)').catch(() => {});
    console.log('ensureExecutedPlansTable: ok');
  } catch (e) {
    console.warn('ensureExecutedPlansTable:', e.message);
  }
}

async function ensurePostponeReasonsTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS postpone_reasons (
        id SERIAL PRIMARY KEY,
        reason_key TEXT UNIQUE NOT NULL,
        label TEXT NOT NULL,
        requires_custom BOOLEAN NOT NULL DEFAULT FALSE,
        is_system BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TEXT NOT NULL
      )
    `);
    const defaults = [
      ['site_not_ready', 'عدم جاهزية موقع العمل', false],
      ['weather', 'ظروف جوية', false],
      ['contractor_absent', 'عدم حضور المقاول', false],
      ['other', 'أخرى', true],
    ];
    for (const [key, label, requiresCustom] of defaults) {
      await pool.query(
        `INSERT INTO postpone_reasons (reason_key, label, requires_custom, is_system, created_at)
         VALUES ($1,$2,$3,TRUE,$4)
         ON CONFLICT (reason_key) DO UPDATE SET label = EXCLUDED.label, requires_custom = EXCLUDED.requires_custom, is_system = TRUE`,
        [key, label, requiresCustom, new Date().toISOString()]
      );
    }
    await pool.query(
      `DELETE FROM postpone_reasons
       WHERE is_system = TRUE
         AND reason_key NOT IN ('site_not_ready', 'weather', 'contractor_absent', 'other')`
    );
    console.log('ensurePostponeReasonsTable: ok');
  } catch (e) {
    console.warn('ensurePostponeReasonsTable:', e.message);
  }
}

async function ensureNotificationsTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        recipient_user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        recipient_role TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        event_type TEXT NOT NULL,
        actor_user_id INTEGER,
        actor_user_name TEXT,
        project_name TEXT,
        created_at TEXT NOT NULL,
        is_read BOOLEAN NOT NULL DEFAULT FALSE,
        read_at TEXT
      )
    `);
    await pool.query('CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created ON notifications(recipient_user_id, created_at DESC)').catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread ON notifications(recipient_user_id, is_read)').catch(() => {});
    console.log('ensureNotificationsTable: ok');
  } catch (e) {
    console.warn('ensureNotificationsTable:', e.message);
  }
}

async function ensurePrivateChatMessagesTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS private_chat_messages (
        id SERIAL PRIMARY KEY,
        sender_email TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        receiver_email TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(
      'CREATE INDEX IF NOT EXISTS idx_private_chat_created ON private_chat_messages(created_at)',
    ).catch(() => {});
    console.log('ensurePrivateChatMessagesTable: ok');
  } catch (e) {
    console.warn('ensurePrivateChatMessagesTable:', e.message);
  }
}

const REPORTS_SYS_PRIMARY_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';
const REPORTS_SYS_MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024;
const REPORTS_SYS_TYPES = ['تقرير معاينة', 'تقرير إثبات حالة', 'تقرير تلفيات'];

async function ensureReportsSysTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS reports_sys (
        id SERIAL PRIMARY KEY,
        report_name TEXT NOT NULL,
        report_type TEXT NOT NULL,
        summary TEXT NOT NULL DEFAULT '',
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        created_by_user_id INTEGER NOT NULL REFERENCES users(id),
        created_by_user_name TEXT NOT NULL DEFAULT '',
        current_assignee_user_id INTEGER REFERENCES users(id),
        current_assignee_user_name TEXT,
        source_report_id INTEGER REFERENCES reports_sys(id),
        rejection_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT,
        rejected_at TEXT
      )
    `);
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_reports_sys_name_lower
      ON reports_sys (LOWER(TRIM(report_name)))
    `).catch(() => {});
    await pool.query(`
      CREATE TABLE IF NOT EXISTS reports_sys_attachments (
        id SERIAL PRIMARY KEY,
        report_id INTEGER NOT NULL REFERENCES reports_sys(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        data_base64 TEXT NOT NULL,
        size_bytes INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS reports_sys_actions (
        id SERIAL PRIMARY KEY,
        report_id INTEGER NOT NULL REFERENCES reports_sys(id) ON DELETE CASCADE,
        actor_user_id INTEGER NOT NULL REFERENCES users(id),
        actor_user_name TEXT NOT NULL,
        action TEXT NOT NULL,
        comment TEXT,
        from_user_id INTEGER,
        to_user_id INTEGER,
        to_user_name TEXT,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_reports_sys_assignee_status
      ON reports_sys (current_assignee_user_id, status)
    `).catch(() => {});
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_reports_sys_creator
      ON reports_sys (created_by_user_id, status)
    `).catch(() => {});
    await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = current_schema()
            AND table_name = 'reports_sys' AND column_name = 'project_id'
        ) THEN
          ALTER TABLE reports_sys ADD COLUMN project_id INTEGER REFERENCES projects(id);
        END IF;
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = current_schema()
            AND table_name = 'reports_sys' AND column_name = 'project_name'
        ) THEN
          ALTER TABLE reports_sys ADD COLUMN project_name TEXT NOT NULL DEFAULT '';
        END IF;
      END $$
    `).catch(() => {});
    console.log('ensureReportsSysTables: ok');
  } catch (e) {
    console.warn('ensureReportsSysTables:', e.message);
  }
}

async function reportsSysNotifyPrimaryAdmin(pool, fields) {
  await runNotificationSafely('reportsSysNotifyPrimaryAdmin', async () => {
    const r = await pool.query(
      `SELECT id, role FROM users WHERE LOWER(TRIM(email)) = $1 LIMIT 1`,
      [REPORTS_SYS_PRIMARY_ADMIN_EMAIL.toLowerCase()],
    );
    if (r.rows.length === 0) return;
    const admin = r.rows[0];
    const now = new Date().toISOString();
    await pool.query(
      `INSERT INTO notifications (
        recipient_user_id, recipient_role, title, body, event_type,
        actor_user_id, actor_user_name, project_name, created_at, is_read
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, FALSE)`,
      [
        parseInt(admin.id, 10),
        String(admin.role || 'app_admin'),
        fields.title,
        fields.body,
        fields.eventType ?? fields.event_type ?? 'reports_sys',
        fields.actorUserId ?? fields.actor_user_id ?? null,
        fields.actorUserName ?? fields.actor_user_name ?? null,
        fields.reportName ?? fields.report_name ?? null,
        now,
      ],
    );
  });
}

async function reportsSysNotifyUser(pool, userId, fields) {
  await runNotificationSafely('reportsSysNotifyUser', async () => {
    const u = await pool.query('SELECT id, role FROM users WHERE id = $1', [userId]);
    if (u.rows.length === 0) return;
    const row = u.rows[0];
    const now = new Date().toISOString();
    await pool.query(
      `INSERT INTO notifications (
        recipient_user_id, recipient_role, title, body, event_type,
        actor_user_id, actor_user_name, project_name, created_at, is_read
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, FALSE)`,
      [
        parseInt(userId, 10),
        String(row.role || 'site_engineer'),
        fields.title,
        fields.body,
        fields.eventType ?? fields.event_type ?? 'reports_sys',
        fields.actorUserId ?? fields.actor_user_id ?? null,
        fields.actorUserName ?? fields.actor_user_name ?? null,
        fields.reportName ?? fields.report_name ?? null,
        now,
      ],
    );
  });
}

function reportsSysMapRow(row, attachments = [], actions = [], reviewers = []) {
  return {
    id: parseInt(row.id, 10),
    report_name: row.report_name,
    report_type: row.report_type,
    summary: row.summary || '',
    notes: row.notes || '',
    status: row.status,
    created_by_user_id: parseInt(row.created_by_user_id, 10),
    created_by_user_name: row.created_by_user_name || '',
    current_assignee_user_id: row.current_assignee_user_id != null
      ? parseInt(row.current_assignee_user_id, 10)
      : null,
    current_assignee_user_name: row.current_assignee_user_name || null,
    source_report_id: row.source_report_id != null ? parseInt(row.source_report_id, 10) : null,
    project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
    project_name: row.project_name || '',
    rejection_reason: row.rejection_reason || null,
    created_at: row.created_at,
    updated_at: row.updated_at,
    archived_at: row.archived_at || null,
    rejected_at: row.rejected_at || null,
    attachments,
    actions,
    reviewers,
  };
}

async function reportsSysLoadDetail(pool, reportId) {
  const r = await pool.query('SELECT * FROM reports_sys WHERE id = $1', [reportId]);
  if (r.rows.length === 0) return null;
  const row = r.rows[0];
  const att = await pool.query(
    `SELECT id, file_name, mime_type, size_bytes, created_at
     FROM reports_sys_attachments WHERE report_id = $1 ORDER BY id`,
    [reportId],
  );
  const act = await pool.query(
    `SELECT * FROM reports_sys_actions WHERE report_id = $1 ORDER BY created_at ASC, id ASC`,
    [reportId],
  );
  const reviewers = act.rows
    .filter((a) => ['forward', 'archive', 'submit', 'resubmit'].includes(String(a.action)))
    .map((a) => ({
      user_id: parseInt(a.actor_user_id, 10),
      user_name: a.actor_user_name,
      reviewed_at: a.created_at,
      action: a.action,
    }));
  const attachments = att.rows.map((a) => ({
    id: parseInt(a.id, 10),
    file_name: a.file_name,
    mime_type: a.mime_type,
    size_bytes: parseInt(a.size_bytes, 10),
    created_at: a.created_at,
  }));
  const actions = act.rows.map((a) => ({
    id: parseInt(a.id, 10),
    actor_user_id: parseInt(a.actor_user_id, 10),
    actor_user_name: a.actor_user_name,
    action: a.action,
    comment: a.comment || null,
    from_user_id: a.from_user_id != null ? parseInt(a.from_user_id, 10) : null,
    to_user_id: a.to_user_id != null ? parseInt(a.to_user_id, 10) : null,
    to_user_name: a.to_user_name || null,
    created_at: a.created_at,
  }));
  return reportsSysMapRow(row, attachments, actions, reviewers);
}

async function reportsSysResolveProject(pool, body, fallbackRow = null) {
  const rawId = body?.projectId ?? body?.project_id;
  const rawName = body?.projectName ?? body?.project_name
    ?? body?.customProjectName ?? body?.custom_project_name;
  const isOther = rawId == null
    || String(rawId).trim() === ''
    || String(rawId).trim() === '-1'
    || String(rawId).trim().toLowerCase() === 'other';
  if (isOther) {
    const name = String(rawName ?? fallbackRow?.project_name ?? '').trim();
    if (!name) return { error: 'project_name_required' };
    return { project_id: null, project_name: name };
  }
  const projectId = parseInt(String(rawId), 10);
  if (Number.isNaN(projectId)) return { error: 'invalid_project' };
  const pr = await pool.query('SELECT id, name FROM projects WHERE id = $1', [projectId]);
  if (pr.rows.length === 0) return { error: 'project_not_found' };
  return {
    project_id: projectId,
    project_name: String(pr.rows[0].name || '').trim(),
  };
}

async function reportsSysInsertAction(pool, fields) {
  const now = new Date().toISOString();
  await pool.query(
    `INSERT INTO reports_sys_actions (
      report_id, actor_user_id, actor_user_name, action, comment,
      from_user_id, to_user_id, to_user_name, created_at
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [
      fields.reportId,
      fields.actorUserId,
      fields.actorUserName,
      fields.action,
      fields.comment || null,
      fields.fromUserId ?? null,
      fields.toUserId ?? null,
      fields.toUserName ?? null,
      now,
    ],
  );
  return now;
}

function reportsSysHasFullAccess(role) {
  const r = String(role || '').trim();
  return r === 'app_admin'
    || r === 'operation_manager'
    || r === 'site_engineer_manager'
    || r === 'general_supervisor'
    || r === 'document_controller';
}

async function reportsSysCanArchive(role, email) {
  return reportsSysHasFullAccess(role);
}

function reportsSysAppendTextSearch(sql, params, q) {
  const term = String(q || '').trim().toLowerCase();
  if (!term) return { sql, params };
  const like = `%${term}%`;
  const idx = params.length + 1;
  return {
    sql: `${sql} AND (
      LOWER(report_name) LIKE $${idx}
      OR LOWER(COALESCE(project_name, '')) LIKE $${idx}
      OR LOWER(summary) LIKE $${idx}
    )`,
    params: [...params, like],
  };
}

async function ensureWithdrawalRequestsTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS withdrawal_requests (
        id SERIAL PRIMARY KEY,
        project_id INTEGER NOT NULL REFERENCES projects(id),
        location_id INTEGER NOT NULL REFERENCES project_locations(id),
        phase TEXT NOT NULL DEFAULT 'first_fix',
        engineer_user_id INTEGER NOT NULL REFERENCES users(id),
        engineer_user_name TEXT NOT NULL,
        location_path_label TEXT NOT NULL DEFAULT '',
        sem_status TEXT NOT NULL DEFAULT 'pending',
        om_status TEXT NOT NULL DEFAULT 'pending',
        sem_reason TEXT,
        om_reason TEXT,
        sem_responded_at TEXT,
        om_responded_at TEXT,
        overall_status TEXT NOT NULL DEFAULT 'pending',
        fulfilled_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_withdrawal_req_active_unique
      ON withdrawal_requests (location_id, phase)
      WHERE fulfilled_at IS NULL AND overall_status IN ('pending', 'approved')
    `).catch(() => {});
    console.log('ensureWithdrawalRequestsTable: ok');
  } catch (e) {
    console.warn('ensureWithdrawalRequestsTable:', e.message);
  }
}

async function withdrawalInsertNotificationsForRoles(pool, roles, fields) {
  const title = fields.title;
  const body = fields.body;
  const eventType = fields.eventType ?? fields.event_type;
  const actorUserId = fields.actorUserId ?? fields.actor_user_id ?? null;
  const actorUserName = fields.actorUserName ?? fields.actor_user_name ?? null;
  const projectName = fields.projectName ?? fields.project_name ?? null;
  const now = new Date().toISOString();
  await pool.query(
    `INSERT INTO notifications (
      recipient_user_id, recipient_role, title, body, event_type,
      actor_user_id, actor_user_name, project_name, created_at, is_read
    )
    SELECT id, role, $1, $2, $3, $4, $5, $6, $7, FALSE
    FROM users
    WHERE role = ANY($8::text[])`,
    [title, body, eventType, actorUserId, actorUserName, projectName, now, roles]
  );
}

async function withdrawalNotifyEngineer(pool, engineerUserId, fields) {
  const u = await pool.query('SELECT role FROM users WHERE id = $1', [engineerUserId]);
  const role = u.rows.length ? String(u.rows[0].role || 'site_engineer') : 'site_engineer';
  const title = fields.title;
  const body = fields.body;
  const eventType = fields.eventType ?? fields.event_type;
  const actorUserId = fields.actorUserId ?? fields.actor_user_id ?? null;
  const actorUserName = fields.actorUserName ?? fields.actor_user_name ?? null;
  const projectName = fields.projectName ?? fields.project_name ?? null;
  await pool.query(
    `INSERT INTO notifications (
      recipient_user_id, recipient_role, title, body, event_type,
      actor_user_id, actor_user_name, project_name, created_at, is_read
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, FALSE)`,
    [
      engineerUserId,
      role,
      title,
      body,
      eventType,
      actorUserId,
      actorUserName,
      projectName,
      new Date().toISOString(),
    ]
  );
}

async function notifyAppAdmins(pool, fields) {
  await runNotificationSafely('notifyAppAdmins', async () => {
    await withdrawalInsertNotificationsForRoles(pool, ['app_admin'], fields);
  });
}

async function fetchUserRole(pool, userId) {
  const id = parseInt(userId, 10);
  if (Number.isNaN(id)) return null;
  const r = await pool.query('SELECT role FROM users WHERE id = $1', [id]);
  return r.rows.length ? String(r.rows[0].role || '') : null;
}

function formatDateYmd(value) {
  if (!value) return '';
  const s = String(value);
  return s.length >= 10 ? s.slice(0, 10) : s;
}

function serverLocalDateYmd(d = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function classifyPlanDay(reportDatetime) {
  const d = formatDateYmd(reportDatetime);
  const today = serverLocalDateYmd();
  const tomorrowDate = new Date();
  tomorrowDate.setDate(tomorrowDate.getDate() + 1);
  const tomorrow = serverLocalDateYmd(tomorrowDate);
  if (d === tomorrow) return 'tomorrow';
  if (d === today) return 'today';
  return 'other';
}

async function runNotificationSafely(label, fn) {
  try {
    await fn();
  } catch (e) {
    console.warn(`${label}:`, e.message);
  }
}

async function notifyAppAdminsOnDocumentUpload(pool, userId, userName, details) {
  await notifyAppAdmins(pool, {
    title: details.title || 'رفع مستند',
    body: details.body,
    eventType: details.eventType ?? details.event_type,
    actorUserId: userId,
    actorUserName: userName,
    projectName: details.projectName ?? details.project_name ?? null,
  });
}

async function notifyAppAdminsIfSiteEngineer(pool, userId, fields) {
  const role = await fetchUserRole(pool, userId);
  if (role !== 'site_engineer') return;
  await notifyAppAdmins(pool, fields);
}

async function notifyAppAdminsWorkPlanSaved(pool, {
  userId,
  userName,
  projectName,
  reportDatetime,
  isUpdate = false,
  hasAttachments = false,
}) {
  const role = await fetchUserRole(pool, userId);
  if (role !== 'site_engineer') return;
  const dayKind = classifyPlanDay(reportDatetime);
  let planLabel;
  let eventType;
  if (dayKind === 'tomorrow') {
    planLabel = 'خطة عمل الغد';
    eventType = isUpdate ? 'tomorrow_work_plan_updated' : 'tomorrow_work_plan_created';
  } else if (dayKind === 'today') {
    planLabel = 'خطة عمل اليوم';
    eventType = isUpdate ? 'today_work_plan_updated' : 'today_work_plan_saved';
  } else {
    planLabel = `خطة عمل (${formatDateYmd(reportDatetime)})`;
    eventType = isUpdate ? 'work_plan_updated' : 'work_plan_saved';
  }
  const proj = String(projectName || '').trim() || 'غير محدد';
  const action = isUpdate ? 'عدّل' : 'حفظ';
  await notifyAppAdmins(pool, {
    title: `تنبيه — ${planLabel}`,
    body:
      `قام "${userName}" ب${action} ${planLabel} بمشروع "${proj}"\n` +
      `تاريخ الخطة: ${formatDateYmd(reportDatetime)}`,
    eventType,
    actorUserId: userId,
    actorUserName: userName,
    projectName: projectName || null,
  });
  if (hasAttachments) {
    await notifyAppAdminsOnDocumentUpload(pool, userId, userName, {
      title: 'رفع مرفقات مع خطة العمل',
      body:
        `قام "${userName}" بإرفاق مستند/صورة مع ${planLabel} — مشروع "${proj}"`,
      eventType: 'work_plan_attachment',
      projectName: projectName || null,
    });
  }
}

const MS_SD_MAX_FILE_BYTES = 5 * 1024 * 1024;

function _estimateBase64PayloadBytes(dataUrl) {
  let b64 = String(dataUrl || '').trim();
  if (!b64) return 0;
  if (b64.startsWith('data:')) {
    const idx = b64.indexOf(',');
    if (idx >= 0) b64 = b64.slice(idx + 1);
  }
  return Math.floor((b64.length * 3) / 4);
}

function _normalizeMsSdFileData(fileMime, fileData) {
  let mime = String(fileMime || '').trim();
  let data = String(fileData || '').trim();
  if (!data) return { mime, data };
  if (!data.startsWith('data:')) {
    data = `data:${mime || 'application/octet-stream'};base64,${data}`;
  } else if (!mime) {
    const m = /^data:([^;]+);/i.exec(data);
    if (m) mime = m[1];
  }
  return { mime, data };
}

function _isPrimaryAppAdminEmail(email) {
  return String(email || '')
    .trim()
    .toLowerCase() === PRIMARY_APP_ADMIN_EMAIL.toLowerCase();
}

async function ensureMsSdTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ms_sd_records (
        id SERIAL PRIMARY KEY,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_name TEXT NOT NULL,
        kind TEXT NOT NULL CHECK (kind IN ('ms', 'sd')),
        record_name TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ms_sd_attachments (
        id SERIAL PRIMARY KEY,
        record_id INTEGER NOT NULL REFERENCES ms_sd_records(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL,
        file_mime TEXT NOT NULL,
        file_data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(
      'CREATE INDEX IF NOT EXISTS idx_ms_sd_records_project_kind ON ms_sd_records(project_id, kind)',
    ).catch(() => {});
    await pool.query(
      'CREATE INDEX IF NOT EXISTS idx_ms_sd_attachments_record_id ON ms_sd_attachments(record_id)',
    ).catch(() => {});
    console.log('ensureMsSdTables: ok');
  } catch (e) {
    console.warn('ensureMsSdTables:', e.message);
  }
}

async function ensureMosItpTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS mos_itp_records (
        id SERIAL PRIMARY KEY,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_name TEXT NOT NULL,
        kind TEXT NOT NULL CHECK (kind IN ('mos', 'itp')),
        record_name TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS mos_itp_attachments (
        id SERIAL PRIMARY KEY,
        record_id INTEGER NOT NULL REFERENCES mos_itp_records(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL,
        file_mime TEXT NOT NULL,
        file_data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(
      'CREATE INDEX IF NOT EXISTS idx_mos_itp_records_project_kind ON mos_itp_records(project_id, kind)',
    ).catch(() => {});
    await pool.query(
      'CREATE INDEX IF NOT EXISTS idx_mos_itp_attachments_record_id ON mos_itp_attachments(record_id)',
    ).catch(() => {});
    console.log('ensureMosItpTables: ok');
  } catch (e) {
    console.warn('ensureMosItpTables:', e.message);
  }
}

async function ensureIrMirUploadsTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS ir_mir_uploads (
        id SERIAL PRIMARY KEY,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        user_name TEXT NOT NULL,
        kind TEXT NOT NULL CHECK (kind IN ('mir', 'ir')),
        mir_name TEXT,
        location_id INTEGER REFERENCES project_locations(id) ON DELETE CASCADE,
        phase TEXT,
        file_name TEXT NOT NULL,
        file_mime TEXT NOT NULL,
        file_data TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    `);
    await pool.query(
      'CREATE INDEX IF NOT EXISTS idx_ir_mir_project_kind ON ir_mir_uploads(project_id, kind)',
    ).catch(() => {});
    await pool.query(
      'CREATE INDEX IF NOT EXISTS idx_ir_mir_location_phase ON ir_mir_uploads(location_id, phase)',
    ).catch(() => {});
    console.log('ensureIrMirUploadsTable: ok');
  } catch (e) {
    console.warn('ensureIrMirUploadsTable:', e.message);
  }
}

function _isAllowedPrivatePair(a, b) {
  const x = String(a || '').trim().toLowerCase();
  const y = String(b || '').trim().toLowerCase();
  const manager = 'islam.shams2050@gmail.com';
  const admin = 'mouhammedhelal@gmail.com';
  return (x === manager && y === admin) || (x === admin && y === manager);
}


function _extractUserContext(req) {
  const body = req.body || {};
  const query = req.query || {};
  const userIdRaw = body.userId ?? body.user_id ?? query.userId ?? query.user_id;
  const userName = body.userName ?? body.user_name ?? query.userName ?? query.user_name ?? null;
  const userEmail = body.userEmail ?? body.user_email ?? query.userEmail ?? query.user_email ?? body.email ?? query.email ?? null;
  const userId = userIdRaw != null && String(userIdRaw).trim() !== '' ? parseInt(userIdRaw, 10) : null;
  return {
    userId: Number.isNaN(userId) ? null : userId,
    userName: userName != null ? String(userName) : null,
    userEmail: userEmail != null ? String(userEmail).trim().toLowerCase() : null,
  };
}

async function _insertActivityLog({ req, statusCode, details }) {
  try {
    if (req.path === '/activity-logs') return;
    const ctx = _extractUserContext(req);
    const action = _resolveActivityAction(req.method, req.path);
    await pool.query(
      `INSERT INTO activity_logs (created_at, action_type, action_label, endpoint, method, user_id, user_name, user_email, status_code, details)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [
        new Date().toISOString(),
        action.type,
        action.label,
        req.path,
        req.method,
        ctx.userId,
        ctx.userName,
        ctx.userEmail,
        statusCode,
        details,
      ]
    );
  } catch (_) {}
}

function _resolveActivityAction(method, path) {
  const m = String(method || '').toUpperCase();
  const p = String(path || '');
  if (m === 'POST' && p === '/auth/login') return { type: 'login', label: 'تسجيل دخول' };
  if (p.startsWith('/attendance') && m === 'POST') return { type: 'attendance_record', label: 'تسجيل حضور/انصراف' };
  if (p.startsWith('/daily-reports') && m === 'GET') return { type: 'daily_report_view', label: 'عرض تقرير يومي' };
  if (p.startsWith('/daily-reports') && m === 'POST') return { type: 'daily_report_create', label: 'إنشاء تقرير يومي' };
  if (p.startsWith('/daily-reports') && m === 'PUT') return { type: 'daily_report_update', label: 'تعديل تقرير يومي' };
  if (p.startsWith('/daily-reports') && m === 'DELETE') return { type: 'daily_report_delete', label: 'حذف تقرير يومي' };
  if (p.startsWith('/detailed-reports') && m === 'GET') return { type: 'detailed_report_view', label: 'عرض تقرير مفصل' };
  if (p.startsWith('/detailed-reports') && m === 'POST') return { type: 'detailed_report_create', label: 'إنشاء تقرير مفصل' };
  if (p.startsWith('/detailed-reports') && m === 'PUT') return { type: 'detailed_report_update', label: 'تعديل تقرير مفصل' };
  if (p.startsWith('/detailed-reports') && m === 'DELETE') return { type: 'detailed_report_delete', label: 'حذف تقرير مفصل' };
  if (p.startsWith('/users') && m === 'POST') return { type: 'user_create', label: 'إنشاء مستخدم' };
  if (p.startsWith('/users') && m === 'PUT') return { type: 'user_update', label: 'تعديل مستخدم' };
  if (p.startsWith('/users') && m === 'DELETE') return { type: 'user_delete', label: 'حذف مستخدم' };
  if (p.startsWith('/projects') && m === 'POST') return { type: 'project_create', label: 'إنشاء مشروع' };
  if (p.startsWith('/projects') && m === 'PUT') return { type: 'project_update', label: 'تعديل مشروع' };
  if (p.startsWith('/projects') && m === 'DELETE') return { type: 'project_delete', label: 'حذف مشروع' };
  if (p === '/activity-logs' && m === 'GET') return { type: 'activity_log_view', label: 'عرض سجل الحركة' };
  return { type: 'other', label: 'حركة أخرى' };
}

app.use((req, res, next) => {
  const startedAt = Date.now();
  res.on('finish', () => {
    const elapsed = Date.now() - startedAt;
    const queryJson = Object.keys(req.query || {}).length > 0 ? `query=${JSON.stringify(req.query)}` : '';
    const details = `${queryJson} elapsed_ms=${elapsed}`.trim();
    _insertActivityLog({ req, statusCode: res.statusCode, details });
  });
  next();
});

app.get('/', (req, res) => {
  res.json({ ok: true, message: 'Wood & More API', docs: 'Use POST /auth/login for login, /users, /projects, etc.' });
});

// Support Neon / any cloud PostgreSQL: set DATABASE_URL (with ?sslmode=require).
// Or use PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD for local/other.
const databaseUrl = process.env.DATABASE_URL;
const pool = databaseUrl
  ? new Pool({
      connectionString: databaseUrl,
      ssl: databaseUrl.includes('sslmode=require') || databaseUrl.includes('neon.tech')
        ? { rejectUnauthorized: false }
        : false,
    })
  : new Pool({
      host: process.env.PGHOST || 'localhost',
      port: parseInt(process.env.PGPORT || '5432', 10),
      database: process.env.PGDATABASE || 'wood_more',
      user: process.env.PGUSER || 'wood_more',
      password: process.env.PGPASSWORD || 'wood_more',
    });

// One-time migration: add password column if missing (e.g. Docker volume created before it existed)
async function ensurePasswordColumn() {
  try {
    await pool.query(`
      ALTER TABLE users ADD COLUMN IF NOT EXISTS password TEXT NOT NULL DEFAULT '0000'
    `);
  } catch (e) {
    console.warn('ensurePasswordColumn:', e.message);
  }
}

async function ensureSystemLockTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    `);
    await pool.query(
      `INSERT INTO app_settings (key, value) VALUES ('system_locked', '0') ON CONFLICT (key) DO NOTHING`
    );
  } catch (e) {
    console.warn('ensureSystemLockTable:', e.message);
  }
}

async function ensureUserHomeIconOrderTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS user_home_icon_orders (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        icon_order_json TEXT NOT NULL DEFAULT '[]'
      )
    `);
  } catch (e) {
    console.warn('ensureUserHomeIconOrderTable:', e.message);
  }
}

async function ensureAttendanceCalendarDateColumn() {
  try {
    await pool.query(
      'ALTER TABLE attendance_records ADD COLUMN IF NOT EXISTS calendar_date TEXT'
    );
  } catch (e) {
    console.warn('ensureAttendanceCalendarDateColumn:', e.message);
  }
}

/** تطبيق seed هيكلة Z1_EMAAR_F من الملف (آمن للتكرار بفضل NOT EXISTS داخل SQL). */
async function ensureZ1EmaarFProjectLocationsSeeded() {
  try {
    const sqlPath = path.join(__dirname, 'scripts', 'seed_z1_emaar_f_project_locations.sql');
    if (!fs.existsSync(sqlPath)) {
      console.warn('ensureZ1EmaarFProjectLocationsSeeded: file not found', sqlPath);
      return;
    }
    const raw = fs.readFileSync(sqlPath, 'utf8');
    const chunks = splitSqlChunks(raw);
    let ran = 0;
    for (const chunk of chunks) {
      const s = chunk.trim();
      if (!s.startsWith('INSERT INTO')) continue;
      await pool.query(s);
      ran += 1;
    }
    if (ran > 0) {
      console.log(`ensureZ1EmaarFProjectLocationsSeeded: executed ${ran} SQL chunk(s)`);
    }
  } catch (e) {
    console.warn('ensureZ1EmaarFProjectLocationsSeeded:', e.message);
  }
}

async function ensureHomeIconsVisibilitySetting() {
  try {
    const defaultConfig = {
      site_engineer: {
        attendance: true,
        today_work_plan: true,
        tomorrow_work_plan: true,
        engineer_withdraw_materials: true,
        engineer_finances: true,
        operation_reports: true,
        detailed_report: true,
        engineer_projects: true,
        ir_mir: true,
        ms_sd: true,
        mos_itp: true,
      },
      accountant: {
        accountant_custody: true,
        accountant_finance: true,
      },
      site_engineer_manager: {
        attendance_reports: true,
        work_plan_tracking_report: true,
        new_icon: true,
        operation_reports_tracking: true,
        aggregated_detailed_daily: true,
        contractor_report: true,
        ir_mir: true,
        warehouses_view: true,
        ms_sd: true,
        mos_itp: true,
      },
      general_supervisor: {
        attendance: true,
        attendance_reports: true,
        work_plan_tracking_report: true,
        new_icon: true,
        operation_reports_tracking: true,
        aggregated_detailed_daily: true,
        contractor_report: true,
        ir_mir: true,
        warehouses_view: true,
        ms_sd: true,
        mos_itp: true,
      },
      operation_manager: {
        attendance_reports: true,
        work_plan_tracking_report: true,
        postpone_fines_reports: true,
        new_icon: true,
        operation_reports_tracking: true,
        aggregated_detailed_daily: true,
        contractor_report: true,
        ir_mir: true,
        warehouses_view: true,
        ms_sd: true,
        qs_invs: true,
        mos_itp: true,
      },
      app_admin: {
        attendance_reports: true,
        work_plan_tracking_report: true,
        postpone_fines_reports: true,
        new_icon: true,
        operation_reports_tracking: true,
        daily_movement: true,
        reports: true,
        aggregated_detailed_daily: true,
        contractor_report: true,
        admin_project_structure: true,
        admin_dashboard: true,
        activity_logs: true,
        dashboard: true,
        ir_mir: true,
        warehouses_view: true,
        ms_sd: true,
        qs_invs: true,
        mos_itp: true,
      },
      document_controller: {
        ir_mir: true,
        ms_sd: true,
        qs_invs: true,
        mos_itp: true,
        warehouses_view: true,
        admin_dashboard: true,
      },
    };
    await pool.query(
      `INSERT INTO app_settings (key, value) VALUES ('home_icons_visibility', $1) ON CONFLICT (key) DO NOTHING`,
      [JSON.stringify(defaultConfig)]
    );
  } catch (e) {
    console.warn('ensureHomeIconsVisibilitySetting:', e.message);
  }
}

// إنشاء جداول التقرير المفصل تلقائياً إذا لم تكن موجودة (لتجنب خطأ relation "detailed_reports" does not exist)
async function ensureDetailedReportsTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS work_phases (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS project_locations (
        id SERIAL PRIMARY KEY,
        project_id INTEGER NOT NULL REFERENCES projects(id),
        parent_id INTEGER REFERENCES project_locations(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'folder' CHECK (type IN ('folder', 'work_site')),
        display_order INTEGER NOT NULL DEFAULT 0
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS detailed_reports (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id),
        user_name TEXT NOT NULL,
        report_datetime TEXT NOT NULL,
        project_id INTEGER REFERENCES projects(id),
        project_name TEXT,
        supervisor_id INTEGER REFERENCES supervisors(id),
        created_at TEXT NOT NULL,
        summary TEXT
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS detailed_report_lines (
        id SERIAL PRIMARY KEY,
        detailed_report_id INTEGER NOT NULL REFERENCES detailed_reports(id) ON DELETE CASCADE,
        contractor_id INTEGER REFERENCES contractors(id),
        contractor_workers_count INTEGER NOT NULL DEFAULT 0 CHECK (contractor_workers_count >= 0),
        self_workers_count INTEGER NOT NULL DEFAULT 0 CHECK (self_workers_count >= 0 AND self_workers_count <= 10),
        zone_id INTEGER REFERENCES zones(id),
        building_id INTEGER REFERENCES buildings(id),
        location_id INTEGER REFERENCES project_locations(id),
        phase_id INTEGER NOT NULL REFERENCES work_phases(id),
        workers_count INTEGER NOT NULL CHECK (workers_count >= 0)
      )
    `);
    await pool.query(`ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS project_name TEXT`);
    await pool.query(`ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS summary TEXT`);
    await pool.query(`ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS expenses_json TEXT`);
    await pool.query(`ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS attachments_json TEXT`).catch(() => {});
    await pool.query(`ALTER TABLE detailed_reports ADD COLUMN IF NOT EXISTS executed_today_summary TEXT`).catch(() => {});
    try {
      await pool.query(`ALTER TABLE detailed_reports ALTER COLUMN project_id DROP NOT NULL`);
    } catch (_) {}
    await pool.query(`ALTER TABLE detailed_report_lines ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES project_locations(id)`).catch(() => {});
    await pool.query(`ALTER TABLE detailed_report_lines ADD COLUMN IF NOT EXISTS manual_work_location TEXT`).catch(() => {});
    // قواعد قديمة: كان contractor_id إجبارياً — الواجهة تسمح بـ «لايوجد مقاول»
    try {
      await pool.query(`ALTER TABLE detailed_report_lines ALTER COLUMN contractor_id DROP NOT NULL`);
    } catch (_) {}
    // السماح بقيمة 0 في عدد العمال (بدلاً من 1 كحد أدنى).
    try {
      await pool.query(`ALTER TABLE detailed_report_lines DROP CONSTRAINT IF EXISTS detailed_report_lines_workers_count_check`);
      await pool.query(`ALTER TABLE detailed_report_lines ADD CONSTRAINT detailed_report_lines_workers_count_check CHECK (workers_count >= 0)`);
    } catch (_) {}
    // تأكيد وجود مراحل العمل القياسية (5 مراحل) دائماً.
    // ملاحظة: قد توجد مراحل قديمة إضافية في بعض قواعد البيانات؛ لا نحذفها هنا لتجنب كسر بيانات قديمة،
    // لكن واجهة التطبيق ستعرض فقط المراحل القياسية عبر مسار /work-phases.
    const standardPhases = [
      'تركيب اكسسوارات',
      'تقطيع WPC',
      'تركيب WPC',
      'معالجة',
      'دهان',
      'تشوين',
      'تركيب ارضيات',
      'تركيب Q.round + وزر',
    ];
    const existing = await pool.query('SELECT name FROM work_phases');
    const existingNames = new Set(existing.rows.map(r => String(r.name)));
    for (const name of standardPhases) {
      if (!existingNames.has(name)) {
        await pool.query('INSERT INTO work_phases (name) VALUES ($1)', [name]);
      }
    }
    console.log('ensureDetailedReportsTables: ok');
  } catch (e) {
    console.warn('ensureDetailedReportsTables:', e.message);
  }
}

// هيكلة المخازن: location_materials + location_withdrawal
async function ensureLocationMaterialsTables() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS location_materials (
        id SERIAL PRIMARY KEY,
        location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
        phase TEXT NOT NULL DEFAULT 'first_fix',
        material_name TEXT NOT NULL,
        quantity TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT ''
      )
    `);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS location_withdrawal (
        id SERIAL PRIMARY KEY,
        location_id INTEGER NOT NULL REFERENCES project_locations(id) ON DELETE CASCADE,
        phase TEXT NOT NULL DEFAULT 'first_fix',
        user_id INTEGER NOT NULL REFERENCES users(id),
        user_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        disbursement_permit_images_json TEXT,
        delivery_permit_images_json TEXT,
        UNIQUE(location_id, phase)
      )
    `);
    await pool.query(`ALTER TABLE location_materials ADD COLUMN IF NOT EXISTS phase TEXT NOT NULL DEFAULT 'first_fix'`).catch(() => {});
    await pool.query(`ALTER TABLE location_withdrawal ADD COLUMN IF NOT EXISTS phase TEXT NOT NULL DEFAULT 'first_fix'`).catch(() => {});
    await pool.query(`ALTER TABLE location_withdrawal DROP CONSTRAINT IF EXISTS location_withdrawal_location_id_key`).catch(() => {});
    await pool.query(`CREATE UNIQUE INDEX IF NOT EXISTS idx_location_withdrawal_location_phase_unique ON location_withdrawal(location_id, phase)`).catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_location_materials_location_id ON location_materials(location_id)').catch(() => {});
    await pool.query('CREATE INDEX IF NOT EXISTS idx_location_withdrawal_location_id ON location_withdrawal(location_id)').catch(() => {});
    console.log('ensureLocationMaterialsTables: ok');
  } catch (e) {
    console.warn('ensureLocationMaterialsTables:', e.message);
  }
}

// ——— Auth (email + password) ———
app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const emailNorm = (email || '').trim().toLowerCase();
    const pwd = (password || '').trim();
    if (!emailNorm || !pwd) return res.status(400).json({ error: 'email and password required' });
    const lockEmailBypass = 'mouhammedhelal@gmail.com';
    const lockR = await pool.query(
      `SELECT value FROM app_settings WHERE key = 'system_locked' LIMIT 1`
    );
    const isLocked = lockR.rows.length > 0 && String(lockR.rows[0].value || '0').trim() === '1';
    if (isLocked && emailNorm !== lockEmailBypass) {
      return res.status(423).json({
        error: 'system_locked',
        message: 'System Locked for maintainance please try again later',
      });
    }
    const r = await pool.query(
      'SELECT id, name, email, role, COALESCE(password, \'0000\') AS password FROM users WHERE LOWER(TRIM(email)) = $1',
      [emailNorm]
    );
    if (r.rows.length === 0) return res.status(401).json(null);
    const row = r.rows[0];
    const stored = (row.password || '0000').trim();
    if (stored !== pwd) return res.status(401).json(null);
    res.json({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/system-lock', async (req, res) => {
  try {
    const r = await pool.query(
      `SELECT value FROM app_settings WHERE key = 'system_locked' LIMIT 1`
    );
    const locked = r.rows.length > 0 && String(r.rows[0].value || '0').trim() === '1';
    res.json({ locked });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/system-lock', async (req, res) => {
  try {
    const requesterEmail = String(req.body?.requesterEmail || '').trim().toLowerCase();
    if (requesterEmail !== PRIMARY_APP_ADMIN_EMAIL) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const locked = req.body?.locked === true;
    await pool.query(
      `INSERT INTO app_settings (key, value) VALUES ('system_locked', $1)
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`,
      [locked ? '1' : '0']
    );
    res.json({ ok: true, locked });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/home-icons-visibility', async (req, res) => {
  try {
    const r = await pool.query(`SELECT value FROM app_settings WHERE key = 'home_icons_visibility' LIMIT 1`);
    if (r.rows.length === 0) return res.json({});
    const raw = String(r.rows[0].value || '').trim();
    if (!raw) return res.json({});
    try {
      return res.json(JSON.parse(raw));
    } catch (_) {
      return res.json({});
    }
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/users/:id/home-icon-order', async (req, res) => {
  try {
    const userId = parseInt(String(req.params.id), 10);
    if (!Number.isFinite(userId)) return res.status(400).json({ error: 'invalid user id' });
    const r = await pool.query(
      'SELECT icon_order_json FROM user_home_icon_orders WHERE user_id = $1',
      [userId]
    );
    if (r.rows.length === 0) return res.json({ iconOrder: [] });
    const raw = String(r.rows[0].icon_order_json || '').trim();
    if (!raw) return res.json({ iconOrder: [] });
    try {
      const parsed = JSON.parse(raw);
      return res.json({ iconOrder: Array.isArray(parsed) ? parsed : [] });
    } catch (_) {
      return res.json({ iconOrder: [] });
    }
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/users/:id/home-icon-order', async (req, res) => {
  try {
    const userId = parseInt(String(req.params.id), 10);
    if (!Number.isFinite(userId)) return res.status(400).json({ error: 'invalid user id' });
    const requesterUserId = parseInt(String(req.body?.requesterUserId ?? ''), 10);
    if (!Number.isFinite(requesterUserId) || requesterUserId !== userId) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const owner = await pool.query('SELECT id FROM users WHERE id = $1', [userId]);
    if (owner.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const iconOrder = req.body?.iconOrder;
    if (!Array.isArray(iconOrder)) return res.status(400).json({ error: 'iconOrder array required' });
    const cleaned = iconOrder
      .map((value) => String(value || '').trim())
      .filter((value) => value.length > 0);
    await pool.query(
      `INSERT INTO user_home_icon_orders (user_id, icon_order_json)
       VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE SET icon_order_json = EXCLUDED.icon_order_json`,
      [userId, JSON.stringify(cleaned)]
    );
    res.json({ ok: true, iconOrder: cleaned });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/home-icons-visibility/:role', async (req, res) => {
  try {
    const role = String(req.params.role || '').trim();
    const allowedRoles = new Set(['site_engineer', 'site_engineer_manager', 'general_supervisor', 'operation_manager', 'app_admin', 'accountant', 'document_controller']);
    if (!allowedRoles.has(role)) return res.status(400).json({ error: 'invalid role' });

    const requesterEmail = String(req.body?.requesterEmail || '').trim().toLowerCase();
    if (requesterEmail !== 'mouhammedhelal@gmail.com') {
      return res.status(403).json({ error: 'forbidden' });
    }
    const icons = req.body?.icons;
    if (!icons || typeof icons !== 'object' || Array.isArray(icons)) {
      return res.status(400).json({ error: 'icons map required' });
    }

    const r = await pool.query(`SELECT value FROM app_settings WHERE key = 'home_icons_visibility' LIMIT 1`);
    let all = {};
    if (r.rows.length > 0) {
      try {
        all = JSON.parse(String(r.rows[0].value || '{}')) || {};
      } catch (_) {}
    }
    all[role] = {};
    for (const [key, value] of Object.entries(icons)) {
      all[role][String(key)] = value === true;
    }
    await pool.query(
      `INSERT INTO app_settings (key, value) VALUES ('home_icons_visibility', $1)
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`,
      [JSON.stringify(all)]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Users ———
app.get('/users/by-email', async (req, res) => {
  try {
    const email = (req.query.email || '').trim().toLowerCase();
    const r = await pool.query('SELECT id, name, email, role FROM users WHERE email = $1', [email]);
    if (r.rows.length === 0) return res.json(null);
    const row = r.rows[0];
    res.json({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/users', async (req, res) => {
  try {
    const requesterEmail = String(req.query.requesterEmail || '').trim().toLowerCase();
    const r = await pool.query('SELECT id, name, email, role FROM users ORDER BY name');
    const out = r.rows
      .map(row => ({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role }))
      .filter((u) => requesterEmail === PRIMARY_APP_ADMIN_EMAIL || String(u.email).trim().toLowerCase() !== PRIMARY_APP_ADMIN_EMAIL);
    res.json(out);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/users/site-engineers', async (req, res) => {
  try {
    const r = await pool.query("SELECT id, name, email, role FROM users WHERE role = 'site_engineer' ORDER BY name");
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name, email: row.email, role: row.role })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/users', async (req, res) => {
  try {
    const { name, email, role, password } = req.body;
    const pwd = (password != null && String(password).trim() !== '') ? String(password).trim() : '0000';
    const r = await pool.query(
      'INSERT INTO users (name, email, role, password) VALUES ($1, $2, $3, $4) RETURNING id',
      [name, (email || '').trim().toLowerCase(), role, pwd]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/users/:id', async (req, res) => {
  try {
    const requesterEmail = String(req.body?.requesterEmail || '').trim().toLowerCase();
    const target = await pool.query('SELECT email FROM users WHERE id = $1', [req.params.id]);
    if (target.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const targetEmail = String(target.rows[0].email || '').trim().toLowerCase();
    if (targetEmail === PRIMARY_APP_ADMIN_EMAIL && requesterEmail !== PRIMARY_APP_ADMIN_EMAIL) {
      return res.status(403).json({ error: 'forbidden_primary_admin' });
    }
    const { name, email, role, password } = req.body;
    const nextEmail = String(email || '').trim().toLowerCase();
    if (nextEmail === PRIMARY_APP_ADMIN_EMAIL && requesterEmail !== PRIMARY_APP_ADMIN_EMAIL) {
      return res.status(403).json({ error: 'forbidden_primary_admin' });
    }
    const updates = ['name = $1', 'email = $2', 'role = $3'];
    const params = [name, nextEmail, role];
    let i = 4;
    if (password != null && String(password).trim() !== '') {
      updates.push(`password = $${i}`);
      params.push(String(password).trim());
      i++;
    }
    params.push(req.params.id);
    await pool.query(`UPDATE users SET ${updates.join(', ')} WHERE id = $${i}`, params);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

async function deleteUserAndDependencies(client, userId) {
  const id = parseInt(userId, 10);
  if (Number.isNaN(id)) throw new Error('invalid user id');

  await client.query('DELETE FROM executed_plans WHERE user_id = $1', [id]);
  await client.query(
    'UPDATE executed_plans SET sem_resolved_by_user_id = NULL WHERE sem_resolved_by_user_id = $1',
    [id],
  );
  await client.query('DELETE FROM detailed_reports WHERE user_id = $1', [id]);
  await client.query('DELETE FROM attendance_records WHERE user_id = $1', [id]);
  await client.query('DELETE FROM daily_reports WHERE user_id = $1', [id]);
  await client.query('DELETE FROM engineer_custody WHERE user_id = $1', [id]);
  await client.query('DELETE FROM engineer_balance WHERE user_id = $1', [id]);
  await client.query('DELETE FROM location_withdrawal WHERE user_id = $1', [id]);
  await client.query('DELETE FROM withdrawal_requests WHERE engineer_user_id = $1', [id]);
  await client.query('DELETE FROM ir_mir_uploads WHERE user_id = $1', [id]);
  await client.query('DELETE FROM notifications WHERE recipient_user_id = $1', [id]);
  await client.query('DELETE FROM user_home_icon_orders WHERE user_id = $1', [id]);
  await client.query('UPDATE project_stock_ledger SET user_id = NULL WHERE user_id = $1', [id]);
  await client.query('UPDATE activity_logs SET user_id = NULL WHERE user_id = $1', [id]);
}

app.delete('/users/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    const requesterEmail = String(req.query.requesterEmail || req.body?.requesterEmail || '').trim().toLowerCase();
    const userId = parseInt(req.params.id, 10);
    if (Number.isNaN(userId)) return res.status(400).json({ error: 'invalid id' });
    const target = await client.query('SELECT email FROM users WHERE id = $1', [userId]);
    if (target.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const targetEmail = String(target.rows[0].email || '').trim().toLowerCase();
    if (targetEmail === PRIMARY_APP_ADMIN_EMAIL && requesterEmail !== PRIMARY_APP_ADMIN_EMAIL) {
      return res.status(403).json({ error: 'forbidden_primary_admin' });
    }
    await client.query('BEGIN');
    await deleteUserAndDependencies(client, userId);
    await client.query('DELETE FROM users WHERE id = $1', [userId]);
    await client.query('COMMIT');
    res.json({ ok: true });
  } catch (e) {
    try {
      await client.query('ROLLBACK');
    } catch (_) {}
    const msg = String(e.message || e);
    if (msg.includes('foreign key') || msg.includes('violates')) {
      return res.status(409).json({
        error: 'user_has_linked_data',
        message: 'تعذر حذف المستخدم لوجود بيانات مرتبطة به في النظام',
      });
    }
    res.status(500).json({ error: msg });
  } finally {
    client.release();
  }
});

// ——— Projects ———
app.get('/projects', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM projects ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/projects', async (req, res) => {
  try {
    const name = String(req.body?.name || '').trim();
    if (!name) return res.status(400).json({ error: 'name required' });
    const r = await pool.query(
      `INSERT INTO projects (name)
       VALUES ($1)
       ON CONFLICT ((lower(btrim(name)))) DO UPDATE SET name = EXCLUDED.name
       RETURNING id`,
      [name]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/projects/:id', async (req, res) => {
  try {
    await pool.query('UPDATE projects SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/projects/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM project_stock WHERE project_id = $1', [req.params.id]);
    await pool.query('DELETE FROM project_locations WHERE project_id = $1', [req.params.id]);
    await pool.query('DELETE FROM zones WHERE project_id = $1', [req.params.id]);
    await pool.query('DELETE FROM projects WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Project locations (هيكل مواقع المشروع: folder / work_site) ———
app.get('/project-locations', async (req, res) => {
  try {
    const r = await pool.query(
      'SELECT id, project_id, parent_id, name, type, display_order FROM project_locations WHERE project_id = $1 ORDER BY display_order, id',
      [req.query.projectId]
    );
    res.json(r.rows.map(row => ({
      id: parseInt(row.id),
      project_id: parseInt(row.project_id),
      parent_id: row.parent_id != null ? parseInt(row.parent_id) : null,
      name: row.name,
      type: row.type,
      display_order: parseInt(row.display_order || 0),
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/project-locations', async (req, res) => {
  try {
    const { projectId, parentId, name, type, display_order } = req.body;
    const order = display_order != null ? parseInt(display_order) : 0;
    const r = await pool.query(
      'INSERT INTO project_locations (project_id, parent_id, name, type, display_order) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [projectId, parentId ?? null, name, type || 'folder', order]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/project-locations/:id', async (req, res) => {
  try {
    const { name, display_order } = req.body;
    if (name != null) {
      await pool.query('UPDATE project_locations SET name = $1 WHERE id = $2', [name, req.params.id]);
    }
    if (display_order != null) {
      await pool.query('UPDATE project_locations SET display_order = $1 WHERE id = $2', [display_order, req.params.id]);
    }
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/project-locations/:id', async (req, res) => {
  try {
    // CASCADE in DB will delete children; optionally delete recursively in app for consistency
    await pool.query('DELETE FROM project_locations WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Zones ———
app.get('/zones', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, project_id, name FROM zones WHERE project_id = $1 ORDER BY name', [req.query.projectId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), project_id: parseInt(row.project_id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/zones', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO zones (project_id, name) VALUES ($1, $2) RETURNING id', [req.body.projectId, req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/zones/:id', async (req, res) => {
  try {
    await pool.query('UPDATE zones SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/zones/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM buildings WHERE zone_id = $1', [req.params.id]);
    await pool.query('DELETE FROM zones WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Buildings ———
app.get('/buildings', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, zone_id, name, storage_info, model_details, cut_list FROM buildings WHERE zone_id = $1 ORDER BY name', [req.query.zoneId]);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), zone_id: parseInt(row.zone_id), name: row.name,
      storage_info: row.storage_info, model_details: row.model_details, cut_list: row.cut_list
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/buildings', async (req, res) => {
  try {
    const { zoneId, name, storageInfo, modelDetails, cutList } = req.body;
    const r = await pool.query(
      'INSERT INTO buildings (zone_id, name, storage_info, model_details, cut_list) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [zoneId, name, storageInfo || null, modelDetails || null, cutList || null]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/buildings/:id', async (req, res) => {
  try {
    const { name, storageInfo, modelDetails, cutList } = req.body;
    await pool.query('UPDATE buildings SET name = $1, storage_info = $2, model_details = $3, cut_list = $4 WHERE id = $5', [name, storageInfo || null, modelDetails || null, cutList || null, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/buildings/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM units WHERE building_id = $1', [req.params.id]);
    await pool.query('DELETE FROM building_materials WHERE building_id = $1', [req.params.id]);
    await pool.query('DELETE FROM building_cutlist_images WHERE building_id = $1', [req.params.id]);
    await pool.query('DELETE FROM buildings WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Attendance ———
app.post('/attendance', async (req, res) => {
  try {
    const b = req.body;
    const userId = parseInt(String(b.userId || ''), 10);
    const type = String(b.type || '');
    let calendarDate = String(b.calendarDate || '').trim();
    const dateRe = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRe.test(calendarDate) && b.dateTime) {
      const m = String(b.dateTime).match(/^(\d{4}-\d{2}-\d{2})/);
      if (m) calendarDate = m[1];
    }
    if (!Number.isInteger(userId) || (type !== 'check_in' && type !== 'check_out') || !dateRe.test(calendarDate)) {
      return res.status(400).json({ error: 'userId ونوع التسجيل (check_in / check_out) وcalendarDate بصيغة YYYY-MM-DD مطلوبة' });
    }
    const rawPid = b.projectId;
    const projectId =
      rawPid === null || rawPid === undefined || rawPid === ''
        ? null
        : parseInt(String(rawPid), 10);
    const projectName = b.projectName != null ? String(b.projectName) : '';

    let dup;
    if (projectId != null && !Number.isNaN(projectId)) {
      dup = await pool.query(
        `SELECT id FROM attendance_records
         WHERE user_id = $1 AND type = $2
         AND (
           calendar_date = $3
           OR (calendar_date IS NULL AND SUBSTRING(date_time, 1, 10) = $3)
         )
         AND project_id = $4
         LIMIT 1`,
        [userId, type, calendarDate, projectId]
      );
    } else {
      dup = await pool.query(
        `SELECT id FROM attendance_records
         WHERE user_id = $1 AND type = $2
         AND (
           calendar_date = $3
           OR (calendar_date IS NULL AND SUBSTRING(date_time, 1, 10) = $3)
         )
         AND project_id IS NULL AND TRIM(COALESCE(project_name, '')) = TRIM($4::text)
         LIMIT 1`,
        [userId, type, calendarDate, projectName]
      );
    }
    if (dup.rows.length > 0) {
      const msg =
        type === 'check_in'
          ? 'تم تسجيل الحضور مسبقاً لهذا المشروع اليوم. لا داعي لإعادة التسجيل مرة أخرى.'
          : 'تم تسجيل الانصراف مسبقاً لهذا المشروع اليوم. لا داعي لإعادة التسجيل مرة أخرى.';
      return res.status(409).json({ error: msg });
    }

    const r = await pool.query(
      'INSERT INTO attendance_records (user_id, user_name, type, date_time, calendar_date, location, project_id, project_name, notes) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id',
      [
        userId,
        b.userName,
        b.type,
        b.dateTime,
        calendarDate,
        b.location || '',
        Number.isNaN(projectId) ? null : projectId,
        b.projectName || null,
        b.notes || null,
      ]
    );
    const isCheckIn = String(b.type || '') === 'check_in';
    const actionLabel = isCheckIn ? 'الحضور' : 'الانصراف';
    const projectNameDisplay = String(b.projectName || '').trim() || 'بدون مشروع';
    const body = `قام "${String(b.userName || '')}" بتسجيل ${actionLabel} بمشروع "${projectNameDisplay}"`;
    await pool.query(
      `INSERT INTO notifications (
        recipient_user_id, recipient_role, title, body, event_type,
        actor_user_id, actor_user_name, project_name, created_at, is_read
      )
      SELECT id, role, $1, $2, $3, $4, $5, $6, $7, FALSE
      FROM users
      WHERE role IN ('site_engineer_manager', 'operation_manager', 'app_admin')`,
      [
        'تنبيه حضور/انصراف',
        body,
        `attendance_${String(b.type || '')}`,
        b.userId || null,
        b.userName || null,
        b.projectName || null,
        new Date().toISOString(),
      ]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/notifications', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId || ''), 10);
    if (!Number.isInteger(userId)) {
      return res.status(400).json({ error: 'userId is required' });
    }
    const r = await pool.query(
      `SELECT * FROM notifications
       WHERE recipient_user_id = $1
       ORDER BY created_at DESC`,
      [userId]
    );
    res.json(
      r.rows.map((row) => ({
        id: parseInt(row.id),
        recipient_user_id: parseInt(row.recipient_user_id),
        recipient_role: row.recipient_role,
        title: row.title,
        body: row.body,
        event_type: row.event_type,
        actor_user_id: row.actor_user_id != null ? parseInt(row.actor_user_id) : null,
        actor_user_name: row.actor_user_name,
        project_name: row.project_name,
        created_at: row.created_at,
        is_read: row.is_read === true,
        read_at: row.read_at,
      }))
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/notifications/unread-count', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId || ''), 10);
    if (!Number.isInteger(userId)) {
      return res.status(400).json({ error: 'userId is required' });
    }
    const r = await pool.query(
      'SELECT COUNT(*)::int AS count FROM notifications WHERE recipient_user_id = $1 AND is_read = FALSE',
      [userId]
    );
    res.json({ count: parseInt(r.rows[0]?.count || '0') });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/notifications/:id/read', async (req, res) => {
  try {
    const notificationId = parseInt(String(req.params.id || ''), 10);
    const userId = parseInt(String(req.body?.userId || req.query?.userId || ''), 10);
    if (!Number.isInteger(notificationId) || !Number.isInteger(userId)) {
      return res.status(400).json({ error: 'notification id and userId are required' });
    }
    await pool.query(
      'UPDATE notifications SET is_read = TRUE, read_at = $1 WHERE id = $2 AND recipient_user_id = $3',
      [new Date().toISOString(), notificationId, userId]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/private-chat/messages', async (req, res) => {
  try {
    const requesterEmail = String(req.query.requesterEmail || '')
      .trim()
      .toLowerCase();
    if (
      requesterEmail !== 'islam.shams2050@gmail.com' &&
      requesterEmail !== 'mouhammedhelal@gmail.com'
    ) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const r = await pool.query(
      `SELECT id, sender_email, sender_name, receiver_email, body, created_at
       FROM private_chat_messages
       WHERE (sender_email = $1 AND receiver_email = $2)
          OR (sender_email = $2 AND receiver_email = $1)
       ORDER BY created_at ASC, id ASC`,
      ['islam.shams2050@gmail.com', 'mouhammedhelal@gmail.com'],
    );
    res.json(
      r.rows.map((row) => ({
        id: parseInt(row.id, 10),
        sender_email: row.sender_email,
        sender_name: row.sender_name,
        receiver_email: row.receiver_email,
        body: row.body,
        created_at: row.created_at,
      })),
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/private-chat/messages', async (req, res) => {
  try {
    const b = req.body || {};
    const senderEmail = String(b.senderEmail || '')
      .trim()
      .toLowerCase();
    const receiverEmail = String(b.receiverEmail || '')
      .trim()
      .toLowerCase();
    const senderName = String(b.senderName || '').trim();
    const body = String(b.body || '').trim();
    if (!senderEmail || !receiverEmail || !senderName || !body) {
      return res.status(400).json({ error: 'missing fields' });
    }
    if (!_isAllowedPrivatePair(senderEmail, receiverEmail)) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const r = await pool.query(
      `INSERT INTO private_chat_messages
       (sender_email, sender_name, receiver_email, body, created_at)
       VALUES ($1,$2,$3,$4,$5)
       RETURNING id`,
      [senderEmail, senderName, receiverEmail, body, new Date().toISOString()],
    );
    res.json(parseInt(r.rows[0].id, 10));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/ir-mir/uploads', async (req, res) => {
  try {
    const projectId = parseInt(req.query.projectId ?? req.query.project_id ?? '', 10);
    if (Number.isNaN(projectId)) {
      return res.status(400).json({ error: 'projectId required' });
    }
    const kind = req.query.kind != null ? String(req.query.kind).trim().toLowerCase() : null;
    const mirName = req.query.mirName != null ? String(req.query.mirName).trim() : null;
    const locationIdRaw = req.query.locationId ?? req.query.location_id;
    const locationId =
      locationIdRaw != null && String(locationIdRaw).trim() !== ''
        ? parseInt(locationIdRaw, 10)
        : null;
    const phase = req.query.phase != null ? String(req.query.phase).trim().toLowerCase() : null;

    let sql =
      `SELECT id, project_id, user_id, user_name, kind, mir_name, location_id, phase,
              file_name, file_mime, file_data, notes, created_at
       FROM ir_mir_uploads WHERE project_id = $1`;
    const params = [projectId];
    let i = 2;
    if (kind === 'mir' || kind === 'ir') {
      sql += ` AND kind = $${i}`;
      params.push(kind);
      i += 1;
    }
    if (mirName != null && mirName !== '') {
      sql += ` AND LOWER(TRIM(COALESCE(mir_name,''))) = LOWER(TRIM($${i}))`;
      params.push(mirName);
      i += 1;
    }
    if (locationId != null && !Number.isNaN(locationId)) {
      sql += ` AND location_id = $${i}`;
      params.push(locationId);
      i += 1;
    }
    if (phase != null && phase !== '') {
      sql += ` AND LOWER(TRIM(COALESCE(phase,''))) = LOWER(TRIM($${i}))`;
      params.push(phase);
      i += 1;
    }
    sql += ' ORDER BY created_at DESC, id DESC';
    const r = await pool.query(sql, params);
    res.json(
      r.rows.map((row) => ({
        id: parseInt(row.id, 10),
        project_id: parseInt(row.project_id, 10),
        user_id: parseInt(row.user_id, 10),
        user_name: row.user_name,
        kind: row.kind,
        mir_name: row.mir_name,
        location_id: row.location_id != null ? parseInt(row.location_id, 10) : null,
        phase: row.phase,
        file_name: row.file_name,
        file_mime: row.file_mime,
        file_data: row.file_data,
        notes: row.notes,
        created_at: row.created_at,
      })),
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/ir-mir/uploads', async (req, res) => {
  try {
    const b = req.body || {};
    const projectId = parseInt(b.projectId ?? b.project_id ?? '', 10);
    const userId = parseInt(b.userId ?? b.user_id ?? '', 10);
    const userName = String(b.userName ?? b.user_name ?? '').trim();
    const kind = String(b.kind ?? '').trim().toLowerCase();
    const fileName = String(b.fileName ?? b.file_name ?? '').trim();
    const fileMime = String(b.fileMime ?? b.file_mime ?? '').trim();
    let fileData = String(b.fileData ?? b.file_data ?? '').trim();
    const notes = b.notes != null ? String(b.notes).trim() : null;

    if (Number.isNaN(projectId) || Number.isNaN(userId) || !userName || !kind || !fileName || !fileMime || !fileData) {
      return res.status(400).json({ error: 'missing required fields' });
    }
    if (kind !== 'mir' && kind !== 'ir') {
      return res.status(400).json({ error: 'invalid kind' });
    }

    let mirName = b.mirName != null ? String(b.mirName).trim() : b.mir_name != null ? String(b.mir_name).trim() : null;
    let locationId =
      b.locationId != null ? parseInt(b.locationId, 10) : b.location_id != null ? parseInt(b.location_id, 10) : null;
    let phase = b.phase != null ? String(b.phase).trim().toLowerCase() : null;

    if (kind === 'mir') {
      if (!mirName) return res.status(400).json({ error: 'mirName required for MIR' });
      locationId = null;
      phase = null;
    } else {
      mirName = null;
      if (locationId == null || Number.isNaN(locationId)) {
        return res.status(400).json({ error: 'locationId required for IR' });
      }
      const allowedPhase = new Set(['first_fix', 'second_fix', 'finish']);
      if (!phase || !allowedPhase.has(phase)) {
        return res.status(400).json({ error: 'invalid phase for IR' });
      }
      const loc = await pool.query(
        'SELECT id, project_id, type FROM project_locations WHERE id = $1',
        [locationId],
      );
      if (loc.rows.length === 0) {
        return res.status(400).json({ error: 'location not found' });
      }
      if (parseInt(loc.rows[0].project_id, 10) !== projectId) {
        return res.status(400).json({ error: 'location project mismatch' });
      }
      const locType = String(loc.rows[0].type || '');
      if (locType !== 'work_site' && locType !== 'folder') {
        return res.status(400).json({ error: 'invalid location type' });
      }
    }

    const proj = await pool.query('SELECT id FROM projects WHERE id = $1', [projectId]);
    if (proj.rows.length === 0) return res.status(400).json({ error: 'project not found' });
    const usr = await pool.query('SELECT id FROM users WHERE id = $1', [userId]);
    if (usr.rows.length === 0) return res.status(400).json({ error: 'user not found' });

    if (!fileData.startsWith('data:')) {
      fileData = `data:${fileMime};base64,${fileData}`;
    }

    const ins = await pool.query(
      `INSERT INTO ir_mir_uploads (
        project_id, user_id, user_name, kind, mir_name, location_id, phase,
        file_name, file_mime, file_data, notes, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
      RETURNING id`,
      [
        projectId,
        userId,
        userName,
        kind,
        mirName,
        locationId,
        phase,
        fileName,
        fileMime,
        fileData,
        notes || null,
        new Date().toISOString(),
      ],
    );
    const uploadId = parseInt(ins.rows[0].id, 10);
    const projRes = await pool.query('SELECT name FROM projects WHERE id = $1', [projectId]);
    const projName = projRes.rows.length ? projRes.rows[0].name : null;
    const kindLabel = kind === 'mir' ? 'MIR' : 'IR';
    const extra =
      kind === 'mir' && mirName
        ? ` — اسم ${kindLabel}: ${mirName}`
        : kind === 'ir' && phase
          ? ` — مرحلة: ${phase}`
          : '';
    await notifyAppAdminsOnDocumentUpload(pool, userId, userName, {
      title: `رفع مستند ${kindLabel}`,
      body:
        `قام "${userName}" برفع ملف "${fileName}" (${kindLabel}) — مشروع "${projName || 'غير محدد'}"${extra}\n` +
        `رقم المرفق: ${uploadId}`,
      eventType: kind === 'mir' ? 'mir_upload' : 'ir_upload',
      projectName: projName,
    });
    res.json(uploadId);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/ir-mir/uploads/:id', async (req, res) => {
  try {
    const requesterEmail = String(
      req.query.requesterEmail ?? req.body?.requesterEmail ?? '',
    )
      .trim()
      .toLowerCase();
    if (requesterEmail !== PRIMARY_APP_ADMIN_EMAIL.toLowerCase()) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
    const del = await pool.query('DELETE FROM ir_mir_uploads WHERE id = $1 RETURNING id', [
      id,
    ]);
    if (del.rowCount === 0) return res.status(404).json({ error: 'not found' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

async function _mapMsSdRecordRow(row, attachments, includeAudit) {
  const out = {
    id: parseInt(row.id, 10),
    project_id: parseInt(row.project_id, 10),
    kind: row.kind,
    record_name: row.record_name,
    notes: row.notes,
    attachments: (attachments || []).map((a) => ({
      id: parseInt(a.id, 10),
      record_id: parseInt(a.record_id, 10),
      file_name: a.file_name,
      file_mime: a.file_mime,
      file_data: a.file_data,
      created_at: a.created_at,
    })),
  };
  if (includeAudit) {
    out.user_id = parseInt(row.user_id, 10);
    out.user_name = row.user_name;
    out.created_at = row.created_at;
  }
  return out;
}

app.get('/ms-sd/records', async (req, res) => {
  try {
    const projectId = parseInt(req.query.projectId ?? req.query.project_id ?? '', 10);
    if (Number.isNaN(projectId)) {
      return res.status(400).json({ error: 'projectId required' });
    }
    const kind = String(req.query.kind ?? '').trim().toLowerCase();
    if (kind !== 'ms' && kind !== 'sd') {
      return res.status(400).json({ error: 'kind must be ms or sd' });
    }
    const requesterEmail = String(req.query.requesterEmail ?? '').trim();
    const includeAudit = _isPrimaryAppAdminEmail(requesterEmail);

    const recs = await pool.query(
      `SELECT id, project_id, user_id, user_name, kind, record_name, notes, created_at
       FROM ms_sd_records
       WHERE project_id = $1 AND kind = $2
       ORDER BY created_at DESC, id DESC`,
      [projectId, kind],
    );
    const out = [];
    for (const row of recs.rows) {
      const att = await pool.query(
        `SELECT id, record_id, file_name, file_mime, file_data, created_at
         FROM ms_sd_attachments WHERE record_id = $1 ORDER BY id ASC`,
        [row.id],
      );
      out.push(await _mapMsSdRecordRow(row, att.rows, includeAudit));
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/ms-sd/records', async (req, res) => {
  try {
    const b = req.body || {};
    const projectId = parseInt(b.projectId ?? b.project_id ?? '', 10);
    const userId = parseInt(b.userId ?? b.user_id ?? '', 10);
    const userName = String(b.userName ?? b.user_name ?? '').trim();
    const kind = String(b.kind ?? '').trim().toLowerCase();
    const recordName = String(b.recordName ?? b.record_name ?? '').trim();
    const notes = b.notes != null ? String(b.notes).trim() : null;
    const attachments = Array.isArray(b.attachments) ? b.attachments : [];

    if (
      Number.isNaN(projectId) ||
      Number.isNaN(userId) ||
      !userName ||
      !recordName ||
      (kind !== 'ms' && kind !== 'sd') ||
      attachments.length === 0
    ) {
      return res.status(400).json({ error: 'missing required fields' });
    }

    const usr = await pool.query('SELECT id, role FROM users WHERE id = $1', [userId]);
    if (usr.rows.length === 0) return res.status(400).json({ error: 'user not found' });
    if (String(usr.rows[0].role) !== 'document_controller') {
      return res.status(403).json({ error: 'only document controller can upload' });
    }

    const proj = await pool.query('SELECT id FROM projects WHERE id = $1', [projectId]);
    if (proj.rows.length === 0) return res.status(400).json({ error: 'project not found' });

    const prepared = [];
    for (const raw of attachments) {
      const fileName = String(raw.fileName ?? raw.file_name ?? '').trim();
      let fileMime = String(raw.fileMime ?? raw.file_mime ?? '').trim();
      let fileData = String(raw.fileData ?? raw.file_data ?? '').trim();
      if (!fileName || !fileData) {
        return res.status(400).json({ error: 'invalid attachment' });
      }
      const norm = _normalizeMsSdFileData(fileMime, fileData);
      fileMime = norm.mime;
      fileData = norm.data;
      if (_estimateBase64PayloadBytes(fileData) > MS_SD_MAX_FILE_BYTES) {
        return res.status(400).json({ error: `file too large (max ${MS_SD_MAX_FILE_BYTES} bytes)` });
      }
      prepared.push({ fileName, fileMime, fileData });
    }

    const createdAt = new Date().toISOString();
    const ins = await pool.query(
      `INSERT INTO ms_sd_records (
        project_id, user_id, user_name, kind, record_name, notes, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
      [projectId, userId, userName, kind, recordName, notes || null, createdAt],
    );
    const recordId = parseInt(ins.rows[0].id, 10);
    for (const att of prepared) {
      await pool.query(
        `INSERT INTO ms_sd_attachments (
          record_id, file_name, file_mime, file_data, created_at
        ) VALUES ($1,$2,$3,$4,$5)`,
        [recordId, att.fileName, att.fileMime, att.fileData, createdAt],
      );
    }

    const projRes = await pool.query('SELECT name FROM projects WHERE id = $1', [projectId]);
    const projName = projRes.rows.length ? projRes.rows[0].name : null;
    const kindLabel = kind === 'sd' ? 'SD' : 'MS';
    await notifyAppAdminsOnDocumentUpload(pool, userId, userName, {
      title: `رفع ${kindLabel} جديد`,
      body:
        `قام "${userName}" بإضافة "${recordName}" (${kindLabel}) — مشروع "${projName || 'غير محدد'}"\n` +
        `رقم السجل: ${recordId}`,
      eventType: kind === 'sd' ? 'sd_upload' : 'ms_upload',
      projectName: projName,
    });

    res.json(recordId);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.patch('/ms-sd/records/:id', async (req, res) => {
  try {
    const requesterEmail = String(
      req.query.requesterEmail ?? req.body?.requesterEmail ?? '',
    ).trim();
    if (!_isPrimaryAppAdminEmail(requesterEmail)) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });

    const existing = await pool.query('SELECT * FROM ms_sd_records WHERE id = $1', [id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'not found' });

    const b = req.body || {};
    const recordName =
      b.recordName != null
        ? String(b.recordName).trim()
        : b.record_name != null
          ? String(b.record_name).trim()
          : null;
    const notes = b.notes !== undefined ? (b.notes != null ? String(b.notes).trim() : null) : undefined;
    const removeIds = Array.isArray(b.removeAttachmentIds)
      ? b.removeAttachmentIds
      : Array.isArray(b.remove_attachment_ids)
        ? b.remove_attachment_ids
        : [];
    const addAttachments = Array.isArray(b.addAttachments)
      ? b.addAttachments
      : Array.isArray(b.add_attachments)
        ? b.add_attachments
        : [];

    if (recordName !== null && recordName === '') {
      return res.status(400).json({ error: 'recordName cannot be empty' });
    }

    if (recordName !== null || notes !== undefined) {
      const fields = [];
      const params = [];
      let i = 1;
      if (recordName !== null) {
        fields.push(`record_name = $${i}`);
        params.push(recordName);
        i += 1;
      }
      if (notes !== undefined) {
        fields.push(`notes = $${i}`);
        params.push(notes || null);
        i += 1;
      }
      params.push(id);
      await pool.query(
        `UPDATE ms_sd_records SET ${fields.join(', ')} WHERE id = $${i}`,
        params,
      );
    }

    for (const rawId of removeIds) {
      const attId = parseInt(rawId, 10);
      if (Number.isNaN(attId)) continue;
      await pool.query(
        'DELETE FROM ms_sd_attachments WHERE id = $1 AND record_id = $2',
        [attId, id],
      );
    }

    const now = new Date().toISOString();
    for (const raw of addAttachments) {
      const fileName = String(raw.fileName ?? raw.file_name ?? '').trim();
      let fileMime = String(raw.fileMime ?? raw.file_mime ?? '').trim();
      let fileData = String(raw.fileData ?? raw.file_data ?? '').trim();
      if (!fileName || !fileData) {
        return res.status(400).json({ error: 'invalid attachment' });
      }
      const norm = _normalizeMsSdFileData(fileMime, fileData);
      fileMime = norm.mime;
      fileData = norm.data;
      if (_estimateBase64PayloadBytes(fileData) > MS_SD_MAX_FILE_BYTES) {
        return res.status(400).json({ error: `file too large (max ${MS_SD_MAX_FILE_BYTES} bytes)` });
      }
      await pool.query(
        `INSERT INTO ms_sd_attachments (
          record_id, file_name, file_mime, file_data, created_at
        ) VALUES ($1,$2,$3,$4,$5)`,
        [id, fileName, fileMime, fileData, now],
      );
    }

    const remain = await pool.query(
      'SELECT COUNT(*)::int AS c FROM ms_sd_attachments WHERE record_id = $1',
      [id],
    );
    if (parseInt(remain.rows[0].c, 10) === 0) {
      return res.status(400).json({ error: 'record must have at least one attachment' });
    }

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/ms-sd/records/:id', async (req, res) => {
  try {
    const requesterEmail = String(
      req.query.requesterEmail ?? req.body?.requesterEmail ?? '',
    ).trim();
    if (!_isPrimaryAppAdminEmail(requesterEmail)) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
    const del = await pool.query('DELETE FROM ms_sd_records WHERE id = $1 RETURNING id', [id]);
    if (del.rowCount === 0) return res.status(404).json({ error: 'not found' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

async function _mapMosItpRecordRow(row, attachments, includeAudit) {
  const out = {
    id: parseInt(row.id, 10),
    project_id: parseInt(row.project_id, 10),
    kind: row.kind,
    record_name: row.record_name,
    notes: row.notes,
    attachments: (attachments || []).map((a) => ({
      id: parseInt(a.id, 10),
      record_id: parseInt(a.record_id, 10),
      file_name: a.file_name,
      file_mime: a.file_mime,
      file_data: a.file_data,
      created_at: a.created_at,
    })),
  };
  if (includeAudit) {
    out.user_id = parseInt(row.user_id, 10);
    out.user_name = row.user_name;
    out.created_at = row.created_at;
  }
  return out;
}

app.get('/mos-itp/records', async (req, res) => {
  try {
    const projectId = parseInt(req.query.projectId ?? req.query.project_id ?? '', 10);
    if (Number.isNaN(projectId)) {
      return res.status(400).json({ error: 'projectId required' });
    }
    const kind = String(req.query.kind ?? '').trim().toLowerCase();
    if (kind !== 'mos' && kind !== 'itp') {
      return res.status(400).json({ error: 'kind must be mos or itp' });
    }
    const requesterEmail = String(req.query.requesterEmail ?? '').trim();
    const includeAudit = _isPrimaryAppAdminEmail(requesterEmail);

    const recs = await pool.query(
      `SELECT id, project_id, user_id, user_name, kind, record_name, notes, created_at
       FROM mos_itp_records
       WHERE project_id = $1 AND kind = $2
       ORDER BY created_at DESC, id DESC`,
      [projectId, kind],
    );
    const out = [];
    for (const row of recs.rows) {
      const att = await pool.query(
        `SELECT id, record_id, file_name, file_mime, file_data, created_at
         FROM mos_itp_attachments WHERE record_id = $1 ORDER BY id ASC`,
        [row.id],
      );
      out.push(await _mapMosItpRecordRow(row, att.rows, includeAudit));
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/mos-itp/records', async (req, res) => {
  try {
    const b = req.body || {};
    const projectId = parseInt(b.projectId ?? b.project_id ?? '', 10);
    const userId = parseInt(b.userId ?? b.user_id ?? '', 10);
    const userName = String(b.userName ?? b.user_name ?? '').trim();
    const kind = String(b.kind ?? '').trim().toLowerCase();
    const recordName = String(b.recordName ?? b.record_name ?? '').trim();
    const notes = b.notes != null ? String(b.notes).trim() : null;
    const attachments = Array.isArray(b.attachments) ? b.attachments : [];

    if (
      Number.isNaN(projectId) ||
      Number.isNaN(userId) ||
      !userName ||
      !recordName ||
      (kind !== 'mos' && kind !== 'itp') ||
      attachments.length === 0
    ) {
      return res.status(400).json({ error: 'missing required fields' });
    }

    const usr = await pool.query('SELECT id, role FROM users WHERE id = $1', [userId]);
    if (usr.rows.length === 0) return res.status(400).json({ error: 'user not found' });
    if (String(usr.rows[0].role) !== 'document_controller') {
      return res.status(403).json({ error: 'only document controller can upload' });
    }

    const proj = await pool.query('SELECT id FROM projects WHERE id = $1', [projectId]);
    if (proj.rows.length === 0) return res.status(400).json({ error: 'project not found' });

    const prepared = [];
    for (const raw of attachments) {
      const fileName = String(raw.fileName ?? raw.file_name ?? '').trim();
      let fileMime = String(raw.fileMime ?? raw.file_mime ?? '').trim();
      let fileData = String(raw.fileData ?? raw.file_data ?? '').trim();
      if (!fileName || !fileData) {
        return res.status(400).json({ error: 'invalid attachment' });
      }
      const norm = _normalizeMsSdFileData(fileMime, fileData);
      fileMime = norm.mime;
      fileData = norm.data;
      if (_estimateBase64PayloadBytes(fileData) > MS_SD_MAX_FILE_BYTES) {
        return res.status(400).json({ error: `file too large (max ${MS_SD_MAX_FILE_BYTES} bytes)` });
      }
      prepared.push({ fileName, fileMime, fileData });
    }

    const createdAt = new Date().toISOString();
    const ins = await pool.query(
      `INSERT INTO mos_itp_records (
        project_id, user_id, user_name, kind, record_name, notes, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
      [projectId, userId, userName, kind, recordName, notes || null, createdAt],
    );
    const recordId = parseInt(ins.rows[0].id, 10);
    for (const att of prepared) {
      await pool.query(
        `INSERT INTO mos_itp_attachments (
          record_id, file_name, file_mime, file_data, created_at
        ) VALUES ($1,$2,$3,$4,$5)`,
        [recordId, att.fileName, att.fileMime, att.fileData, createdAt],
      );
    }

    const projRes = await pool.query('SELECT name FROM projects WHERE id = $1', [projectId]);
    const projName = projRes.rows.length ? projRes.rows[0].name : null;
    const kindLabel = kind === 'itp' ? 'ITP' : 'MoS';
    await notifyAppAdminsOnDocumentUpload(pool, userId, userName, {
      title: `رفع ${kindLabel} جديد`,
      body:
        `قام "${userName}" بإضافة "${recordName}" (${kindLabel}) — مشروع "${projName || 'غير محدد'}"\n` +
        `رقم السجل: ${recordId}`,
      eventType: kind === 'itp' ? 'itp_upload' : 'mos_upload',
      projectName: projName,
    });

    res.json(recordId);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.patch('/mos-itp/records/:id', async (req, res) => {
  try {
    const requesterEmail = String(
      req.query.requesterEmail ?? req.body?.requesterEmail ?? '',
    ).trim();
    if (!_isPrimaryAppAdminEmail(requesterEmail)) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });

    const existing = await pool.query('SELECT * FROM mos_itp_records WHERE id = $1', [id]);
    if (existing.rows.length === 0) return res.status(404).json({ error: 'not found' });

    const b = req.body || {};
    const recordName =
      b.recordName != null
        ? String(b.recordName).trim()
        : b.record_name != null
          ? String(b.record_name).trim()
          : null;
    const notes = b.notes !== undefined ? (b.notes != null ? String(b.notes).trim() : null) : undefined;
    const removeIds = Array.isArray(b.removeAttachmentIds)
      ? b.removeAttachmentIds
      : Array.isArray(b.remove_attachment_ids)
        ? b.remove_attachment_ids
        : [];
    const addAttachments = Array.isArray(b.addAttachments)
      ? b.addAttachments
      : Array.isArray(b.add_attachments)
        ? b.add_attachments
        : [];

    if (recordName !== null && recordName === '') {
      return res.status(400).json({ error: 'recordName cannot be empty' });
    }

    if (recordName !== null || notes !== undefined) {
      const fields = [];
      const params = [];
      let i = 1;
      if (recordName !== null) {
        fields.push(`record_name = $${i}`);
        params.push(recordName);
        i += 1;
      }
      if (notes !== undefined) {
        fields.push(`notes = $${i}`);
        params.push(notes || null);
        i += 1;
      }
      params.push(id);
      await pool.query(
        `UPDATE mos_itp_records SET ${fields.join(', ')} WHERE id = $${i}`,
        params,
      );
    }

    for (const rawId of removeIds) {
      const attId = parseInt(rawId, 10);
      if (Number.isNaN(attId)) continue;
      await pool.query(
        'DELETE FROM mos_itp_attachments WHERE id = $1 AND record_id = $2',
        [attId, id],
      );
    }

    const now = new Date().toISOString();
    for (const raw of addAttachments) {
      const fileName = String(raw.fileName ?? raw.file_name ?? '').trim();
      let fileMime = String(raw.fileMime ?? raw.file_mime ?? '').trim();
      let fileData = String(raw.fileData ?? raw.file_data ?? '').trim();
      if (!fileName || !fileData) {
        return res.status(400).json({ error: 'invalid attachment' });
      }
      const norm = _normalizeMsSdFileData(fileMime, fileData);
      fileMime = norm.mime;
      fileData = norm.data;
      if (_estimateBase64PayloadBytes(fileData) > MS_SD_MAX_FILE_BYTES) {
        return res.status(400).json({ error: `file too large (max ${MS_SD_MAX_FILE_BYTES} bytes)` });
      }
      await pool.query(
        `INSERT INTO mos_itp_attachments (
          record_id, file_name, file_mime, file_data, created_at
        ) VALUES ($1,$2,$3,$4,$5)`,
        [id, fileName, fileMime, fileData, now],
      );
    }

    const remain = await pool.query(
      'SELECT COUNT(*)::int AS c FROM mos_itp_attachments WHERE record_id = $1',
      [id],
    );
    if (parseInt(remain.rows[0].c, 10) === 0) {
      return res.status(400).json({ error: 'record must have at least one attachment' });
    }

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/mos-itp/records/:id', async (req, res) => {
  try {
    const requesterEmail = String(
      req.query.requesterEmail ?? req.body?.requesterEmail ?? '',
    ).trim();
    if (!_isPrimaryAppAdminEmail(requesterEmail)) {
      return res.status(403).json({ error: 'forbidden' });
    }
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
    const del = await pool.query('DELETE FROM mos_itp_records WHERE id = $1 RETURNING id', [id]);
    if (del.rowCount === 0) return res.status(404).json({ error: 'not found' });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/attendance', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM attendance_records ORDER BY date_time DESC');
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), user_id: parseInt(row.user_id), user_name: row.user_name, type: row.type,
      date_time: row.date_time, location: row.location, project_id: row.project_id ? parseInt(row.project_id) : null, project_name: row.project_name, notes: row.notes
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/attendance/by-user/:userId', async (req, res) => {
  try {
    const r = await pool.query('SELECT * FROM attendance_records WHERE user_id = $1 ORDER BY date_time DESC', [req.params.userId]);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), user_id: parseInt(row.user_id), user_name: row.user_name, type: row.type,
      date_time: row.date_time, location: row.location, project_id: row.project_id ? parseInt(row.project_id) : null, project_name: row.project_name, notes: row.notes
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/attendance/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM attendance_records WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Materials ———
app.get('/materials', async (req, res) => {
  try {
    const r = await pool.query('SELECT name FROM materials ORDER BY name');
    res.json(r.rows.map(row => row.name));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/materials/with-ids', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM materials ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/materials', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO materials (name) VALUES ($1) RETURNING id', [req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/materials/:id', async (req, res) => {
  try {
    await pool.query('UPDATE materials SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/materials/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM materials WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Daily reports ———
app.post('/daily-reports', async (req, res) => {
  try {
    const b = req.body;
    const now = new Date().toISOString();
    const contractorsJson = (b.contractors_json != null) ? (typeof b.contractors_json === 'string' ? b.contractors_json : JSON.stringify(b.contractors_json || [])) : null;
    const r = await pool.query(
      `INSERT INTO daily_reports (user_id, user_name, project_id, project_name, report_datetime, work_place, work_report, executed_today, supervisor_name, contractor_name, workers_count, contractors_json, tomorrow_plan, document_path, images_json, notes, materials_json, expenses_json, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19) RETURNING id`,
      [b.userId, b.userName, b.projectId || null, b.projectName || null, b.reportDate, b.workPlace || '', b.workReport || '', b.executedToday || '', b.supervisorName || null, b.contractorName || null, b.workersCount || null, contractorsJson, b.tomorrowPlan || '', b.documentPath || null, typeof b.imagePaths === 'string' ? b.imagePaths : JSON.stringify(b.imagePaths || []), b.notes || null, typeof b.materials === 'string' ? b.materials : JSON.stringify(b.materials || []), typeof b.expenses === 'string' ? b.expenses : JSON.stringify(b.expenses || []), now]
    );
    const id = parseInt(r.rows[0].id);
    const expenses = Array.isArray(b.expenses) ? b.expenses : (typeof b.expenses === 'string' ? JSON.parse(b.expenses || '[]') : []);
    let totalExpense = 0;
    for (const e of expenses) {
      const amt = parseFloat(String((e.amount || '').replace(/[^\d.]/g, ''))) || 0;
      totalExpense += amt;
    }
    if (totalExpense > 0) {
      const bal = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [b.userId]);
      const current = bal.rows.length ? parseFloat(bal.rows[0].balance) : 0;
      await pool.query('INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2', [b.userId, current - totalExpense]);
    }
    // خصم المواد من مخزن المشروع: المطابقة بالمشروع + اسم الخامة فقط، والخصم يكون على رقم الكمية فقط
    // التطبيق يرسل اسم الخامة في الحقل "material" (وقد يرسلها أيضاً materialName / material_name)
    if (b.projectId) {
      const materials = Array.isArray(b.materials) ? b.materials : (typeof b.materials === 'string' ? JSON.parse(b.materials || '[]') : []);
      const reportDate = b.reportDate ? new Date(b.reportDate) : new Date();
      for (const m of materials) {
        const materialName = (m.materialName || m.material_name || m.material || '').trim();
        const quantity = parseFloat(String((m.quantity || '').replace(/[^\d.]/g, ''))) || 0;
        const unit = (m.unit || 'متر').trim() || 'متر';
        if (!materialName || quantity <= 0) continue;
        const stock = await pool.query('SELECT id, quantity, unit FROM project_stock WHERE project_id = $1 AND material_name = $2 LIMIT 1', [b.projectId, materialName]);
        if (stock.rows.length === 0) continue;
        const row = stock.rows[0];
        const currentQty = parseFloat(String(row.quantity).replace(/[^\d.]/g, '')) || 0;
        const newQty = Math.max(0, currentQty - quantity);
        await pool.query('UPDATE project_stock SET quantity = $1 WHERE id = $2', [String(newQty), row.id]);
        await pool.query(
          'INSERT INTO project_stock_ledger (project_id, material_name, unit, quantity_delta, type, created_at, user_id, user_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
          [b.projectId, materialName, row.unit || unit, -quantity, 'deduct_report', reportDate.toISOString(), b.userId || null, b.userName || '']
        );
      }
    }
    res.json(id);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/daily-reports', async (req, res) => {
  try {
    const { dateFrom, dateTo, userId, projectId } = req.query;
    let q = 'SELECT * FROM daily_reports WHERE report_datetime >= $1 AND report_datetime <= $2';
    const params = [dateFrom, dateTo];
    let i = 3;
    if (userId) { q += ` AND user_id = $${i}`; params.push(userId); i++; }
    if (projectId) { q += ` AND project_id = $${i}`; params.push(projectId); i++; }
    q += ' ORDER BY report_datetime DESC';
    const r = await pool.query(q, params);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), user_id: parseInt(row.user_id), user_name: row.user_name, project_id: row.project_id ? parseInt(row.project_id) : null, project_name: row.project_name,
      report_datetime: row.report_datetime, work_place: row.work_place, work_report: row.work_report, executed_today: row.executed_today, supervisor_name: row.supervisor_name, contractor_name: row.contractor_name, workers_count: row.workers_count, contractors_json: row.contractors_json, tomorrow_plan: row.tomorrow_plan, document_path: row.document_path, images_json: row.images_json, notes: row.notes, materials_json: row.materials_json, expenses_json: row.expenses_json, created_at: row.created_at
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/daily-reports/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM daily_reports WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Engineer balance & custody ———
app.get('/engineer-balance/:userId', async (req, res) => {
  try {
    const r = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [req.params.userId]);
    res.json(r.rows.length ? parseFloat(r.rows[0].balance) : 0);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/engineer-balance', async (req, res) => {
  try {
    const { userId, balance } = req.body;
    await pool.query('INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2', [userId, balance]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/custody', async (req, res) => {
  try {
    const { userId, amount, note } = req.body;
    const now = new Date().toISOString();
    await pool.query(
      'INSERT INTO engineer_custody (user_id, amount, created_at, note, movement_type) VALUES ($1, $2, $3, $4, $5)',
      [userId, amount, now, note || '', 'custody']
    );
    const r = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [userId]);
    const current = r.rows.length ? parseFloat(r.rows[0].balance) : 0;
    // Custody = company gives cash to engineer → balance (what we owe) decreases
    await pool.query('INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2', [userId, current - parseFloat(amount)]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// حركة إضافة رصيد أو سحب رصيد (من واجهة المحاسب) — تسجيل فقط في engineer_custody؛ تعديل الأرصدة يتم من التطبيق
app.post('/balance-movement', async (req, res) => {
  try {
    const { userId, amount, note, movementType } = req.body;
    const now = new Date().toISOString();
    const type = movementType === 'add_balance' || movementType === 'withdraw_balance' ? movementType : 'add_balance';
    await pool.query(
      'INSERT INTO engineer_custody (user_id, amount, created_at, note, movement_type) VALUES ($1, $2, $3, $4, $5)',
      [userId, amount, now, note || '', type]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/custody', async (req, res) => {
  try {
    const userId = req.query.userId;
    const q = userId ? 'SELECT * FROM engineer_custody WHERE user_id = $1 ORDER BY created_at DESC' : 'SELECT * FROM engineer_custody ORDER BY created_at DESC';
    const params = userId ? [userId] : [];
    const r = await pool.query(q, params);
    const mapRow = (row) => {
      const out = { id: parseInt(row.id), user_id: parseInt(row.user_id), amount: parseFloat(row.amount), created_at: row.created_at, note: row.note || '' };
      if (row.movement_type != null) out.movement_type = row.movement_type;
      if (row.document_path != null) out.document_path = row.document_path;
      return out;
    };
    res.json(r.rows.map(mapRow));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Supervisors, Contractors ———
app.get('/supervisors', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM supervisors ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/supervisors', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO supervisors (name) VALUES ($1) RETURNING id', [req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/supervisors/:id', async (req, res) => {
  try {
    await pool.query('UPDATE supervisors SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/supervisors/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM supervisors WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/contractors', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, name FROM contractors ORDER BY name');
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/contractors', async (req, res) => {
  try {
    const r = await pool.query('INSERT INTO contractors (name) VALUES ($1) RETURNING id', [req.body.name]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/contractors/:id', async (req, res) => {
  try {
    await pool.query('UPDATE contractors SET name = $1 WHERE id = $2', [req.body.name, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/contractors/:id', async (req, res) => {
  try {
    // فك ربط المقاول من سطور التقرير المفصل أولاً لتجنب خطأ FK
    await pool.query('UPDATE detailed_report_lines SET contractor_id = NULL WHERE contractor_id = $1', [req.params.id]);
    await pool.query('DELETE FROM contractors WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Work phases (مراحل العمل للتقرير المفصل) ———
app.get('/work-phases', async (req, res) => {
  try {
    // نُرجع فقط المراحل القياسية الخمس وبترتيب ثابت (حتى لو كانت القاعدة تحتوي مراحل قديمة أخرى).
    const names = [
      'تركيب اكسسوارات',
      'تقطيع WPC',
      'تركيب WPC',
      'معالجة',
      'دهان',
      'تشوين',
      'تركيب ارضيات',
      'تركيب Q.round + وزر',
    ];
    const r = await pool.query(
      `SELECT id, name
       FROM work_phases
       WHERE name = ANY($1)
       ORDER BY CASE name
         WHEN 'تركيب اكسسوارات' THEN 1
         WHEN 'تقطيع WPC' THEN 2
         WHEN 'تركيب WPC' THEN 3
         WHEN 'معالجة' THEN 4
         WHEN 'دهان' THEN 5
         WHEN 'تشوين' THEN 6
         WHEN 'تركيب ارضيات' THEN 7
         WHEN 'تركيب Q.round + وزر' THEN 8
         ELSE 999
       END, id`,
      [names]
    );
    res.json(r.rows.map(row => ({ id: parseInt(row.id), name: row.name })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Detailed reports (التقرير المفصل) ———
function parseExecutedTodaySummaryFromBody(b) {
  const raw = b.executedTodaySummary ?? b.executed_today_summary;
  if (raw == null) return null;
  const s = String(raw).trim();
  return s !== '' ? s : null;
}

app.post('/detailed-reports', async (req, res) => {
  try {
    const b = req.body;
    const now = new Date().toISOString();
    const summary = (b.summary != null && String(b.summary).trim() !== '') ? String(b.summary).trim() : null;
    const executedTodaySummary = parseExecutedTodaySummaryFromBody(b);
    const projectId = b.projectId != null ? parseInt(b.projectId) : null;
    const projectName = (b.projectName != null && String(b.projectName).trim() !== '') ? String(b.projectName).trim() : null;
    const expensesJson = (b.expenses != null && Array.isArray(b.expenses) && b.expenses.length > 0)
      ? JSON.stringify(b.expenses) : null;
    const attachmentsJson = (b.attachments != null && Array.isArray(b.attachments) && b.attachments.length > 0)
      ? JSON.stringify(b.attachments) : null;
    const r = await pool.query(
      'INSERT INTO detailed_reports (user_id, user_name, report_datetime, project_id, project_name, supervisor_id, created_at, summary, executed_today_summary, expenses_json, attachments_json) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING id',
      [b.userId, b.userName, b.reportDatetime || now, projectId, projectName, b.supervisorId || null, now, summary, executedTodaySummary, expensesJson, attachmentsJson]
    );
    const reportId = parseInt(r.rows[0].id);
    const lines = Array.isArray(b.lines) ? b.lines : [];
    for (const line of lines) {
      const locationId = line.locationId != null ? parseInt(line.locationId) : null;
      const zoneId = line.zoneId != null ? parseInt(line.zoneId) : null;
      const buildingId = line.buildingId != null ? parseInt(line.buildingId) : null;
      const contractorId = line.contractorId != null ? parseInt(line.contractorId) : null;
      await pool.query(
        'INSERT INTO detailed_report_lines (detailed_report_id, contractor_id, contractor_workers_count, self_workers_count, zone_id, building_id, location_id, manual_work_location, phase_id, workers_count) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
        [reportId, contractorId, line.contractorWorkersCount ?? 0, line.selfWorkersCount ?? 0, zoneId, buildingId, locationId, (line.manualWorkLocation != null && String(line.manualWorkLocation).trim() !== '') ? String(line.manualWorkLocation).trim() : null, line.phaseId, line.workersCount]
      );
    }
    // خصم إجمالي بنود الماليات من رصيد مهندس الموقع (مستخدم كاتب التقرير)
    const expenses = Array.isArray(b.expenses) ? b.expenses : (expensesJson ? JSON.parse(expensesJson) : []);
    let totalExpense = 0;
    for (const e of expenses) {
      const amt = parseFloat(String((e.amount || '').replace(/[^\d.]/g, ''))) || 0;
      totalExpense += amt;
    }
    if (totalExpense > 0 && b.userId) {
      const bal = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [b.userId]);
      const current = bal.rows.length ? parseFloat(bal.rows[0].balance) : 0;
      await pool.query('INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2', [b.userId, current - totalExpense]);
    }
    const hasAttachments =
      (Array.isArray(b.attachments) && b.attachments.length > 0) ||
      (attachmentsJson != null && String(attachmentsJson).trim() !== '');
    await notifyAppAdminsWorkPlanSaved(pool, {
      userId: b.userId,
      userName: b.userName,
      projectName: projectName,
      reportDatetime: b.reportDatetime || now,
      isUpdate: false,
      hasAttachments,
    });
    res.json(reportId);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/detailed-reports', async (req, res) => {
  try {
    const q = req.query;
    let sql = `
      SELECT
        dr.id,
        dr.user_id,
        dr.user_name,
        dr.report_datetime,
        dr.project_id,
        COALESCE(NULLIF(TRIM(dr.project_name), ''), p.name) AS project_name,
        dr.supervisor_id,
        dr.created_at,
        dr.summary,
        dr.executed_today_summary,
        dr.expenses_json,
        dr.attachments_json
      FROM detailed_reports dr
      LEFT JOIN projects p ON p.id = dr.project_id
      WHERE 1=1
    `;
    const params = [];
    let i = 1;
    if (q.dateFrom) { sql += ` AND report_datetime >= $${i}`; params.push(q.dateFrom); i++; }
    if (q.dateTo) { sql += ` AND report_datetime <= $${i}`; params.push(q.dateTo); i++; }
    if (q.userId) { sql += ` AND user_id = $${i}`; params.push(q.userId); i++; }
    if (q.projectId !== undefined && q.projectId !== '') {
      if (q.projectId === '0' || String(q.projectId).toLowerCase() === 'other') {
        sql += ' AND project_id IS NULL';
      } else {
        sql += ` AND project_id = $${i}`;
        params.push(q.projectId);
        i++;
      }
    }
    sql += ' ORDER BY report_datetime DESC';
    const r = await pool.query(sql, params);
    const reports = r.rows.map(row => {
      let expenses = [];
      try {
        if (row.expenses_json && String(row.expenses_json).trim() !== '') {
          expenses = JSON.parse(row.expenses_json);
        }
      } catch (_) {}
      let attachments = [];
      try {
        if (row.attachments_json && String(row.attachments_json).trim() !== '') {
          attachments = JSON.parse(row.attachments_json);
        }
      } catch (_) {}
      return {
        id: parseInt(row.id),
        user_id: parseInt(row.user_id),
        user_name: row.user_name,
        report_datetime: row.report_datetime,
        project_id: row.project_id != null ? parseInt(row.project_id) : null,
        project_name: row.project_name != null ? row.project_name : null,
        supervisor_id: row.supervisor_id != null ? parseInt(row.supervisor_id) : null,
        created_at: row.created_at,
        summary: row.summary != null ? row.summary : null,
        executed_today_summary: row.executed_today_summary != null ? row.executed_today_summary : null,
        expenses: expenses,
        attachments: attachments,
      };
    });
    // Load lines for each report
    for (const report of reports) {
      const linesRes = await pool.query(
        'SELECT id, detailed_report_id, contractor_id, contractor_workers_count, self_workers_count, zone_id, building_id, location_id, manual_work_location, phase_id, workers_count FROM detailed_report_lines WHERE detailed_report_id = $1 ORDER BY id',
        [report.id]
      );
      report.lines = linesRes.rows.map(l => ({
        id: parseInt(l.id),
        detailed_report_id: parseInt(l.detailed_report_id),
        contractor_id: l.contractor_id != null ? parseInt(l.contractor_id) : null,
        contractor_workers_count: parseInt(l.contractor_workers_count),
        self_workers_count: parseInt(l.self_workers_count),
        zone_id: l.zone_id != null ? parseInt(l.zone_id) : null,
        building_id: l.building_id != null ? parseInt(l.building_id) : null,
        location_id: l.location_id != null ? parseInt(l.location_id) : null,
        manual_work_location: l.manual_work_location != null ? l.manual_work_location : null,
        phase_id: parseInt(l.phase_id),
        workers_count: parseInt(l.workers_count),
      }));
    }
    res.json(reports);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/detailed-reports/:id/expenses', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
    const bodyUserId = req.body.userId != null ? parseInt(req.body.userId, 10) : null;
    const expenses = Array.isArray(req.body.expenses) ? req.body.expenses : [];

    const r = await pool.query(
      'SELECT user_id, expenses_json FROM detailed_reports WHERE id = $1',
      [id]
    );
    if (r.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const rowUserId = parseInt(r.rows[0].user_id, 10);
    if (bodyUserId != null && bodyUserId !== rowUserId) {
      return res.status(403).json({ error: 'user mismatch' });
    }

    function expenseTotal(expList) {
      let t = 0;
      if (!Array.isArray(expList)) return 0;
      for (const e of expList) {
        const amt = parseFloat(String((e.amount || '').replace(/[^\d.]/g, ''))) || 0;
        t += amt;
      }
      return t;
    }

    let oldTotal = 0;
    if (r.rows[0].expenses_json) {
      try {
        const oldArr = JSON.parse(r.rows[0].expenses_json);
        oldTotal = expenseTotal(oldArr);
      } catch (_) {}
    }
    const newTotal = expenseTotal(expenses);
    const delta = newTotal - oldTotal;

    if (delta !== 0 && rowUserId) {
      const bal = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [rowUserId]);
      const current = bal.rows.length ? parseFloat(bal.rows[0].balance) : 0;
      await pool.query(
        'INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2',
        [rowUserId, current - delta]
      );
    }

    const expensesJson =
      expenses.length > 0 ? JSON.stringify(expenses) : null;
    await pool.query('UPDATE detailed_reports SET expenses_json = $1 WHERE id = $2', [
      expensesJson,
      id,
    ]);
    const userRow = await pool.query(
      'SELECT user_name, project_name FROM detailed_reports WHERE id = $1',
      [id],
    );
    const userName = userRow.rows.length ? String(userRow.rows[0].user_name || '') : '';
    const projectName = userRow.rows.length ? userRow.rows[0].project_name : null;
    await notifyAppAdminsIfSiteEngineer(pool, rowUserId, {
      title: 'تحديث ماليات التقرير',
      body: `قام "${userName}" بتحديث بنود الصرف في التقرير المفصل #${id}`,
      eventType: 'detailed_report_expenses_updated',
      actorUserId: rowUserId,
      actorUserName: userName,
      projectName,
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/detailed-reports/:id', async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
  try {
    const exists = await pool.query('SELECT id FROM detailed_reports WHERE id = $1', [id]);
    if (exists.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const b = req.body || {};
    const summary = (b.summary != null && String(b.summary).trim() !== '') ? String(b.summary).trim() : null;
    const executedTodaySummary = parseExecutedTodaySummaryFromBody(b);
    const projectId = b.projectId != null ? parseInt(b.projectId, 10) : null;
    const projectName = (b.projectName != null && String(b.projectName).trim() !== '') ? String(b.projectName).trim() : null;
    const expensesJson = (b.expenses != null && Array.isArray(b.expenses) && b.expenses.length > 0)
      ? JSON.stringify(b.expenses) : null;
    const attachmentsJson = (b.attachments != null && Array.isArray(b.attachments) && b.attachments.length > 0)
      ? JSON.stringify(b.attachments) : null;
    await pool.query('BEGIN');
    try {
      await pool.query('DELETE FROM detailed_report_lines WHERE detailed_report_id = $1', [id]);
      await pool.query(
        `UPDATE detailed_reports SET
          user_id = $1, user_name = $2, report_datetime = $3, project_id = $4, project_name = $5,
          supervisor_id = $6, summary = $7, executed_today_summary = $8, expenses_json = $9, attachments_json = $10
         WHERE id = $11`,
        [
          b.userId,
          b.userName,
          b.reportDatetime || new Date().toISOString(),
          projectId,
          projectName,
          b.supervisorId || null,
          summary,
          executedTodaySummary,
          expensesJson,
          attachmentsJson,
          id,
        ]
      );
      const lines = Array.isArray(b.lines) ? b.lines : [];
      for (const line of lines) {
        const locationId = line.locationId != null ? parseInt(line.locationId, 10) : null;
        const zoneId = line.zoneId != null ? parseInt(line.zoneId, 10) : null;
        const buildingId = line.buildingId != null ? parseInt(line.buildingId, 10) : null;
        const contractorId = line.contractorId != null ? parseInt(line.contractorId, 10) : null;
        await pool.query(
          'INSERT INTO detailed_report_lines (detailed_report_id, contractor_id, contractor_workers_count, self_workers_count, zone_id, building_id, location_id, manual_work_location, phase_id, workers_count) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
          [id, contractorId, line.contractorWorkersCount ?? 0, line.selfWorkersCount ?? 0, zoneId, buildingId, locationId, (line.manualWorkLocation != null && String(line.manualWorkLocation).trim() !== '') ? String(line.manualWorkLocation).trim() : null, line.phaseId, line.workersCount]
        );
      }
      await pool.query('COMMIT');
      const hasAttachments =
        (Array.isArray(b.attachments) && b.attachments.length > 0) ||
        (attachmentsJson != null && String(attachmentsJson).trim() !== '');
      await notifyAppAdminsWorkPlanSaved(pool, {
        userId: b.userId,
        userName: b.userName,
        projectName: projectName,
        reportDatetime: b.reportDatetime || new Date().toISOString(),
        isUpdate: true,
        hasAttachments,
      });
      res.json({ ok: true });
    } catch (err) {
      await pool.query('ROLLBACK');
      throw err;
    }
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/detailed-reports/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id, 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
    const r = await pool.query('SELECT user_id, expenses_json FROM detailed_reports WHERE id = $1', [id]);
    if (r.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const row = r.rows[0];
    let totalExpense = 0;
    if (row.expenses_json) {
      try {
        const expenses = JSON.parse(row.expenses_json);
        if (Array.isArray(expenses)) {
          for (const e of expenses) {
            totalExpense += parseFloat(String((e.amount || '').replace(/[^\d.]/g, ''))) || 0;
          }
        }
      } catch (_) {}
    }
    if (totalExpense > 0 && row.user_id) {
      const bal = await pool.query('SELECT balance FROM engineer_balance WHERE user_id = $1', [row.user_id]);
      const current = bal.rows.length ? parseFloat(bal.rows[0].balance) : 0;
      await pool.query(
        'INSERT INTO engineer_balance (user_id, balance) VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = $2',
        [row.user_id, current + totalExpense]
      );
    }
    await pool.query('DELETE FROM detailed_reports WHERE id = $1', [id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Project stock, Units, Building materials, Building cutlists ———
app.get('/project-stock', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, project_id, material_name, quantity, unit FROM project_stock WHERE project_id = $1 ORDER BY material_name', [req.query.projectId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), project_id: parseInt(row.project_id), material_name: row.material_name, quantity: row.quantity, unit: row.unit })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/project-stock', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query('INSERT INTO project_stock (project_id, material_name, quantity, unit) VALUES ($1, $2, $3, $4) RETURNING id', [b.projectId, b.materialName, b.quantity, b.unit]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/project-stock/:id', async (req, res) => {
  try {
    const b = req.body;
    await pool.query('UPDATE project_stock SET material_name = $1, quantity = $2, unit = $3 WHERE id = $4', [b.materialName, b.quantity, b.unit, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/project-stock/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM project_stock WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Project stock ledger (سجل حركات الخامات) ———
app.post('/project-stock-ledger', async (req, res) => {
  try {
    const { projectId, materialName, unit, quantityDelta, type, userName, userId, createdAt } = req.body;
    const now = (createdAt ? new Date(createdAt) : new Date()).toISOString();
    await pool.query(
      'INSERT INTO project_stock_ledger (project_id, material_name, unit, quantity_delta, type, created_at, user_id, user_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
      [projectId, materialName, unit || '', quantityDelta, type || 'add', now, userId || null, userName || '']
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/project-stock-ledger', async (req, res) => {
  try {
    const { projectId, materialName } = req.query;
    if (!projectId || !materialName) return res.status(400).json({ error: 'projectId and materialName required' });
    const r = await pool.query(
      'SELECT * FROM project_stock_ledger WHERE project_id = $1 AND material_name = $2 ORDER BY created_at DESC',
      [projectId, materialName]
    );
    res.json(r.rows.map(row => ({
      id: parseInt(row.id),
      project_id: parseInt(row.project_id),
      material_name: row.material_name,
      unit: row.unit,
      quantity_delta: parseFloat(row.quantity_delta),
      type: row.type,
      created_at: row.created_at,
      user_id: row.user_id ? parseInt(row.user_id) : null,
      user_name: row.user_name || ''
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— هيكلة المخازن: خامات لكل موقع فرعي ———
app.get('/location-materials', async (req, res) => {
  try {
    const locationId = req.query.locationId;
    const projectId = req.query.projectId;
    const phase = String(req.query.phase || 'first_fix').trim().toLowerCase();
    if (projectId !== undefined && projectId !== '') {
      const r = await pool.query(
        `SELECT lm.id, lm.location_id, lm.phase, lm.material_name, lm.quantity, lm.unit
         FROM location_materials lm
         INNER JOIN project_locations pl ON pl.id = lm.location_id
         WHERE pl.project_id = $1
         ORDER BY lm.location_id, lm.phase, lm.material_name`,
        [parseInt(String(projectId), 10)]
      );
      return res.json(r.rows.map(row => ({
        id: parseInt(row.id),
        location_id: parseInt(row.location_id),
        phase: row.phase || 'first_fix',
        material_name: row.material_name,
        quantity: row.quantity,
        unit: row.unit || ''
      })));
    }
    if (!locationId) return res.status(400).json({ error: 'locationId or projectId required' });
    const r = await pool.query(
      'SELECT id, location_id, phase, material_name, quantity, unit FROM location_materials WHERE location_id = $1 AND phase = $2 ORDER BY material_name',
      [locationId, phase]
    );
    res.json(r.rows.map(row => ({
      id: parseInt(row.id),
      location_id: parseInt(row.location_id),
      phase: row.phase || 'first_fix',
      material_name: row.material_name,
      quantity: row.quantity,
      unit: row.unit || ''
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/location-materials', async (req, res) => {
  try {
    const { locationId, materialName, quantity, unit } = req.body;
    const phase = String(req.body?.phase || 'first_fix').trim().toLowerCase();
    const r = await pool.query(
      'INSERT INTO location_materials (location_id, phase, material_name, quantity, unit) VALUES ($1, $2, $3, $4, $5) RETURNING id',
      [locationId, phase, materialName, quantity || '0', unit || '']
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/location-materials/:id', async (req, res) => {
  try {
    const { materialName, quantity, unit } = req.body;
    const phase = String(req.body?.phase || 'first_fix').trim().toLowerCase();
    await pool.query(
      'UPDATE location_materials SET phase = $1, material_name = $2, quantity = $3, unit = $4 WHERE id = $5',
      [phase, materialName, quantity, unit, req.params.id]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/location-materials/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM location_materials WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// سجل سحب الخامات (مرة واحدة لكل موقع)
app.get('/location-withdrawal', async (req, res) => {
  try {
    const locationId = req.query.locationId;
    const projectId = req.query.projectId;
    const phase = String(req.query.phase || 'first_fix').trim().toLowerCase();
    if (projectId !== undefined && projectId !== '') {
      const r = await pool.query(
        `SELECT lw.id, lw.location_id, lw.phase, lw.user_id, lw.user_name, lw.created_at,
                lw.disbursement_permit_images_json, lw.delivery_permit_images_json
         FROM location_withdrawal lw
         INNER JOIN project_locations pl ON pl.id = lw.location_id
         WHERE pl.project_id = $1
         ORDER BY lw.location_id, lw.phase`,
        [parseInt(String(projectId), 10)]
      );
      return res.json(r.rows.map(row => ({
        id: parseInt(row.id),
        location_id: parseInt(row.location_id),
        phase: row.phase || 'first_fix',
        user_id: parseInt(row.user_id),
        user_name: row.user_name,
        created_at: row.created_at,
        disbursement_permit_images_json: row.disbursement_permit_images_json,
        delivery_permit_images_json: row.delivery_permit_images_json
      })));
    }
    if (!locationId) return res.status(400).json({ error: 'locationId or projectId required' });
    const r = await pool.query(
      'SELECT id, location_id, phase, user_id, user_name, created_at, disbursement_permit_images_json, delivery_permit_images_json FROM location_withdrawal WHERE location_id = $1 AND phase = $2',
      [locationId, phase]
    );
    if (r.rows.length === 0) return res.json(null);
    const row = r.rows[0];
    res.json({
      id: parseInt(row.id),
      location_id: parseInt(row.location_id),
      phase: row.phase || 'first_fix',
      user_id: parseInt(row.user_id),
      user_name: row.user_name,
      created_at: row.created_at,
      disbursement_permit_images_json: row.disbursement_permit_images_json,
      delivery_permit_images_json: row.delivery_permit_images_json
    });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// سحوبات الخامات ضمن فترة (للتقرير اليومي المجمع من التقارير المفصّلة)
app.get('/location-withdrawals-for-period', async (req, res) => {
  try {
    const { dateFrom, dateTo, projectId } = req.query;
    if (!dateFrom || !dateTo) return res.status(400).json({ error: 'dateFrom and dateTo required' });
    const fromD = String(dateFrom).slice(0, 10);
    const toD = String(dateTo).slice(0, 10);
    let sql = `
      SELECT lw.location_id, lw.phase, lw.user_id, lw.user_name, lw.created_at, pl.project_id
      FROM location_withdrawal lw
      INNER JOIN project_locations pl ON pl.id = lw.location_id
      WHERE substring(lw.created_at from 1 for 10)::date >= $1::date
        AND substring(lw.created_at from 1 for 10)::date <= $2::date
    `;
    const params = [fromD, toD];
    if (projectId !== undefined && projectId !== '') {
      sql += ` AND pl.project_id = $3`;
      params.push(parseInt(String(projectId), 10));
    }
    const r = await pool.query(sql, params);
    const out = [];
    for (const row of r.rows) {
      const projectIdNum = parseInt(row.project_id, 10);
      const createdAt = row.created_at instanceof Date ? row.created_at.toISOString() : String(row.created_at);
      const led = await pool.query(
        `SELECT material_name, quantity_delta, unit FROM project_stock_ledger
         WHERE project_id = $1 AND type = 'withdraw_location' AND created_at = $2
         ORDER BY material_name`,
        [projectIdNum, createdAt]
      );
      const materials = led.rows.map((l) => {
        const q = Math.abs(parseFloat(l.quantity_delta) || 0);
        return {
          material_name: l.material_name,
          quantity: String(q),
          unit: l.unit || '',
        };
      });
      out.push({
        location_id: parseInt(row.location_id, 10),
        phase: row.phase || 'first_fix',
        user_id: parseInt(row.user_id, 10),
        user_name: row.user_name,
        created_at: createdAt,
        project_id: projectIdNum,
        materials,
      });
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/location-withdrawal', async (req, res) => {
  try {
    const { locationId, userId, userName, disbursementPermitImagesJson, deliveryPermitImagesJson } = req.body;
    const phase = String(req.body?.phase || 'first_fix').trim().toLowerCase();
    const now = new Date().toISOString();
    const existing = await pool.query('SELECT id FROM location_withdrawal WHERE location_id = $1 AND phase = $2', [locationId, phase]);
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'already_withdrawn', message: 'تم سحب الخامات من هذا المكان مسبقاً' });
    }
    const loc = await pool.query('SELECT project_id FROM project_locations WHERE id = $1', [locationId]);
    if (loc.rows.length === 0) return res.status(404).json({ error: 'location not found' });
    const projectId = loc.rows[0].project_id;
    const materials = await pool.query('SELECT material_name, quantity, unit FROM location_materials WHERE location_id = $1 AND phase = $2', [locationId, phase]);
    for (const m of materials.rows) {
      const qtyNum = parseFloat(String(m.quantity).replace(/[^\d.]/g, '')) || 0;
      if (qtyNum <= 0) continue;
      const stock = await pool.query('SELECT id, quantity FROM project_stock WHERE project_id = $1 AND material_name = $2', [projectId, m.material_name]);
      if (stock.rows.length === 0) {
        return res.status(400).json({
          error: 'insufficient_stock',
          message: 'عملية سحب غير ناجحة الرصيد غير كافي',
        });
      }
      const current = parseFloat(String(stock.rows[0].quantity).replace(/[^\d.]/g, '')) || 0;
      if (current < qtyNum) {
        return res.status(400).json({
          error: 'insufficient_stock',
          message: 'عملية سحب غير ناجحة الرصيد غير كافي',
        });
      }
    }
    await pool.query(
      'INSERT INTO location_withdrawal (location_id, phase, user_id, user_name, created_at, disbursement_permit_images_json, delivery_permit_images_json) VALUES ($1, $2, $3, $4, $5, $6, $7)',
      [locationId, phase, userId, userName, now, disbursementPermitImagesJson || null, deliveryPermitImagesJson || null]
    );
    for (const m of materials.rows) {
      const qtyNum = parseFloat(String(m.quantity).replace(/[^\d.]/g, '')) || 0;
      if (qtyNum <= 0) continue;
      const stock = await pool.query('SELECT id, quantity FROM project_stock WHERE project_id = $1 AND material_name = $2', [projectId, m.material_name]);
      if (stock.rows.length > 0) {
        const current = parseFloat(String(stock.rows[0].quantity).replace(/[^\d.]/g, '')) || 0;
        const newQty = current - qtyNum;
        await pool.query('UPDATE project_stock SET quantity = $1 WHERE id = $2', [newQty.toString(), stock.rows[0].id]);
      }
      await pool.query(
        'INSERT INTO project_stock_ledger (project_id, material_name, unit, quantity_delta, type, created_at, user_id, user_name) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
        [projectId, m.material_name, m.unit || '', -qtyNum, 'withdraw_location', now, userId, userName]
      );
    }
    await pool.query(
      `UPDATE withdrawal_requests
       SET fulfilled_at = $1, updated_at = $1
       WHERE location_id = $2 AND phase = $3 AND engineer_user_id = $4
         AND overall_status = 'approved' AND fulfilled_at IS NULL`,
      [now, locationId, phase, userId]
    );
    const projRes = await pool.query('SELECT name FROM projects WHERE id = $1', [projectId]);
    const projectName = projRes.rows.length ? projRes.rows[0].name : null;
    await notifyAppAdminsIfSiteEngineer(pool, userId, {
      title: 'إتمام سحب خامات',
      body:
        `قام "${userName}" بإتمام سحب خامات من موقع فرعي — مشروع "${projectName || 'غير محدد'}" — مرحلة: ${phase}`,
      eventType: 'material_withdrawal_completed',
      actorUserId: userId,
      actorUserName: userName,
      projectName,
    });
    const hasPermitDocs =
      (disbursementPermitImagesJson != null &&
        String(disbursementPermitImagesJson).trim() !== '' &&
        String(disbursementPermitImagesJson).trim() !== '[]') ||
      (deliveryPermitImagesJson != null &&
        String(deliveryPermitImagesJson).trim() !== '' &&
        String(deliveryPermitImagesJson).trim() !== '[]');
    if (hasPermitDocs) {
      await notifyAppAdminsOnDocumentUpload(pool, userId, userName, {
        title: 'مرفقات سحب خامات',
        body:
          `قام "${userName}" بإرفاق أذون صرف/تسليم مع سحب الخامات — مشروع "${projectName || 'غير محدد'}"`,
        eventType: 'withdrawal_permit_upload',
        projectName,
      });
    }
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// إلغاء سحب الخامات لموقع فرعي: حذف السجل واسترجاع رصيد مخزن المشروع وسجل الاستهلاك (مسؤول التطبيق فقط من الواجهة)
app.delete('/location-withdrawal', async (req, res) => {
  try {
    const locationId = parseInt(String(req.query.locationId || ''), 10);
    const phase = String(req.query.phase || 'first_fix').trim().toLowerCase();
    if (!locationId) return res.status(400).json({ error: 'locationId required' });

    const wR = await pool.query(
      'SELECT id, location_id, phase, user_id, user_name, created_at FROM location_withdrawal WHERE location_id = $1 AND phase = $2',
      [locationId, phase]
    );
    if (wR.rows.length === 0) {
      return res.status(404).json({ error: 'not_found', message: 'لا يوجد سحب مسجل لهذا الموقع' });
    }
    const w = wR.rows[0];
    const createdAt = w.created_at instanceof Date ? w.created_at.toISOString() : String(w.created_at);

    const loc = await pool.query('SELECT project_id FROM project_locations WHERE id = $1', [locationId]);
    if (loc.rows.length === 0) return res.status(404).json({ error: 'location not found' });
    const projectId = loc.rows[0].project_id;

    const ledgers = await pool.query(
      `SELECT id, material_name, quantity_delta, unit FROM project_stock_ledger
       WHERE project_id = $1 AND type = 'withdraw_location' AND created_at = $2`,
      [projectId, createdAt]
    );

    for (const l of ledgers.rows) {
      const qtyNum = Math.abs(parseFloat(l.quantity_delta) || 0);
      if (qtyNum <= 0) continue;
      const stock = await pool.query(
        'SELECT id, quantity FROM project_stock WHERE project_id = $1 AND material_name = $2',
        [projectId, l.material_name]
      );
      if (stock.rows.length > 0) {
        const current = parseFloat(String(stock.rows[0].quantity).replace(/[^\d.]/g, '')) || 0;
        const newQty = current + qtyNum;
        await pool.query('UPDATE project_stock SET quantity = $1 WHERE id = $2', [newQty.toString(), stock.rows[0].id]);
      } else {
        await pool.query(
          'INSERT INTO project_stock (project_id, material_name, quantity, unit) VALUES ($1, $2, $3, $4)',
          [projectId, l.material_name, qtyNum.toFixed(2), l.unit || '']
        );
      }
    }

    if (ledgers.rows.length > 0) {
      await pool.query(
        `DELETE FROM project_stock_ledger WHERE project_id = $1 AND type = 'withdraw_location' AND created_at = $2`,
        [projectId, createdAt]
      );
    }

    await pool.query('DELETE FROM location_withdrawal WHERE location_id = $1 AND phase = $2', [locationId, phase]);
    res.json({ ok: true, restoredLedgerRows: ledgers.rows.length });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

function withdrawalRequestRowToJson(row) {
  return {
    id: parseInt(row.id, 10),
    project_id: parseInt(row.project_id, 10),
    location_id: parseInt(row.location_id, 10),
    phase: row.phase || 'first_fix',
    engineer_user_id: parseInt(row.engineer_user_id, 10),
    engineer_user_name: row.engineer_user_name,
    location_path_label: row.location_path_label || '',
    sem_status: row.sem_status || 'pending',
    om_status: row.om_status || 'pending',
    sem_reason: row.sem_reason,
    om_reason: row.om_reason,
    sem_responded_at: row.sem_responded_at,
    om_responded_at: row.om_responded_at,
    overall_status: row.overall_status || 'pending',
    fulfilled_at: row.fulfilled_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

app.post('/withdrawal-requests', async (req, res) => {
  try {
    const projectId = parseInt(String(req.body?.projectId ?? req.body?.project_id ?? ''), 10);
    const locationId = parseInt(String(req.body?.locationId ?? req.body?.location_id ?? ''), 10);
    const userId = parseInt(String(req.body?.userId ?? req.body?.user_id ?? ''), 10);
    const userName = String(req.body?.userName ?? req.body?.user_name ?? '').trim();
    const phase = String(req.body?.phase || 'first_fix').trim().toLowerCase();
    const locationPathLabel = String(req.body?.locationPathLabel ?? req.body?.location_path_label ?? '').trim();
    if (Number.isNaN(projectId) || Number.isNaN(locationId) || Number.isNaN(userId) || !userName) {
      return res.status(400).json({ error: 'missing fields' });
    }
    const loc = await pool.query(
      'SELECT id, project_id FROM project_locations WHERE id = $1',
      [locationId]
    );
    if (loc.rows.length === 0) return res.status(404).json({ error: 'location not found' });
    if (parseInt(loc.rows[0].project_id, 10) !== projectId) {
      return res.status(400).json({ error: 'project mismatch' });
    }
    const ex = await pool.query(
      `SELECT * FROM withdrawal_requests
       WHERE location_id = $1 AND phase = $2
         AND fulfilled_at IS NULL
         AND overall_status IN ('pending', 'approved')`,
      [locationId, phase]
    );
    if (ex.rows.length > 0) {
      const r = ex.rows[0];
      if (parseInt(r.engineer_user_id, 10) !== userId) {
        return res.status(409).json({ error: 'existing_request_other_engineer' });
      }
      if (String(r.overall_status) === 'approved') {
        return res.status(409).json({ error: 'already_approved_complete_flow' });
      }
      return res.json({ ...withdrawalRequestRowToJson(r), existing: true });
    }
    const now = new Date().toISOString();
    const proj = await pool.query('SELECT name FROM projects WHERE id = $1', [projectId]);
    const projectName = proj.rows.length ? proj.rows[0].name : '';
    const ins = await pool.query(
      `INSERT INTO withdrawal_requests (
        project_id, location_id, phase, engineer_user_id, engineer_user_name,
        location_path_label, sem_status, om_status, overall_status,
        created_at, updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,'pending','pending','pending',$7,$7)
      RETURNING *`,
      [projectId, locationId, phase, userId, userName, locationPathLabel || '', now]
    );
    const row = ins.rows[0];
    const idNum = parseInt(row.id, 10);
    const bodyN =
      `طلب من "${userName}" — مشروع "${projectName}" — موقع: ${locationPathLabel || '—'}\n` +
      `رقم الطلب: ${idNum}`;
    await withdrawalInsertNotificationsForRoles(
      pool,
      ['site_engineer_manager', 'operation_manager', 'app_admin'],
      {
        title: 'طلب سحب خامات',
        body: bodyN,
        event_type: 'withdrawal_request_new',
        actor_user_id: userId,
        actor_user_name: userName,
        project_name: projectName,
      }
    );
    res.json({ ...withdrawalRequestRowToJson(row), existing: false });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/withdrawal-requests/for-engineer-project', async (req, res) => {
  try {
    const projectId = parseInt(String(req.query.projectId ?? ''), 10);
    const engineerUserId = parseInt(String(req.query.engineerUserId ?? ''), 10);
    if (Number.isNaN(projectId) || Number.isNaN(engineerUserId)) {
      return res.status(400).json({ error: 'projectId and engineerUserId required' });
    }
    const r = await pool.query(
      `SELECT * FROM withdrawal_requests
       WHERE project_id = $1 AND engineer_user_id = $2 AND fulfilled_at IS NULL
       ORDER BY id DESC`,
      [projectId, engineerUserId]
    );
    res.json(r.rows.map(withdrawalRequestRowToJson));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/withdrawal-requests/open', async (req, res) => {
  try {
    const locationId = parseInt(String(req.query.locationId ?? ''), 10);
    const phase = String(req.query.phase || 'first_fix').trim().toLowerCase();
    if (Number.isNaN(locationId)) return res.status(400).json({ error: 'locationId required' });
    const r = await pool.query(
      `SELECT * FROM withdrawal_requests
       WHERE location_id = $1 AND phase = $2
         AND fulfilled_at IS NULL
         AND overall_status IN ('pending', 'approved')`,
      [locationId, phase]
    );
    if (r.rows.length === 0) return res.json(null);
    res.json(withdrawalRequestRowToJson(r.rows[0]));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/withdrawal-requests/action-count', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId ?? ''), 10);
    const role = String(req.query.role || '').trim();
    if (Number.isNaN(userId) || !role) return res.status(400).json({ error: 'userId and role required' });
    const u = await pool.query('SELECT role FROM users WHERE id = $1', [userId]);
    if (u.rows.length === 0 || String(u.rows[0].role) !== role) {
      return res.json({ count: 0 });
    }
    let q;
    if (role === 'site_engineer_manager') {
      q = `SELECT (
        (SELECT COUNT(*)::int FROM withdrawal_requests
           WHERE overall_status = 'pending' AND sem_status = 'pending' AND fulfilled_at IS NULL)
        +
        (SELECT COUNT(*)::int FROM executed_plans
           WHERE status = 'postponed' AND sem_resolved_at IS NULL)
      ) AS c`;
    } else if (role === 'operation_manager') {
      q = `SELECT COUNT(*)::int AS c FROM withdrawal_requests
           WHERE overall_status = 'pending' AND om_status = 'pending' AND fulfilled_at IS NULL`;
    } else {
      return res.json({ count: 0 });
    }
    const c = await pool.query(q);
    res.json({ count: parseInt(c.rows[0]?.c || '0', 10) });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/withdrawal-requests/pending-actions', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId ?? ''), 10);
    const role = String(req.query.role || '').trim();
    if (Number.isNaN(userId) || !role) return res.status(400).json({ error: 'userId and role required' });
    const u = await pool.query('SELECT role FROM users WHERE id = $1', [userId]);
    if (u.rows.length === 0 || String(u.rows[0].role) !== role) {
      return res.json([]);
    }
    let r;
    if (role === 'site_engineer_manager') {
      r = await pool.query(
        `SELECT wr.*, p.name AS project_name FROM withdrawal_requests wr
         INNER JOIN projects p ON p.id = wr.project_id
         WHERE wr.overall_status = 'pending' AND wr.sem_status = 'pending' AND wr.fulfilled_at IS NULL
         ORDER BY wr.id DESC`
      );
    } else if (role === 'operation_manager') {
      r = await pool.query(
        `SELECT wr.*, p.name AS project_name FROM withdrawal_requests wr
         INNER JOIN projects p ON p.id = wr.project_id
         WHERE wr.overall_status = 'pending' AND wr.om_status = 'pending' AND wr.fulfilled_at IS NULL
         ORDER BY wr.id DESC`
      );
    } else {
      return res.json([]);
    }
    res.json(
      r.rows.map((row) => ({
        ...withdrawalRequestRowToJson(row),
        project_name: row.project_name,
      }))
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/withdrawal-requests/:id/respond', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    const userId = parseInt(String(req.body?.userId ?? req.body?.user_id ?? ''), 10);
    const decision = String(req.body?.decision || '').trim().toLowerCase();
    const reason = req.body?.reason != null ? String(req.body.reason).trim() : '';
    if (Number.isNaN(id) || Number.isNaN(userId) || (decision !== 'approve' && decision !== 'reject')) {
      return res.status(400).json({ error: 'invalid request' });
    }
    if (decision === 'reject' && !reason) {
      return res.status(400).json({ error: 'reason_required' });
    }
    const actor = await pool.query('SELECT id, role, name FROM users WHERE id = $1', [userId]);
    if (actor.rows.length === 0) return res.status(404).json({ error: 'user not found' });
    const actorRole = String(actor.rows[0].role || '');
    if (actorRole !== 'site_engineer_manager' && actorRole !== 'operation_manager') {
      return res.status(403).json({ error: 'forbidden' });
    }
    const rq = await pool.query('SELECT * FROM withdrawal_requests WHERE id = $1', [id]);
    if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const row = rq.rows[0];
    if (row.fulfilled_at != null || String(row.overall_status) === 'rejected') {
      return res.status(400).json({ error: 'closed' });
    }
    if (String(row.overall_status) === 'approved') {
      return res.status(400).json({ error: 'already_approved' });
    }
    const now = new Date().toISOString();
    const proj = await pool.query('SELECT name FROM projects WHERE id = $1', [row.project_id]);
    const projectName = proj.rows.length ? proj.rows[0].name : '';
    const pathLabel = row.location_path_label || '';
    const engId = parseInt(row.engineer_user_id, 10);
    const engName = row.engineer_user_name;

    if (actorRole === 'site_engineer_manager') {
      if (String(row.sem_status) !== 'pending') {
        return res.status(400).json({ error: 'already_responded' });
      }
      if (decision === 'reject') {
        await pool.query(
          `UPDATE withdrawal_requests SET sem_status = 'rejected', sem_reason = $1, sem_responded_at = $2,
           overall_status = 'rejected', updated_at = $2 WHERE id = $3`,
          [reason, now, id]
        );
        await withdrawalNotifyEngineer(pool, engId, {
          title: 'رفض طلب سحب خامات',
          body: `تم رفض طلبك بسبب: ${reason}`,
          event_type: 'withdrawal_request_rejected',
          actor_user_id: userId,
          actor_user_name: actor.rows[0].name,
          project_name: projectName,
        });
        await withdrawalInsertNotificationsForRoles(pool, ['operation_manager'], {
          title: 'طلب سحب خامات — مرفوض',
          body: `رُفض الطلب من مدير المشروعات. السبب: ${reason}\nالمهندس: ${engName} — ${pathLabel}`,
          event_type: 'withdrawal_request_rejected_by_sem',
          actor_user_id: userId,
          actor_user_name: actor.rows[0].name,
          project_name: projectName,
        });
        return res.json({ ok: true });
      }
      await pool.query(
        `UPDATE withdrawal_requests SET sem_status = 'approved', sem_responded_at = $1, updated_at = $1 WHERE id = $2`,
        [now, id]
      );
      if (String(row.om_status) === 'approved') {
        await pool.query(
          `UPDATE withdrawal_requests SET overall_status = 'approved', updated_at = $1 WHERE id = $2`,
          [now, id]
        );
        await withdrawalNotifyEngineer(pool, engId, {
          title: 'تمت الموافقة على طلب سحب الخامات',
          body: `يمكنك الآن إكمال سحب الخامات من الموقع: ${pathLabel} — مشروع "${projectName}"`,
          event_type: 'withdrawal_request_approved',
          actor_user_id: userId,
          actor_user_name: actor.rows[0].name,
          project_name: projectName,
        });
      } else {
        await withdrawalInsertNotificationsForRoles(pool, ['operation_manager'], {
          title: 'بانتظار موافقتكم — طلب سحب خامات',
          body: `وافق مدير المشروعات. بانتظار موافقة مدير العمليات.\nالمهندس: ${engName} — ${pathLabel} — رقم الطلب: ${id}`,
          event_type: 'withdrawal_request_waiting_om',
          actor_user_id: engId,
          actor_user_name: engName,
          project_name: projectName,
        });
      }
      return res.json({ ok: true });
    }

    if (actorRole === 'operation_manager') {
      if (String(row.om_status) !== 'pending') {
        return res.status(400).json({ error: 'already_responded' });
      }
      if (decision === 'reject') {
        await pool.query(
          `UPDATE withdrawal_requests SET om_status = 'rejected', om_reason = $1, om_responded_at = $2,
           overall_status = 'rejected', updated_at = $2 WHERE id = $3`,
          [reason, now, id]
        );
        await withdrawalNotifyEngineer(pool, engId, {
          title: 'رفض طلب سحب خامات',
          body: `تم رفض طلبك بسبب: ${reason}`,
          event_type: 'withdrawal_request_rejected',
          actor_user_id: userId,
          actor_user_name: actor.rows[0].name,
          project_name: projectName,
        });
        await withdrawalInsertNotificationsForRoles(pool, ['site_engineer_manager'], {
          title: 'طلب سحب خامات — مرفوض',
          body: `رُفض الطلب من مدير العمليات. السبب: ${reason}\nالمهندس: ${engName} — ${pathLabel}`,
          event_type: 'withdrawal_request_rejected_by_om',
          actor_user_id: userId,
          actor_user_name: actor.rows[0].name,
          project_name: projectName,
        });
        return res.json({ ok: true });
      }
      await pool.query(
        `UPDATE withdrawal_requests SET om_status = 'approved', om_responded_at = $1, updated_at = $1 WHERE id = $2`,
        [now, id]
      );
      if (String(row.sem_status) === 'approved') {
        await pool.query(
          `UPDATE withdrawal_requests SET overall_status = 'approved', updated_at = $1 WHERE id = $2`,
          [now, id]
        );
        await withdrawalNotifyEngineer(pool, engId, {
          title: 'تمت الموافقة على طلب سحب الخامات',
          body: `يمكنك الآن إكمال سحب الخامات من الموقع: ${pathLabel} — مشروع "${projectName}"`,
          event_type: 'withdrawal_request_approved',
          actor_user_id: userId,
          actor_user_name: actor.rows[0].name,
          project_name: projectName,
        });
      } else {
        await withdrawalInsertNotificationsForRoles(pool, ['site_engineer_manager'], {
          title: 'بانتظار موافقتكم — طلب سحب خامات',
          body: `وافق مدير العمليات. بانتظار موافقة مدير المشروعات.\nالمهندس: ${engName} — ${pathLabel} — رقم الطلب: ${id}`,
          event_type: 'withdrawal_request_waiting_sem',
          actor_user_id: engId,
          actor_user_name: engName,
          project_name: projectName,
        });
      }
      return res.json({ ok: true });
    }
    return res.status(403).json({ error: 'forbidden' });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/withdrawal-requests/:id/fulfill', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    const userId = parseInt(String(req.body?.userId ?? req.body?.user_id ?? ''), 10);
    if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });
    const rq = await pool.query('SELECT * FROM withdrawal_requests WHERE id = $1', [id]);
    if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const row = rq.rows[0];
    if (parseInt(row.engineer_user_id, 10) !== userId) {
      return res.status(403).json({ error: 'forbidden' });
    }
    if (String(row.overall_status) !== 'approved') {
      return res.status(400).json({ error: 'not_approved' });
    }
    if (row.fulfilled_at != null) return res.json({ ok: true });
    const now = new Date().toISOString();
    await pool.query(
      `UPDATE withdrawal_requests SET fulfilled_at = $1, updated_at = $1 WHERE id = $2`,
      [now, id]
    );
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// ——— Reports-SYS (circulated reports workflow) ———
app.get('/reports-sys/check-name', async (req, res) => {
  try {
    const name = String(req.query.name || '').trim();
    const excludeId = parseInt(String(req.query.excludeId || ''), 10);
    if (!name) return res.json({ available: false, error: 'name_required' });
    const r = await pool.query(
      `SELECT id FROM reports_sys WHERE LOWER(TRIM(report_name)) = LOWER(TRIM($1)) LIMIT 1`,
      [name],
    );
    if (r.rows.length === 0) return res.json({ available: true });
    const existingId = parseInt(r.rows[0].id, 10);
    if (!Number.isNaN(excludeId) && existingId === excludeId) {
      return res.json({ available: true });
    }
    return res.json({ available: false });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/reports-sys/pending-count', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId || ''), 10);
    if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
    const r = await pool.query(
      `SELECT COUNT(*)::int AS count FROM reports_sys
       WHERE current_assignee_user_id = $1 AND status = 'pending_review'`,
      [userId],
    );
    res.json({ count: r.rows[0]?.count ?? 0 });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/reports-sys/inbox', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId || ''), 10);
    const tab = String(req.query.tab || 'pending').trim().toLowerCase();
    const requesterEmail = String(req.query.requesterEmail || '').trim().toLowerCase();
    const searchQ = String(req.query.q || req.query.search || '').trim();
    if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });

    let sql;
    let params;
    if (tab === 'pending') {
      sql = `SELECT * FROM reports_sys
             WHERE current_assignee_user_id = $1 AND status IN ('pending_review', 'returned_for_edit')
             ORDER BY updated_at DESC`;
      params = [userId];
    } else if (tab === 'sent') {
      sql = `SELECT DISTINCT r.* FROM reports_sys r
             INNER JOIN reports_sys_actions a ON a.report_id = r.id
             WHERE a.actor_user_id = $1
             ORDER BY r.updated_at DESC`;
      params = [userId];
    } else if (tab === 'created') {
      sql = `SELECT * FROM reports_sys WHERE created_by_user_id = $1 ORDER BY updated_at DESC`;
      params = [userId];
    } else if (tab === 'archive') {
      const actor = await pool.query('SELECT role, email FROM users WHERE id = $1', [userId]);
      if (actor.rows.length === 0) return res.status(404).json({ error: 'user not found' });
      const canViewArchive = reportsSysHasFullAccess(String(actor.rows[0].role || ''));
      if (!canViewArchive) return res.status(403).json({ error: 'forbidden' });
      let archiveSql = `SELECT * FROM reports_sys WHERE status = 'archived'`;
      let archiveParams = [];
      ({ sql: archiveSql, params: archiveParams } = reportsSysAppendTextSearch(
        archiveSql,
        archiveParams,
        searchQ,
      ));
      sql = `${archiveSql} ORDER BY archived_at DESC NULLS LAST, updated_at DESC`;
      params = archiveParams;
    } else if (tab === 'rejected') {
      const actor = await pool.query('SELECT role, email FROM users WHERE id = $1', [userId]);
      if (actor.rows.length === 0) return res.status(404).json({ error: 'user not found' });
      if (!reportsSysHasFullAccess(String(actor.rows[0].role || ''))) {
        let rejectedSql = `SELECT * FROM reports_sys
               WHERE status = 'rejected' AND created_by_user_id = $1`;
        let rejectedParams = [userId];
        ({ sql: rejectedSql, params: rejectedParams } = reportsSysAppendTextSearch(
          rejectedSql,
          rejectedParams,
          searchQ,
        ));
        sql = `${rejectedSql} ORDER BY rejected_at DESC NULLS LAST, updated_at DESC`;
        params = rejectedParams;
      } else {
        let rejectedSql = `SELECT * FROM reports_sys WHERE status = 'rejected'`;
        let rejectedParams = [];
        ({ sql: rejectedSql, params: rejectedParams } = reportsSysAppendTextSearch(
          rejectedSql,
          rejectedParams,
          searchQ,
        ));
        sql = `${rejectedSql} ORDER BY rejected_at DESC NULLS LAST, updated_at DESC`;
        params = rejectedParams;
      }
    } else if (tab === 'all') {
      const actor = await pool.query('SELECT role FROM users WHERE id = $1', [userId]);
      if (actor.rows.length === 0) return res.status(404).json({ error: 'user not found' });
      if (!reportsSysHasFullAccess(String(actor.rows[0].role || ''))) {
        return res.status(403).json({ error: 'forbidden' });
      }
      sql = `SELECT * FROM reports_sys ORDER BY updated_at DESC`;
      params = [];
    } else {
      return res.status(400).json({ error: 'invalid tab' });
    }

    const r = params.length
      ? await pool.query(sql, params)
      : await pool.query(sql);
    res.json(r.rows.map((row) => reportsSysMapRow(row)));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/reports-sys/:id', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    if (Number.isNaN(id)) return res.status(400).json({ error: 'invalid id' });
    const detail = await reportsSysLoadDetail(pool, id);
    if (!detail) return res.status(404).json({ error: 'not found' });
    res.json(detail);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.delete('/reports-sys/:id', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    const userId = parseInt(String(req.query.userId || req.body?.userId || ''), 10);
    if (Number.isNaN(id) || Number.isNaN(userId)) {
      return res.status(400).json({ error: 'invalid' });
    }

    const actor = await pool.query('SELECT id, name, email FROM users WHERE id = $1', [userId]);
    if (actor.rows.length === 0) return res.status(404).json({ error: 'user not found' });
    const actorEmail = String(actor.rows[0].email || '').trim().toLowerCase();
    if (actorEmail !== REPORTS_SYS_PRIMARY_ADMIN_EMAIL.toLowerCase()) {
      return res.status(403).json({ error: 'forbidden_delete' });
    }

    const existing = await pool.query(
      'SELECT id, report_name FROM reports_sys WHERE id = $1',
      [id],
    );
    if (existing.rows.length === 0) return res.status(404).json({ error: 'not found' });

    await pool.query('DELETE FROM reports_sys WHERE id = $1', [id]);

    await reportsSysNotifyPrimaryAdmin(pool, {
      title: 'Reports-SYS — حذف تقرير',
      body: `${actor.rows[0].name} حذف التقرير «${existing.rows[0].report_name}» نهائياً`,
      eventType: `reports_sys_${id}`,
      actorUserId: userId,
      actorUserName: actor.rows[0].name,
      reportName: existing.rows[0].report_name,
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/reports-sys/:id/attachments/:attachmentId', async (req, res) => {
  try {
    const reportId = parseInt(String(req.params.id || ''), 10);
    const attachmentId = parseInt(String(req.params.attachmentId || ''), 10);
    if (Number.isNaN(reportId) || Number.isNaN(attachmentId)) {
      return res.status(400).json({ error: 'invalid' });
    }
    const r = await pool.query(
      `SELECT file_name, mime_type, data_base64 FROM reports_sys_attachments
       WHERE id = $1 AND report_id = $2`,
      [attachmentId, reportId],
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

app.post('/reports-sys', async (req, res) => {
  try {
    const b = req.body || {};
    const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
    const reportName = String(b.reportName ?? b.report_name ?? '').trim();
    const reportType = String(b.reportType ?? b.report_type ?? '').trim();
    const summary = String(b.summary ?? '').trim();
    const notes = b.notes != null ? String(b.notes).trim() : '';
    const sourceReportId = b.sourceReportId != null
      ? parseInt(String(b.sourceReportId), 10)
      : null;
    if (Number.isNaN(userId) || !reportName || !reportType || !summary) {
      return res.status(400).json({ error: 'missing fields' });
    }
    if (!REPORTS_SYS_TYPES.includes(reportType)) {
      return res.status(400).json({ error: 'invalid_report_type' });
    }
    const actor = await pool.query('SELECT id, name, email FROM users WHERE id = $1', [userId]);
    if (actor.rows.length === 0) return res.status(404).json({ error: 'user not found' });
    const dup = await pool.query(
      `SELECT id FROM reports_sys WHERE LOWER(TRIM(report_name)) = LOWER(TRIM($1)) LIMIT 1`,
      [reportName],
    );
    if (dup.rows.length > 0) return res.status(409).json({ error: 'name_taken' });

    const project = await reportsSysResolveProject(pool, b);
    if (project.error) return res.status(400).json({ error: project.error });

    const now = new Date().toISOString();
    const ins = await pool.query(
      `INSERT INTO reports_sys (
        report_name, report_type, summary, notes, status,
        created_by_user_id, created_by_user_name,
        current_assignee_user_id, current_assignee_user_name,
        source_report_id, project_id, project_name,
        created_at, updated_at
      ) VALUES ($1,$2,$3,$4,'draft',$5,$6,$5,$6,$7,$8,$9,$10,$10) RETURNING id`,
      [
        reportName,
        reportType,
        summary,
        notes || null,
        userId,
        actor.rows[0].name,
        Number.isNaN(sourceReportId) ? null : sourceReportId,
        project.project_id,
        project.project_name,
        now,
      ],
    );
    const reportId = parseInt(ins.rows[0].id, 10);
    await reportsSysInsertAction(pool, {
      reportId,
      actorUserId: userId,
      actorUserName: actor.rows[0].name,
      action: 'created',
      comment: sourceReportId ? `من تقرير سابق #${sourceReportId}` : null,
    });
    await reportsSysNotifyPrimaryAdmin(pool, {
      title: 'Reports-SYS — تقرير جديد',
      body: `أنشأ ${actor.rows[0].name} مسودة تقرير «${reportName}» (${reportType})`,
      eventType: `reports_sys_${reportId}`,
      actorUserId: userId,
      actorUserName: actor.rows[0].name,
      reportName,
    });
    const detail = await reportsSysLoadDetail(pool, reportId);
    res.status(201).json(detail);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.put('/reports-sys/:id', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    const b = req.body || {};
    const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
    if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });

    const rq = await pool.query('SELECT * FROM reports_sys WHERE id = $1', [id]);
    if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const row = rq.rows[0];
    const status = String(row.status);
    const creatorId = parseInt(row.created_by_user_id, 10);
    const assigneeId = row.current_assignee_user_id != null
      ? parseInt(row.current_assignee_user_id, 10)
      : null;

    if (userId !== creatorId) return res.status(403).json({ error: 'forbidden' });
    if (!(status === 'draft' || status === 'returned_for_edit')) {
      return res.status(400).json({ error: 'not_editable' });
    }
    if (assigneeId !== userId) return res.status(403).json({ error: 'not_current_holder' });

    const reportName = String(b.reportName ?? b.report_name ?? row.report_name).trim();
    const reportType = String(b.reportType ?? b.report_type ?? row.report_type).trim();
    const summary = String(b.summary ?? row.summary ?? '').trim();
    const notes = b.notes != null ? String(b.notes).trim() : (row.notes || '');
    if (!reportName || !reportType || !summary) {
      return res.status(400).json({ error: 'missing fields' });
    }
    if (!REPORTS_SYS_TYPES.includes(reportType)) {
      return res.status(400).json({ error: 'invalid_report_type' });
    }
    const dup = await pool.query(
      `SELECT id FROM reports_sys WHERE LOWER(TRIM(report_name)) = LOWER(TRIM($1)) AND id <> $2 LIMIT 1`,
      [reportName, id],
    );
    if (dup.rows.length > 0) return res.status(409).json({ error: 'name_taken' });

    const project = await reportsSysResolveProject(pool, b, row);
    if (project.error) return res.status(400).json({ error: project.error });

    const now = new Date().toISOString();
    await pool.query(
      `UPDATE reports_sys SET report_name=$1, report_type=$2, summary=$3, notes=$4,
       project_id=$5, project_name=$6, updated_at=$7 WHERE id=$8`,
      [
        reportName,
        reportType,
        summary,
        notes || null,
        project.project_id,
        project.project_name,
        now,
        id,
      ],
    );

    const actor = await pool.query('SELECT name FROM users WHERE id = $1', [userId]);
    const actorName = actor.rows.length ? actor.rows[0].name : '';

    if (Array.isArray(b.attachments)) {
      await pool.query('DELETE FROM reports_sys_attachments WHERE report_id = $1', [id]);
      for (const att of b.attachments) {
        const fileName = String(att.fileName ?? att.file_name ?? 'file').trim();
        const mimeType = String(att.mimeType ?? att.mime_type ?? 'application/octet-stream');
        const dataBase64 = String(att.dataBase64 ?? att.data_base64 ?? '');
        const sizeBytes = parseInt(String(att.sizeBytes ?? att.size_bytes ?? '0'), 10);
        if (!dataBase64) continue;
        if (sizeBytes > REPORTS_SYS_MAX_ATTACHMENT_BYTES) {
          return res.status(400).json({ error: 'attachment_too_large' });
        }
        await pool.query(
          `INSERT INTO reports_sys_attachments (report_id, file_name, mime_type, data_base64, size_bytes, created_at)
           VALUES ($1,$2,$3,$4,$5,$6)`,
          [id, fileName, mimeType, dataBase64, sizeBytes, now],
        );
      }
    }

    await reportsSysNotifyPrimaryAdmin(pool, {
      title: 'Reports-SYS — تعديل تقرير',
      body: `عدّل ${actorName} التقرير «${reportName}»`,
      eventType: `reports_sys_${id}`,
      actorUserId: userId,
      actorUserName: actorName,
      reportName,
    });

    const detail = await reportsSysLoadDetail(pool, id);
    res.json(detail);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/reports-sys/:id/submit', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    const b = req.body || {};
    const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
    const toUserId = parseInt(String(b.toUserId ?? b.to_user_id ?? ''), 10);
    const comment = b.comment != null ? String(b.comment).trim() : '';
    if (Number.isNaN(id) || Number.isNaN(userId) || Number.isNaN(toUserId)) {
      return res.status(400).json({ error: 'invalid' });
    }
    if (userId === toUserId) return res.status(400).json({ error: 'cannot_send_to_self' });

    const rq = await pool.query('SELECT * FROM reports_sys WHERE id = $1', [id]);
    if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const row = rq.rows[0];
    const status = String(row.status);
    const creatorId = parseInt(row.created_by_user_id, 10);
    const assigneeId = row.current_assignee_user_id != null
      ? parseInt(row.current_assignee_user_id, 10)
      : null;

    if (userId !== creatorId || assigneeId !== userId) {
      return res.status(403).json({ error: 'forbidden' });
    }
    if (!(status === 'draft' || status === 'returned_for_edit')) {
      return res.status(400).json({ error: 'invalid_status' });
    }

    const toUser = await pool.query('SELECT id, name, role FROM users WHERE id = $1', [toUserId]);
    if (toUser.rows.length === 0) return res.status(404).json({ error: 'recipient not found' });
    const actor = await pool.query('SELECT name FROM users WHERE id = $1', [userId]);
    const actorName = actor.rows.length ? actor.rows[0].name : '';
    const now = new Date().toISOString();
    const actionType = status === 'returned_for_edit' ? 'resubmit' : 'submit';

    await pool.query(
      `UPDATE reports_sys SET status='pending_review', current_assignee_user_id=$1,
       current_assignee_user_name=$2, updated_at=$3 WHERE id=$4`,
      [toUserId, toUser.rows[0].name, now, id],
    );
    await reportsSysInsertAction(pool, {
      reportId: id,
      actorUserId: userId,
      actorUserName: actorName,
      action: actionType,
      comment: comment || null,
      fromUserId: userId,
      toUserId,
      toUserName: toUser.rows[0].name,
    });

    const reportName = row.report_name;
    await reportsSysNotifyUser(pool, toUserId, {
      title: 'Reports-SYS — تقرير بانتظار مراجعتك',
      body: `أرسل إليك ${actorName} التقرير «${reportName}» للاطلاع والتوجيه`,
      eventType: `reports_sys_${id}`,
      actorUserId: userId,
      actorUserName: actorName,
      reportName,
    });
    await reportsSysNotifyPrimaryAdmin(pool, {
      title: 'Reports-SYS — إرسال تقرير',
      body: `${actorName} أرسل التقرير «${reportName}» إلى ${toUser.rows[0].name}`,
      eventType: `reports_sys_${id}`,
      actorUserId: userId,
      actorUserName: actorName,
      reportName,
    });

    res.json(await reportsSysLoadDetail(pool, id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/reports-sys/:id/respond', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    const b = req.body || {};
    const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
    const action = String(b.action || '').trim().toLowerCase();
    const toUserId = b.toUserId != null ? parseInt(String(b.toUserId ?? b.to_user_id), 10) : null;
    const comment = b.comment != null ? String(b.comment).trim() : '';
    if (Number.isNaN(id) || Number.isNaN(userId)) return res.status(400).json({ error: 'invalid' });
    if (!['forward', 'return', 'reject', 'archive'].includes(action)) {
      return res.status(400).json({ error: 'invalid_action' });
    }

    const rq = await pool.query('SELECT * FROM reports_sys WHERE id = $1', [id]);
    if (rq.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const row = rq.rows[0];
    const status = String(row.status);
    if (status !== 'pending_review') return res.status(400).json({ error: 'not_pending' });
    const assigneeId = row.current_assignee_user_id != null
      ? parseInt(row.current_assignee_user_id, 10)
      : null;
    if (assigneeId !== userId) return res.status(403).json({ error: 'not_current_holder' });

    const actor = await pool.query('SELECT id, name, role, email FROM users WHERE id = $1', [userId]);
    if (actor.rows.length === 0) return res.status(404).json({ error: 'user not found' });
    const actorName = actor.rows[0].name;
    const creatorId = parseInt(row.created_by_user_id, 10);
    const reportName = row.report_name;
    const now = new Date().toISOString();

    if (action === 'reject') {
      if (!comment) return res.status(400).json({ error: 'reason_required' });
      await pool.query(
        `UPDATE reports_sys SET status='rejected', rejection_reason=$1, rejected_at=$2,
         current_assignee_user_id=$3, current_assignee_user_name=$4, updated_at=$2 WHERE id=$5`,
        [comment, now, creatorId, row.created_by_user_name, id],
      );
      await reportsSysInsertAction(pool, {
        reportId: id,
        actorUserId: userId,
        actorUserName: actorName,
        action: 'reject',
        comment,
        fromUserId: userId,
        toUserId: creatorId,
        toUserName: row.created_by_user_name,
      });
      await reportsSysNotifyUser(pool, creatorId, {
        title: 'Reports-SYS — رُفض التقرير',
        body: `رُفض التقرير «${reportName}». السبب: ${comment}`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      await reportsSysNotifyPrimaryAdmin(pool, {
        title: 'Reports-SYS — رفض تقرير',
        body: `${actorName} رفض التقرير «${reportName}». السبب: ${comment}`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      return res.json(await reportsSysLoadDetail(pool, id));
    }

    if (action === 'return') {
      if (!comment) return res.status(400).json({ error: 'comment_required' });
      await pool.query(
        `UPDATE reports_sys SET status='returned_for_edit', current_assignee_user_id=$1,
         current_assignee_user_name=$2, updated_at=$3 WHERE id=$4`,
        [creatorId, row.created_by_user_name, now, id],
      );
      await reportsSysInsertAction(pool, {
        reportId: id,
        actorUserId: userId,
        actorUserName: actorName,
        action: 'return',
        comment,
        fromUserId: userId,
        toUserId: creatorId,
        toUserName: row.created_by_user_name,
      });
      await reportsSysNotifyUser(pool, creatorId, {
        title: 'Reports-SYS — أُعيد التقرير للتعديل',
        body: `أعاد ${actorName} التقرير «${reportName}» للتعديل. الملاحظة: ${comment}`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      await reportsSysNotifyPrimaryAdmin(pool, {
        title: 'Reports-SYS — إرجاع للتعديل',
        body: `${actorName} أعاد التقرير «${reportName}» إلى المنشئ للتعديل`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      return res.json(await reportsSysLoadDetail(pool, id));
    }

    if (action === 'archive') {
      const canArchive = await reportsSysCanArchive(
        String(actor.rows[0].role || ''),
        String(actor.rows[0].email || ''),
      );
      if (!canArchive) return res.status(403).json({ error: 'forbidden_archive' });
      await pool.query(
        `UPDATE reports_sys SET status='archived', archived_at=$1, current_assignee_user_id=NULL,
         current_assignee_user_name=NULL, updated_at=$1 WHERE id=$2`,
        [now, id],
      );
      await reportsSysInsertAction(pool, {
        reportId: id,
        actorUserId: userId,
        actorUserName: actorName,
        action: 'archive',
        comment: comment || null,
        fromUserId: userId,
      });
      await reportsSysNotifyUser(pool, creatorId, {
        title: 'Reports-SYS — أُرشف التقرير',
        body: `تم قبول وأرشفة التقرير «${reportName}» بواسطة ${actorName}`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      await reportsSysNotifyPrimaryAdmin(pool, {
        title: 'Reports-SYS — أرشفة',
        body: `${actorName} أرشف التقرير «${reportName}»`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      return res.json(await reportsSysLoadDetail(pool, id));
    }

    if (action === 'forward') {
      if (Number.isNaN(toUserId) || toUserId == null) {
        return res.status(400).json({ error: 'to_user_required' });
      }
      if (toUserId === userId) return res.status(400).json({ error: 'cannot_send_to_self' });
      const toUser = await pool.query('SELECT id, name FROM users WHERE id = $1', [toUserId]);
      if (toUser.rows.length === 0) return res.status(404).json({ error: 'recipient not found' });
      await pool.query(
        `UPDATE reports_sys SET current_assignee_user_id=$1, current_assignee_user_name=$2, updated_at=$3 WHERE id=$4`,
        [toUserId, toUser.rows[0].name, now, id],
      );
      await reportsSysInsertAction(pool, {
        reportId: id,
        actorUserId: userId,
        actorUserName: actorName,
        action: 'forward',
        comment: comment || null,
        fromUserId: userId,
        toUserId,
        toUserName: toUser.rows[0].name,
      });
      await reportsSysNotifyUser(pool, toUserId, {
        title: 'Reports-SYS — تقرير موجّه إليك',
        body: `وجّه ${actorName} إليك التقرير «${reportName}» بعد الاطلاع`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      await reportsSysNotifyPrimaryAdmin(pool, {
        title: 'Reports-SYS — توجيه تقرير',
        body: `${actorName} وجّه التقرير «${reportName}» إلى ${toUser.rows[0].name}`,
        eventType: `reports_sys_${id}`,
        actorUserId: userId,
        actorUserName: actorName,
        reportName,
      });
      return res.json(await reportsSysLoadDetail(pool, id));
    }

    return res.status(400).json({ error: 'invalid_action' });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/reports-sys/:id/relaunch', async (req, res) => {
  try {
    const sourceId = parseInt(String(req.params.id || ''), 10);
    const b = req.body || {};
    const userId = parseInt(String(b.userId ?? b.user_id ?? ''), 10);
    const reportName = String(b.reportName ?? b.report_name ?? '').trim();
    if (Number.isNaN(sourceId) || Number.isNaN(userId) || !reportName) {
      return res.status(400).json({ error: 'invalid' });
    }
    const src = await pool.query('SELECT * FROM reports_sys WHERE id = $1', [sourceId]);
    if (src.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const source = src.rows[0];
    if (!['rejected', 'archived'].includes(String(source.status))) {
      return res.status(400).json({ error: 'invalid_source_status' });
    }
    const dup = await pool.query(
      `SELECT id FROM reports_sys WHERE LOWER(TRIM(report_name)) = LOWER(TRIM($1)) LIMIT 1`,
      [reportName],
    );
    if (dup.rows.length > 0) return res.status(409).json({ error: 'name_taken' });
    const actor = await pool.query('SELECT name FROM users WHERE id = $1', [userId]);
    const actorName = actor.rows.length ? actor.rows[0].name : '';
    const now = new Date().toISOString();
    const ins = await pool.query(
      `INSERT INTO reports_sys (
        report_name, report_type, summary, notes, status,
        created_by_user_id, created_by_user_name,
        current_assignee_user_id, current_assignee_user_name,
        source_report_id, project_id, project_name,
        created_at, updated_at
      ) VALUES ($1,$2,$3,$4,'draft',$5,$6,$5,$6,$7,$8,$9,$10,$10) RETURNING id`,
      [
        reportName,
        source.report_type,
        source.summary,
        source.notes,
        userId,
        actorName,
        sourceId,
        source.project_id ?? null,
        source.project_name || '',
        now,
      ],
    );
    const newId = parseInt(ins.rows[0].id, 10);
    const oldAtt = await pool.query(
      'SELECT file_name, mime_type, data_base64, size_bytes FROM reports_sys_attachments WHERE report_id = $1',
      [sourceId],
    );
    for (const a of oldAtt.rows) {
      await pool.query(
        `INSERT INTO reports_sys_attachments (report_id, file_name, mime_type, data_base64, size_bytes, created_at)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [newId, a.file_name, a.mime_type, a.data_base64, a.size_bytes, now],
      );
    }
    await reportsSysInsertAction(pool, {
      reportId: newId,
      actorUserId: userId,
      actorUserName: actorName,
      action: 'created',
      comment: `إعادة إطلاق من تقرير #${sourceId}`,
    });
    await reportsSysNotifyPrimaryAdmin(pool, {
      title: 'Reports-SYS — إعادة إطلاق تقرير',
      body: `${actorName} أنشأ تقريراً جديداً «${reportName}» من تقرير سابق #${sourceId}`,
      eventType: `reports_sys_${newId}`,
      actorUserId: userId,
      actorUserName: actorName,
      reportName,
    });
    res.status(201).json(await reportsSysLoadDetail(pool, newId));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/units', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, building_id, name, model, image_path FROM units WHERE building_id = $1 ORDER BY name', [req.query.buildingId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), building_id: parseInt(row.building_id), name: row.name, model: row.model, image_path: row.image_path })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/units', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query('INSERT INTO units (building_id, name, model, image_path) VALUES ($1, $2, $3, $4) RETURNING id', [b.buildingId, b.name, b.model || b.name, b.imagePath || null]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/units/:id', async (req, res) => {
  try {
    const b = req.body;
    await pool.query('UPDATE units SET name = $1, model = $2, image_path = $3 WHERE id = $4', [b.name, b.model, b.imagePath || null, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/units/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM units WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/building-materials', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, building_id, material_name, quantity, unit, length, pieces_count, total_length, total_area, image_path FROM building_materials WHERE building_id = $1 ORDER BY material_name', [req.query.buildingId]);
    res.json(r.rows.map(row => ({
      id: parseInt(row.id), building_id: parseInt(row.building_id), material_name: row.material_name, length: row.length || '', pieces_count: row.pieces_count || '', total_length: row.total_length || '', total_area: row.total_area || '', image_path: row.image_path
    })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/building-materials', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query(
      'INSERT INTO building_materials (building_id, material_name, quantity, unit, length, pieces_count, total_length, total_area, image_path) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id',
      [b.buildingId, b.materialName, b.quantity || '', b.unit || '', b.length || '', b.piecesCount || '', b.totalLength || '', b.totalArea || '', b.imagePath || null]
    );
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.put('/building-materials/:id', async (req, res) => {
  try {
    const b = req.body;
    await pool.query('UPDATE building_materials SET material_name = $1, length = $2, pieces_count = $3, total_length = $4, total_area = $5, image_path = $6 WHERE id = $7', [b.materialName, b.length || '', b.piecesCount || '', b.totalLength || '', b.totalArea || '', b.imagePath || null, req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/building-materials/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM building_materials WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/building-cutlists', async (req, res) => {
  try {
    const r = await pool.query('SELECT id, building_id, image_path FROM building_cutlist_images WHERE building_id = $1', [req.query.buildingId]);
    res.json(r.rows.map(row => ({ id: parseInt(row.id), building_id: parseInt(row.building_id), image_path: row.image_path })));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.post('/building-cutlists', async (req, res) => {
  try {
    const b = req.body;
    const r = await pool.query('INSERT INTO building_cutlist_images (building_id, image_path) VALUES ($1, $2) RETURNING id', [b.buildingId, b.imagePath]);
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});
app.delete('/building-cutlists/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM building_cutlist_images WHERE id = $1', [req.params.id]);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/activity-logs', async (req, res) => {
  try {
    const requesterEmail = String(req.query.requesterEmail || '').trim().toLowerCase();
    if (requesterEmail !== 'mouhammedhelal@gmail.com') {
      return res.status(403).json({ error: 'forbidden' });
    }
    const params = [];
    let i = 1;
    let sql = `
      SELECT id, created_at, action_type, action_label, endpoint, method, user_id, user_name, user_email, status_code, details
      FROM activity_logs
      WHERE 1=1
    `;
    if (req.query.dateFrom) {
      sql += ` AND created_at >= $${i}`;
      params.push(String(req.query.dateFrom));
      i++;
    }
    if (req.query.dateTo) {
      sql += ` AND created_at <= $${i}`;
      params.push(String(req.query.dateTo));
      i++;
    }
    if (req.query.userId && String(req.query.userId).trim() !== '') {
      sql += ` AND user_id = $${i}`;
      params.push(parseInt(String(req.query.userId), 10));
      i++;
    }
    if (req.query.actionType && String(req.query.actionType).trim() !== '') {
      sql += ` AND action_type = $${i}`;
      params.push(String(req.query.actionType).trim());
      i++;
    }
    sql += ' ORDER BY created_at DESC, id DESC LIMIT 5000';
    const r = await pool.query(sql, params);
    res.json(
      r.rows.map((row) => ({
        id: parseInt(row.id),
        created_at: row.created_at,
        action_type: row.action_type,
        action_label: row.action_label,
        endpoint: row.endpoint,
        method: row.method,
        user_id: row.user_id != null ? parseInt(row.user_id) : null,
        user_name: row.user_name,
        user_email: row.user_email,
        status_code: parseInt(row.status_code),
        details: row.details ?? '',
      }))
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/executed-plans', async (req, res) => {
  try {
    const b = req.body || {};
    const status = String(b.status || '').trim();
    if (!['confirmed', 'confirmed_edited', 'postponed'].includes(status)) {
      return res.status(400).json({ error: 'invalid status' });
    }
    const userId = parseInt(b.userId, 10);
    if (Number.isNaN(userId)) return res.status(400).json({ error: 'invalid userId' });
    const userName = String(b.userName || '').trim();
    if (!userName) return res.status(400).json({ error: 'userName required' });
    const planDate = String(b.planDate || '').trim();
    if (!planDate) return res.status(400).json({ error: 'planDate required' });
    const planJson = JSON.stringify(b.plan || {});
    const sourcePlanId = b.sourcePlanId != null ? parseInt(b.sourcePlanId, 10) : null;
    const projectId = b.projectId != null ? parseInt(b.projectId, 10) : null;
    const projectName = b.projectName != null ? String(b.projectName) : null;
    const modificationSummary = b.modificationSummary != null ? String(b.modificationSummary) : null;
    let postponeReasonKey = b.postponeReasonKey != null ? String(b.postponeReasonKey).trim() : null;
    let postponeReasonLabel = b.postponeReasonLabel != null ? String(b.postponeReasonLabel).trim() : null;
    let postponeCustomReason = b.postponeCustomReason != null ? String(b.postponeCustomReason).trim() : null;
    let postponeNotes = b.postponeNotes != null ? String(b.postponeNotes).trim() : null;
    let postponeReopenDate = b.postponeReopenDate != null ? String(b.postponeReopenDate).trim() : null;
    let engineerFineTarget =
      b.engineerFineTarget != null ? String(b.engineerFineTarget).trim().toLowerCase() : null;
    if (b.engineer_fine_target != null && engineerFineTarget == null) {
      engineerFineTarget = String(b.engineer_fine_target).trim().toLowerCase();
    }
    const allowedFine = new Set(['owner', 'contractor', 'none']);
    if (status === 'postponed') {
      if (!postponeReasonKey) {
        return res.status(400).json({ error: 'postponeReasonKey required for postponed status' });
      }
      if (!postponeReopenDate) {
        return res.status(400).json({ error: 'postponeReopenDate required for postponed status' });
      }
      if (!engineerFineTarget || !allowedFine.has(engineerFineTarget)) {
        return res.status(400).json({ error: 'engineerFineTarget required (owner|contractor|none)' });
      }
      if (postponeReasonKey === 'other' && (!postponeCustomReason || postponeCustomReason.trim() === '')) {
        return res.status(400).json({ error: 'custom reason required when postponeReasonKey is other' });
      }
      if (postponeReasonKey === 'other' && postponeCustomReason) {
        const normalized = postponeCustomReason.trim();
        const customKey = `custom:${normalized.toLowerCase()}`;
        await pool.query(
          `INSERT INTO postpone_reasons (reason_key, label, requires_custom, is_system, created_at)
           VALUES ($1,$2,FALSE,FALSE,$3)
           ON CONFLICT (reason_key) DO NOTHING`,
          [customKey, normalized, new Date().toISOString()]
        );
      }
    } else {
      postponeReasonKey = null;
      postponeReasonLabel = null;
      postponeCustomReason = null;
      postponeNotes = null;
      postponeReopenDate = null;
      engineerFineTarget = null;
    }
    const createdAt = new Date().toISOString();
    const r = await pool.query(
      `INSERT INTO executed_plans
      (source_plan_id, user_id, user_name, project_id, project_name, plan_date, status, modification_summary, postpone_reason_key, postpone_reason_label, postpone_custom_reason, postpone_notes, postpone_reopen_date, engineer_fine_target, plan_json, created_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
      RETURNING id`,
      [
        Number.isNaN(sourcePlanId) ? null : sourcePlanId,
        userId,
        userName,
        Number.isNaN(projectId) ? null : projectId,
        projectName,
        planDate,
        status,
        modificationSummary,
        postponeReasonKey,
        postponeReasonLabel,
        postponeCustomReason,
        postponeNotes,
        postponeReopenDate,
        engineerFineTarget,
        planJson,
        createdAt,
      ]
    );
    if (status === 'postponed') {
      const displayProject = String(projectName || '').trim() || 'غير محدد';
      const reasonText =
        (postponeCustomReason && postponeCustomReason.trim()) ||
        (postponeReasonLabel && postponeReasonLabel.trim()) ||
        postponeReasonKey ||
        'غير محدد';
      const reopenDay = postponeReopenDate ? String(postponeReopenDate).slice(0, 10) : '';
      const fineSuggestion =
        engineerFineTarget === 'owner'
          ? 'المالك'
          : engineerFineTarget === 'contractor'
            ? 'المقاول'
            : 'لا تستدعي غرامة';
      const notesLine =
        postponeNotes && postponeNotes.trim() !== ''
          ? `\nملاحظات المهندس: ${postponeNotes.trim()}`
          : '';
      const execId = parseInt(r.rows[0].id, 10);
      const body =
        `المشروع: ${displayProject}\n` +
        `المهندس: ${userName}\n` +
        `تاريخ الخطة: ${String(planDate).slice(0, 10)}\n` +
        `سبب التأجيل: ${reasonText}\n` +
        `تاريخ إعادة فتح الخطة: ${reopenDay}${notesLine}\n` +
        `اقتراح توقيع غرامة (من المهندس): ${fineSuggestion}\n` +
        `رقم المرجع: ${execId}`;
      await withdrawalInsertNotificationsForRoles(pool, ['site_engineer_manager'], {
        title: 'تأجيل خطة عمل اليوم — يتطلب قرار الغرامة',
        body,
        eventType: 'work_plan_postponed',
        actorUserId: userId,
        actorUserName: userName,
        projectName: projectName,
      });
      await notifyAppAdminsIfSiteEngineer(pool, userId, {
        title: 'تأجيل خطة عمل اليوم',
        body,
        eventType: 'work_plan_postponed',
        actorUserId: userId,
        actorUserName: userName,
        projectName: projectName,
      });
    } else if (status === 'confirmed') {
      const displayProject = String(projectName || '').trim() || 'غير محدد';
      await notifyAppAdminsIfSiteEngineer(pool, userId, {
        title: 'تأكيد تنفيذ خطة اليوم',
        body:
          `قام "${userName}" بتأكيد تنفيذ خطة اليوم — مشروع "${displayProject}"\n` +
          `تاريخ الخطة: ${formatDateYmd(planDate)}`,
        eventType: 'work_plan_confirmed',
        actorUserId: userId,
        actorUserName: userName,
        projectName: projectName,
      });
    } else if (status === 'confirmed_edited') {
      const displayProject = String(projectName || '').trim() || 'غير محدد';
      const modLine =
        modificationSummary && String(modificationSummary).trim() !== ''
          ? `\nملخص التعديل: ${String(modificationSummary).trim()}`
          : '';
      await notifyAppAdminsIfSiteEngineer(pool, userId, {
        title: 'تعديل وتنفيذ خطة اليوم',
        body:
          `قام "${userName}" بتعديل خطة اليوم وتنفيذها — مشروع "${displayProject}"\n` +
          `تاريخ الخطة: ${formatDateYmd(planDate)}${modLine}`,
        eventType: 'work_plan_confirmed_edited',
        actorUserId: userId,
        actorUserName: userName,
        projectName: projectName,
      });
    }
    res.json(parseInt(r.rows[0].id));
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/executed-plans/pending-sem-fine-actions', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId || ''), 10);
    if (Number.isNaN(userId)) return res.status(400).json({ error: 'userId required' });
    const u = await pool.query('SELECT role FROM users WHERE id = $1', [userId]);
    if (u.rows.length === 0 || String(u.rows[0].role) !== 'site_engineer_manager') {
      return res.json([]);
    }
    const r = await pool.query(
      `SELECT id, user_id, user_name, project_id, project_name, plan_date, status,
              postpone_reason_key, postpone_reason_label, postpone_custom_reason, postpone_notes, postpone_reopen_date,
              engineer_fine_target, created_at
       FROM executed_plans
       WHERE status = 'postponed' AND sem_resolved_at IS NULL
       ORDER BY created_at DESC, id DESC`
    );
    res.json(
      r.rows.map((row) => ({
        id: parseInt(row.id, 10),
        user_id: parseInt(row.user_id, 10),
        user_name: row.user_name,
        project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
        project_name: row.project_name,
        plan_date: row.plan_date,
        postpone_reason_key: row.postpone_reason_key,
        postpone_reason_label: row.postpone_reason_label,
        postpone_custom_reason: row.postpone_custom_reason,
        postpone_notes: row.postpone_notes,
        postpone_reopen_date: row.postpone_reopen_date,
        engineer_fine_target: row.engineer_fine_target,
        created_at: row.created_at,
      }))
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

async function assertPostponeFinesReportAccess(actorUserId) {
  const r = await pool.query(
    `SELECT role, lower(trim(email::text)) AS email FROM users WHERE id = $1`,
    [actorUserId]
  );
  if (!r.rows.length) return false;
  const role = String(r.rows[0].role || '');
  const email = String(r.rows[0].email || '');
  if (role === 'operation_manager') return true;
  if (role === 'app_admin' && email === PRIMARY_APP_ADMIN_EMAIL) return true;
  return false;
}

function contractorIdsFromExecutedPlanJson(planJsonStr) {
  try {
    const j = JSON.parse(planJsonStr || '{}');
    const lines = Array.isArray(j.lines) ? j.lines : [];
    const ids = new Set();
    for (const line of lines) {
      const cid = line.contractorId ?? line.contractor_id;
      if (cid == null || cid === '') continue;
      const n = parseInt(String(cid), 10);
      if (!Number.isNaN(n)) ids.add(n);
    }
    return [...ids];
  } catch (_) {
    return [];
  }
}

app.get('/executed-plans/postpone-fines-report', async (req, res) => {
  try {
    const actorUserId = parseInt(String(req.query.actorUserId || ''), 10);
    if (Number.isNaN(actorUserId)) return res.status(400).json({ error: 'actorUserId required' });
    const allowed = await assertPostponeFinesReportAccess(actorUserId);
    if (!allowed) return res.status(403).json({ error: 'forbidden' });

    const dateFrom = String(req.query.dateFrom || '').trim().slice(0, 10);
    const dateTo = String(req.query.dateTo || '').trim().slice(0, 10);
    if (!dateFrom || !dateTo || dateFrom.length < 10 || dateTo.length < 10) {
      return res.status(400).json({ error: 'dateFrom and dateTo required (YYYY-MM-DD)' });
    }

    let engineerUserId = null;
    if (req.query.engineerUserId != null && String(req.query.engineerUserId).trim() !== '') {
      engineerUserId = parseInt(String(req.query.engineerUserId), 10);
      if (Number.isNaN(engineerUserId)) return res.status(400).json({ error: 'invalid engineerUserId' });
    }
    let projectId = null;
    if (req.query.projectId != null && String(req.query.projectId).trim() !== '') {
      projectId = parseInt(String(req.query.projectId), 10);
      if (Number.isNaN(projectId)) return res.status(400).json({ error: 'invalid projectId' });
    }
    let contractorFilter = null;
    if (req.query.contractorId != null && String(req.query.contractorId).trim() !== '') {
      contractorFilter = parseInt(String(req.query.contractorId), 10);
      if (Number.isNaN(contractorFilter)) return res.status(400).json({ error: 'invalid contractorId' });
    }
    let reasonKey = null;
    if (req.query.reasonKey != null && String(req.query.reasonKey).trim() !== '') {
      reasonKey = String(req.query.reasonKey).trim();
    }

    const params = [dateFrom, dateTo];
    let sql = `
      SELECT ep.id, ep.user_id, ep.user_name, ep.project_id, ep.project_name, ep.plan_date,
        ep.postpone_reason_key, ep.postpone_reason_label, ep.postpone_custom_reason, ep.postpone_notes, ep.postpone_reopen_date,
        ep.engineer_fine_target, ep.sem_fine_target, ep.sem_fine_amount, ep.sem_no_fine_reason, ep.sem_resolved_at,
        ep.plan_json
      FROM executed_plans ep
      WHERE ep.status = 'postponed'
        AND left(trim(ep.plan_date), 10) >= $1
        AND left(trim(ep.plan_date), 10) <= $2
    `;
    let i = 3;
    if (engineerUserId != null) {
      sql += ` AND ep.user_id = $${i}`;
      params.push(engineerUserId);
      i++;
    }
    if (projectId != null) {
      sql += ` AND ep.project_id = $${i}`;
      params.push(projectId);
      i++;
    }
    if (reasonKey != null) {
      sql += ` AND ep.postpone_reason_key = $${i}`;
      params.push(reasonKey);
      i++;
    }
    sql += ' ORDER BY left(trim(ep.plan_date), 10) DESC, ep.id DESC';

    const er = await pool.query(sql, params);
    const contractorsRes = await pool.query('SELECT id, name FROM contractors');
    const contractorById = new Map(
      contractorsRes.rows.map((row) => [parseInt(row.id, 10), String(row.name || '').trim()])
    );

    const out = [];
    for (const row of er.rows) {
      const lineCids = contractorIdsFromExecutedPlanJson(row.plan_json);
      if (contractorFilter != null && !lineCids.includes(contractorFilter)) continue;

      const contractorNames = lineCids.map((id) => contractorById.get(id) || `#${id}`);
      const contractorDisplay =
        contractorNames.length === 0 ? '—' : [...new Set(contractorNames)].join('، ');

      out.push({
        id: parseInt(row.id, 10),
        user_id: parseInt(row.user_id, 10),
        user_name: row.user_name,
        project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
        project_name: row.project_name,
        plan_date: row.plan_date,
        postpone_reason_key: row.postpone_reason_key,
        postpone_reason_label: row.postpone_reason_label,
        postpone_custom_reason: row.postpone_custom_reason,
        postpone_notes: row.postpone_notes,
        postpone_reopen_date: row.postpone_reopen_date,
        engineer_fine_target: row.engineer_fine_target,
        sem_fine_target: row.sem_fine_target,
        sem_fine_amount: row.sem_fine_amount,
        sem_no_fine_reason: row.sem_no_fine_reason,
        sem_resolved_at: row.sem_resolved_at,
        contractors_in_plan_label: contractorDisplay,
      });
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.post('/executed-plans/:id/sem-fine-resolution', async (req, res) => {
  try {
    const id = parseInt(String(req.params.id || ''), 10);
    const managerUserId = parseInt(String(req.body?.managerUserId ?? req.body?.manager_user_id ?? ''), 10);
    const fineTargetRaw = String(req.body?.fineTarget ?? req.body?.fine_target ?? '').trim().toLowerCase();
    const fineAmount = req.body?.fineAmount != null ? String(req.body.fineAmount).trim() : '';
    const noFineReason = req.body?.noFineReason != null ? String(req.body.noFineReason).trim() : '';
    if (Number.isNaN(id) || Number.isNaN(managerUserId)) {
      return res.status(400).json({ error: 'invalid id or managerUserId' });
    }
    const actor = await pool.query('SELECT id, role, name FROM users WHERE id = $1', [managerUserId]);
    if (actor.rows.length === 0 || String(actor.rows[0].role) !== 'site_engineer_manager') {
      return res.status(403).json({ error: 'forbidden' });
    }
    const semName = String(actor.rows[0].name || '').trim() || 'مدير المشروعات';
    const allowed = new Set(['owner', 'contractor', 'none']);
    if (!allowed.has(fineTargetRaw)) {
      return res.status(400).json({ error: 'fineTarget must be owner|contractor|none' });
    }
    if (fineTargetRaw === 'none') {
      if (!noFineReason) return res.status(400).json({ error: 'noFineReason required when fineTarget is none' });
    } else if (!fineAmount) {
      return res.status(400).json({ error: 'fineAmount required when fineTarget is owner or contractor' });
    }
    const ep = await pool.query(
      `SELECT id, user_id, user_name, project_name, plan_date, status,
              postpone_reason_key, postpone_reason_label, postpone_custom_reason, postpone_notes, postpone_reopen_date,
              engineer_fine_target
       FROM executed_plans WHERE id = $1`,
      [id]
    );
    if (ep.rows.length === 0) return res.status(404).json({ error: 'not found' });
    const row = ep.rows[0];
    if (String(row.status) !== 'postponed') return res.status(400).json({ error: 'not_postponed' });
    const chk = await pool.query('SELECT sem_resolved_at FROM executed_plans WHERE id = $1', [id]);
    if (chk.rows.length && chk.rows[0].sem_resolved_at != null) {
      return res.status(400).json({ error: 'already_resolved' });
    }
    const now = new Date().toISOString();
    await pool.query(
      `UPDATE executed_plans SET
        sem_fine_target = $1,
        sem_fine_amount = $2,
        sem_no_fine_reason = $3,
        sem_resolved_at = $4,
        sem_resolved_by_user_id = $5
       WHERE id = $6`,
      [
        fineTargetRaw,
        fineTargetRaw === 'none' ? null : fineAmount,
        fineTargetRaw === 'none' ? noFineReason : null,
        now,
        managerUserId,
        id,
      ]
    );
    const engName = String(row.user_name || '').trim();
    const postponeReason =
      (row.postpone_custom_reason && String(row.postpone_custom_reason).trim()) ||
      (row.postpone_reason_label && String(row.postpone_reason_label).trim()) ||
      String(row.postpone_reason_key || '').trim() ||
      'غير محدد';
    const proj = String(row.project_name || '').trim() || 'غير محدد';
    let omBody = '';
    if (fineTargetRaw === 'none') {
      omBody =
        `قام "${engName}" بتأجيل العمل في مشروع "${proj}" لسبب "${postponeReason}". ` +
        `قام "${semName}" بعدم استدعاء غرامة للسبب: "${noFineReason}".`;
    } else {
      const onWhom = fineTargetRaw === 'owner' ? 'المالك' : 'المقاول';
      omBody =
        `قام "${engName}" بتأجيل العمل في مشروع "${proj}" لسبب "${postponeReason}". ` +
        `قام "${semName}" بتوقيع غرامة على "${onWhom}" بقيمة = "${fineAmount}".`;
    }
    await withdrawalInsertNotificationsForRoles(pool, ['operation_manager'], {
      title: 'تقرير تأجيل خطة عمل وقرار الغرامة',
      body: omBody,
      eventType: 'work_plan_postpone_sem_resolved',
      actorUserId: managerUserId,
      actorUserName: semName,
      projectName: row.project_name,
    });
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/executed-plans/latest', async (req, res) => {
  try {
    const sourcePlanId = parseInt(String(req.query.sourcePlanId || ''), 10);
    const userId = parseInt(String(req.query.userId || ''), 10);
    if (Number.isNaN(sourcePlanId) || Number.isNaN(userId)) {
      return res.status(400).json({ error: 'sourcePlanId and userId are required' });
    }
    const r = await pool.query(
      `SELECT id, source_plan_id, user_id, plan_date, status, modification_summary, postpone_reason_key, postpone_reason_label, postpone_custom_reason, postpone_notes, postpone_reopen_date, engineer_fine_target, created_at
       FROM executed_plans
       WHERE source_plan_id = $1 AND user_id = $2
       ORDER BY created_at DESC, id DESC
       LIMIT 1`,
      [sourcePlanId, userId]
    );
    if (r.rows.length === 0) return res.json(null);
    const row = r.rows[0];
    res.json({
      id: parseInt(row.id),
      source_plan_id: parseInt(row.source_plan_id),
      user_id: parseInt(row.user_id),
      plan_date: row.plan_date,
      status: row.status,
      modification_summary: row.modification_summary,
      postpone_reason_key: row.postpone_reason_key,
      postpone_reason_label: row.postpone_reason_label,
      postpone_custom_reason: row.postpone_custom_reason,
      postpone_notes: row.postpone_notes,
      postpone_reopen_date: row.postpone_reopen_date,
      engineer_fine_target: row.engineer_fine_target,
      created_at: row.created_at,
    });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/executed-plans/postponed-reopens', async (req, res) => {
  try {
    const userId = parseInt(String(req.query.userId || ''), 10);
    const reopenDateRaw = String(req.query.reopenDate || '').trim();
    if (Number.isNaN(userId) || !reopenDateRaw) {
      return res.status(400).json({ error: 'userId and reopenDate are required' });
    }
    const reopenDate = reopenDateRaw.slice(0, 10);
    const r = await pool.query(
      `
      WITH latest_per_source AS (
        SELECT DISTINCT ON (source_plan_id)
          id, source_plan_id, user_id, plan_date, status,
          postpone_reason_key, postpone_reason_label, postpone_custom_reason, postpone_notes, postpone_reopen_date, plan_json, created_at
        FROM executed_plans
        WHERE user_id = $1 AND source_plan_id IS NOT NULL
        ORDER BY source_plan_id, created_at DESC, id DESC
      )
      SELECT *
      FROM latest_per_source
      WHERE status = 'postponed'
        AND postpone_reopen_date IS NOT NULL
        AND substring(postpone_reopen_date from 1 for 10) = $2
      ORDER BY created_at DESC, id DESC
      `,
      [userId, reopenDate]
    );
    res.json(
      r.rows.map((row) => {
        let plan = {};
        try {
          plan = row.plan_json ? JSON.parse(row.plan_json) : {};
        } catch (_) {}
        return {
          id: parseInt(row.id),
          source_plan_id: parseInt(row.source_plan_id),
          user_id: parseInt(row.user_id),
          plan_date: row.plan_date,
          status: row.status,
          postpone_reason_key: row.postpone_reason_key,
          postpone_reason_label: row.postpone_reason_label,
          postpone_custom_reason: row.postpone_custom_reason,
          postpone_notes: row.postpone_notes,
          postpone_reopen_date: row.postpone_reopen_date,
          plan,
          created_at: row.created_at,
        };
      })
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/executed-plans/daily-summary', async (req, res) => {
  try {
    const requesterEmail = String(req.query.requesterEmail || '').trim().toLowerCase();
    if (requesterEmail !== 'mouhammedhelal@gmail.com') {
      return res.status(403).json({ error: 'forbidden' });
    }
    const dateStr = String(req.query.date || '').trim();
    const baseDate = dateStr ? new Date(dateStr) : new Date();
    if (Number.isNaN(baseDate.getTime())) return res.status(400).json({ error: 'invalid date' });
    const dayStart = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate()).toISOString();
    const dayEnd = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), 23, 59, 59, 999).toISOString();

    const r = await pool.query(
      `
      SELECT
        COUNT(DISTINCT CASE WHEN status = 'confirmed' THEN COALESCE(CAST(project_id AS TEXT), project_name, CONCAT('unknown-', id)) END) AS confirmed_projects,
        COUNT(DISTINCT CASE WHEN status = 'confirmed_edited' THEN COALESCE(CAST(project_id AS TEXT), project_name, CONCAT('unknown-', id)) END) AS confirmed_edited_projects,
        COUNT(DISTINCT CASE WHEN status = 'postponed' THEN COALESCE(CAST(project_id AS TEXT), project_name, CONCAT('unknown-', id)) END) AS postponed_projects,
        COUNT(DISTINCT COALESCE(CAST(project_id AS TEXT), project_name, CONCAT('unknown-', id))) AS total_projects
      FROM executed_plans
      WHERE created_at >= $1 AND created_at <= $2
      `,
      [dayStart, dayEnd]
    );
    const row = r.rows[0] || {};
    res.json({
      date: dayStart,
      confirmed_projects: parseInt(row.confirmed_projects || '0', 10),
      confirmed_edited_projects: parseInt(row.confirmed_edited_projects || '0', 10),
      postponed_projects: parseInt(row.postponed_projects || '0', 10),
      total_projects: parseInt(row.total_projects || '0', 10),
    });
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

// تقرير المقاول من خطط اليوم المنفذة فقط:
// المصدر الوحيد: executed_plans (confirmed / confirmed_edited) مع تجاهل postponed.
app.get('/executed-plans/contractor-report', async (req, res) => {
  try {
    const contractorName = String(req.query.contractorName || '').trim();
    const dateFromRaw = String(req.query.dateFrom || '').trim();
    const dateToRaw = String(req.query.dateTo || '').trim();
    if (!contractorName) return res.status(400).json({ error: 'contractorName required' });
    if (!dateFromRaw || !dateToRaw) return res.status(400).json({ error: 'dateFrom and dateTo required' });

    const fromDay = dateFromRaw.slice(0, 10);
    const toDay = dateToRaw.slice(0, 10);
    const isAll = contractorName === 'الجميع';

    let contractorId = null;
    const contractorsMap = new Map();
    if (isAll) {
      const allC = await pool.query('SELECT id, name FROM contractors');
      for (const row of allC.rows) {
        contractorsMap.set(parseInt(row.id, 10), String(row.name || '').trim());
      }
    } else {
      const c = await pool.query('SELECT id FROM contractors WHERE name = $1 LIMIT 1', [contractorName]);
      if (c.rows.length === 0) return res.json([]);
      contractorId = parseInt(c.rows[0].id, 10);
    }

    const rows = await pool.query(
      `SELECT id, user_id, user_name, project_id, project_name, plan_date, status, plan_json
       FROM executed_plans
       WHERE status IN ('confirmed', 'confirmed_edited')
         AND substring(plan_date from 1 for 10) >= $1
         AND substring(plan_date from 1 for 10) <= $2
       ORDER BY plan_date DESC, id DESC`,
      [fromDay, toDay]
    );

    const out = [];
    const locationsCache = new Map();
    async function getLocationsMap(projectId) {
      if (projectId == null || Number.isNaN(projectId)) return new Map();
      if (locationsCache.has(projectId)) return locationsCache.get(projectId);
      const lr = await pool.query(
        'SELECT id, parent_id, name FROM project_locations WHERE project_id = $1',
        [projectId]
      );
      const map = new Map();
      for (const l of lr.rows) {
        map.set(parseInt(l.id, 10), {
          id: parseInt(l.id, 10),
          parentId: l.parent_id != null ? parseInt(l.parent_id, 10) : null,
          name: String(l.name || '').trim(),
        });
      }
      locationsCache.set(projectId, map);
      return map;
    }

    function formatLocation(projectLocations, locationId) {
      if (locationId == null || Number.isNaN(locationId)) return '—';
      const node = projectLocations.get(locationId);
      if (!node || !node.name) return '—';
      if (node.parentId == null) return node.name;
      const parent = projectLocations.get(node.parentId);
      if (!parent || !parent.name) return node.name;
      return `${parent.name} (${node.name})`;
    }

    for (const row of rows.rows) {
      let plan = null;
      try {
        plan = row.plan_json ? JSON.parse(row.plan_json) : null;
      } catch (_) {
        plan = null;
      }
      const lines = Array.isArray(plan?.lines) ? plan.lines : [];
      const byLocation = new Map();
      for (const line of lines) {
        const cid = line?.contractorId != null ? parseInt(line.contractorId, 10) : null;
        if (cid == null || Number.isNaN(cid)) continue;
        if (isAll) {
          if (!contractorsMap.has(cid)) continue;
        } else if (cid !== contractorId) {
          continue;
        }
        const locationId = line?.locationId != null ? parseInt(line.locationId, 10) : null;
        const locKey = Number.isNaN(locationId) || locationId == null ? 'none' : String(locationId);
        const key = isAll ? `${cid}:${locKey}` : locKey;
        const craftsman = parseInt(String(line.contractorWorkersCount ?? 0), 10);
        const assistant = parseInt(String(line.selfWorkersCount ?? 0), 10);
        let workers = parseInt(String(line.workersCount ?? 0), 10);
        const craftsmanSafe = Number.isNaN(craftsman) ? 0 : craftsman;
        const assistantSafe = Number.isNaN(assistant) ? 0 : assistant;
        if (Number.isNaN(workers) || workers <= 0) {
          workers = craftsmanSafe + assistantSafe;
        }
        const prev = byLocation.get(key) || {
          contractorId: cid,
          locationId: locKey === 'none' ? null : parseInt(locKey, 10),
          craftsmanCount: 0,
          assistantCount: 0,
          workersCount: 0,
        };
        prev.craftsmanCount += craftsmanSafe;
        prev.assistantCount += assistantSafe;
        prev.workersCount += Number.isNaN(workers) ? 0 : workers;
        byLocation.set(key, prev);
      }
      if (byLocation.size === 0) continue;
      const projectId = row.project_id != null ? parseInt(row.project_id, 10) : null;
      const projectLocations = await getLocationsMap(projectId);
      for (const g of byLocation.values()) {
        if (g.workersCount <= 0 && g.craftsmanCount <= 0 && g.assistantCount <= 0) {
          continue;
        }
        out.push({
          executed_plan_id: parseInt(row.id, 10),
          project_id: projectId,
          project_name: row.project_name ?? (plan?.projectName ?? null),
          user_id: parseInt(row.user_id, 10),
          user_name: row.user_name,
          contractor_name: isAll ? (contractorsMap.get(g.contractorId) || '—') : contractorName,
          plan_date: row.plan_date,
          status: row.status,
          work_place: formatLocation(projectLocations, g.locationId),
          craftsman_count: g.craftsmanCount,
          assistant_count: g.assistantCount,
          workers_count: g.workersCount,
        });
      }
    }
    res.json(out);
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

app.get('/postpone-reasons', async (req, res) => {
  try {
    const systemOrder = [
      'site_not_ready',
      'weather',
      'contractor_absent',
      'other',
    ];
    const r = await pool.query(
      `SELECT reason_key, label, requires_custom, is_system
       FROM postpone_reasons
       WHERE is_system = TRUE AND reason_key = ANY($1::text[])`,
      [systemOrder]
    );
    const byKey = new Map(
      r.rows.map((row) => [String(row.reason_key), row]),
    );
    res.json(
      systemOrder
        .map((key) => byKey.get(key))
        .filter(Boolean)
        .map((row) => ({
          reason_key: row.reason_key,
          label: row.label,
          requires_custom: row.requires_custom === true,
          is_system: row.is_system === true,
        }))
    );
  } catch (e) {
    res.status(500).json({ error: String(e.message) });
  }
});

const PORT = parseInt(process.env.PORT || '3000', 10);
ensurePasswordColumn()
  .then(() => ensureSystemLockTable())
  .then(() => ensureHomeIconsVisibilitySetting())
  .then(() => ensureUserHomeIconOrderTable())
  .then(() => ensureAttendanceCalendarDateColumn())
  .then(() => ensureDetailedReportsTables())
  .then(() => ensureLocationMaterialsTables())
  .then(() => ensureActivityLogsTable())
  .then(() => ensureExecutedPlansTable())
  .then(() => ensurePostponeReasonsTable())
  .then(() => ensureNotificationsTable())
  .then(() => ensurePrivateChatMessagesTable())
  .then(() => ensureIrMirUploadsTable())
  .then(() => ensureMsSdTables())
  .then(() => ensureMosItpTables())
  .then(() => ensureWithdrawalRequestsTable())
  .then(() => ensureReportsSysTables())
  .then(() => ensureZ1EmaarFProjectLocationsSeeded())
  .then(() => {
    app.listen(PORT, () => console.log(`Wood & More API listening on ${PORT}`));
  })
  .catch((e) => {
    console.error('Startup failed:', e);
    process.exit(1);
  });
