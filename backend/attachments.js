// =============================================================================
// واجهة موحّدة لسرد وجلب مرفقات أي موديول في التطبيق.
//
// كل الملفات في هذا النظام مخزّنة base64 داخل أعمدة TEXT، وكل موديول يخزّنها
// بشكل مختلف (جدول أبناء، أو مصفوفة JSON، أو عمود مفرد). هذه الواجهة تخفي ذلك
// الاختلاف خلف مصدر (`source`) + معرّف سجل (`recordId`) حتى يستطيع الإشعار فتح
// مرفقاته دون أن تعرف الواجهة شيئاً عن الجدول الأصلي.
//
// السرد لا يعيد بيانات الملفات إطلاقاً — فقط بيانات وصفية — والبايتات تُجلب
// لمرفق واحد عند الطلب.
// =============================================================================

const ATTACHMENT_VIEWER_ROLES = ['app_admin', 'operation_manager', 'site_engineer_manager'];

/// الحد الأقصى لحجم مرفق يُسمح بإرجاعه في استجابة JSON واحدة.
const ATTACHMENT_MAX_FETCH_BYTES = 25 * 1024 * 1024;

function attErr(status, error) {
  const e = new Error(error);
  e.status = status;
  e.code = error;
  return e;
}

function attParseId(value) {
  const n = parseInt(String(value ?? ''), 10);
  return Number.isInteger(n) ? n : null;
}

/// يفصل data URL إلى نوع MIME وحمولة base64. يقبل أيضاً base64 مجرّداً.
/// يعيد null للمحتوى غير الصالح أو غير المرمّز بـ base64 (مثل data:text/plain,...).
function attSplitDataUrl(raw, fallbackMime) {
  const s = String(raw || '').trim();
  if (!s) return null;
  if (!s.startsWith('data:')) {
    return { mime: fallbackMime || 'application/octet-stream', base64: s };
  }
  const comma = s.indexOf(',');
  if (comma < 0) return null;
  const header = s.slice('data:'.length, comma);
  if (!/;base64$/i.test(header)) return null;
  const mime = header.replace(/;base64$/i, '').split(';')[0].trim();
  return {
    mime: mime || fallbackMime || 'application/octet-stream',
    base64: s.slice(comma + 1),
  };
}

function attEstimateBytes(base64) {
  const len = String(base64 || '').length;
  return Math.floor((len * 3) / 4);
}

function attExtensionForMime(mime) {
  const m = String(mime || '').toLowerCase();
  if (m === 'image/jpeg' || m === 'image/jpg') return 'jpg';
  if (m === 'image/png') return 'png';
  if (m === 'image/gif') return 'gif';
  if (m === 'image/webp') return 'webp';
  if (m === 'application/pdf') return 'pdf';
  if (m === 'application/msword') return 'doc';
  if (m === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') return 'docx';
  if (m === 'application/vnd.ms-excel') return 'xls';
  if (m === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') return 'xlsx';
  return 'bin';
}

/// تصنيف يُملي على الواجهة كيف تعرض المرفق: صورة داخل التطبيق، أو ملف يُفتح ببرنامج النظام.
function attKindForMime(mime) {
  const m = String(mime || '').toLowerCase();
  if (m.startsWith('image/')) return 'image';
  if (m === 'application/pdf') return 'pdf';
  return 'file';
}

function attItemFromDataUrl(id, raw, { fileName, label, fallbackMime }) {
  const parsed = attSplitDataUrl(raw, fallbackMime);
  if (!parsed) return null;
  const name =
    String(fileName || '').trim() ||
    `${label || 'مرفق'}.${attExtensionForMime(parsed.mime)}`;
  return {
    id,
    file_name: name,
    mime_type: parsed.mime,
    size_bytes: attEstimateBytes(parsed.base64),
    kind: attKindForMime(parsed.mime),
    label: label || null,
    can_open: true,
  };
}

function attFileFromDataUrl(raw, { fileName, label, fallbackMime }) {
  const parsed = attSplitDataUrl(raw, fallbackMime);
  if (!parsed) throw attErr(404, 'attachment_not_found');
  const name =
    String(fileName || '').trim() ||
    `${label || 'مرفق'}.${attExtensionForMime(parsed.mime)}`;
  return { file_name: name, mime_type: parsed.mime, data_base64: parsed.base64 };
}

function attParseJsonArray(raw) {
  if (raw == null) return [];
  if (Array.isArray(raw)) return raw;
  const s = String(raw).trim();
  if (!s) return [];
  try {
    const parsed = JSON.parse(s);
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

/// مرفقات التقرير المفصل تُستخدم أيضاً كقناة جانبية لحفظ نصوص داخلية — تُستبعد من العرض.
const ATT_DETAILED_REPORT_METADATA_NAMES = new Set([
  '__executed_today_summary__',
  '__manual_work_locations__',
]);

// ——— مساعدات للمصادر المبنية على جدول أبناء ———

function attChildTableSource({ parentTable, childTable, titleColumn, titlePrefix }) {
  return {
    async list(pool, recordId) {
      const parent = await pool.query(
        `SELECT ${titleColumn} AS title FROM ${parentTable} WHERE id = $1`,
        [recordId],
      );
      if (parent.rows.length === 0) throw attErr(404, 'record_not_found');
      const r = await pool.query(
        `SELECT id, file_name, file_mime, length(file_data) AS data_len
         FROM ${childTable} WHERE record_id = $1 ORDER BY id`,
        [recordId],
      );
      return {
        title: `${titlePrefix}${parent.rows[0].title || ''}`.trim(),
        items: r.rows.map((row) => ({
          id: String(row.id),
          file_name: row.file_name,
          mime_type: row.file_mime,
          size_bytes: Math.floor(((parseInt(row.data_len, 10) || 0) * 3) / 4),
          kind: attKindForMime(row.file_mime),
          label: null,
          can_open: true,
        })),
      };
    },
    async fetch(pool, recordId, attachmentId) {
      const id = attParseId(attachmentId);
      if (id == null) throw attErr(400, 'invalid_attachment_id');
      const r = await pool.query(
        `SELECT file_name, file_mime, file_data FROM ${childTable}
         WHERE id = $1 AND record_id = $2`,
        [id, recordId],
      );
      if (r.rows.length === 0) throw attErr(404, 'attachment_not_found');
      const row = r.rows[0];
      return attFileFromDataUrl(row.file_data, {
        fileName: row.file_name,
        fallbackMime: row.file_mime,
      });
    },
  };
}

/// مصدر بعمود data URL مفرد على صف واحد.
function attSingleColumnSource({ table, column, label, nameColumn }) {
  return {
    async list(pool, recordId) {
      const cols = nameColumn ? `${column} AS data, ${nameColumn} AS title` : `${column} AS data`;
      const r = await pool.query(`SELECT ${cols} FROM ${table} WHERE id = $1`, [recordId]);
      if (r.rows.length === 0) throw attErr(404, 'record_not_found');
      const item = attItemFromDataUrl('file', r.rows[0].data, { label });
      return {
        title: nameColumn ? String(r.rows[0].title || label) : label,
        items: item ? [item] : [],
      };
    },
    async fetch(pool, recordId) {
      const r = await pool.query(`SELECT ${column} AS data FROM ${table} WHERE id = $1`, [recordId]);
      if (r.rows.length === 0) throw attErr(404, 'record_not_found');
      return attFileFromDataUrl(r.rows[0].data, { label });
    },
  };
}

// ——— مساعدات لمصفوفات JSON داخل صف واحد ———

/// يبني قائمة مرفقات من عدة مصفوفات/أعمدة داخل صف واحد، ويعيد خريطة id → data URL.
function attCollectFromRow(row, groups) {
  const items = [];
  const dataById = new Map();
  for (const group of groups) {
    const values = group.single
      ? [row[group.column]]
      : attParseJsonArray(row[group.column]);
    values.forEach((value, index) => {
      const entry = group.extract ? group.extract(value, index) : { data: value };
      if (!entry || !entry.data) return;
      const id = group.single ? group.key : `${group.key}:${index}`;
      const item = attItemFromDataUrl(id, entry.data, {
        fileName: entry.fileName,
        label: entry.label || group.label,
      });
      if (!item) return;
      items.push(item);
      dataById.set(id, { data: entry.data, fileName: entry.fileName, label: item.label });
    });
  }
  return { items, dataById };
}

function attRowGroupsSource({ table, columns, titleFor, groups }) {
  const selectCols = columns.join(', ');
  async function loadRow(pool, recordId) {
    const r = await pool.query(`SELECT ${selectCols} FROM ${table} WHERE id = $1`, [recordId]);
    if (r.rows.length === 0) throw attErr(404, 'record_not_found');
    return r.rows[0];
  }
  return {
    async list(pool, recordId) {
      const row = await loadRow(pool, recordId);
      const { items } = attCollectFromRow(row, groups);
      return { title: titleFor(row), items };
    },
    async fetch(pool, recordId, attachmentId) {
      const row = await loadRow(pool, recordId);
      const { dataById } = attCollectFromRow(row, groups);
      const entry = dataById.get(String(attachmentId));
      if (!entry) throw attErr(404, 'attachment_not_found');
      return attFileFromDataUrl(entry.data, {
        fileName: entry.fileName,
        label: entry.label,
      });
    },
  };
}

const ATTACHMENT_SOURCES = {
  ir_mir: {
    async list(pool, recordId) {
      const r = await pool.query(
        `SELECT kind, mir_name, phase, file_name, file_mime, length(file_data) AS data_len
         FROM ir_mir_uploads WHERE id = $1`,
        [recordId],
      );
      if (r.rows.length === 0) throw attErr(404, 'record_not_found');
      const row = r.rows[0];
      const kindLabel = row.kind === 'mir' ? 'MIR' : 'IR';
      const suffix = row.mir_name || row.phase || '';
      return {
        title: suffix ? `${kindLabel} — ${suffix}` : kindLabel,
        items: [
          {
            id: 'file',
            file_name: row.file_name,
            mime_type: row.file_mime,
            size_bytes: Math.floor(((parseInt(row.data_len, 10) || 0) * 3) / 4),
            kind: attKindForMime(row.file_mime),
            label: null,
            can_open: true,
          },
        ],
      };
    },
    async fetch(pool, recordId) {
      const r = await pool.query(
        'SELECT file_name, file_mime, file_data FROM ir_mir_uploads WHERE id = $1',
        [recordId],
      );
      if (r.rows.length === 0) throw attErr(404, 'record_not_found');
      const row = r.rows[0];
      return attFileFromDataUrl(row.file_data, {
        fileName: row.file_name,
        fallbackMime: row.file_mime,
      });
    },
  },

  ms_sd: attChildTableSource({
    parentTable: 'ms_sd_records',
    childTable: 'ms_sd_attachments',
    titleColumn: 'record_name',
    titlePrefix: 'MS-SD — ',
  }),

  mos_itp: attChildTableSource({
    parentTable: 'mos_itp_records',
    childTable: 'mos_itp_attachments',
    titleColumn: 'record_name',
    titlePrefix: 'MoS-ITP — ',
  }),

  reports_sys: {
    async list(pool, recordId) {
      const parent = await pool.query(
        'SELECT report_name, report_type FROM reports_sys WHERE id = $1',
        [recordId],
      );
      if (parent.rows.length === 0) throw attErr(404, 'record_not_found');
      const r = await pool.query(
        `SELECT id, file_name, mime_type, size_bytes FROM reports_sys_attachments
         WHERE report_id = $1 ORDER BY id`,
        [recordId],
      );
      return {
        title:
          String(parent.rows[0].report_name || '').trim() ||
          String(parent.rows[0].report_type || 'تقرير'),
        items: r.rows.map((row) => ({
          id: String(row.id),
          file_name: row.file_name,
          mime_type: row.mime_type,
          size_bytes: parseInt(row.size_bytes, 10) || 0,
          kind: attKindForMime(row.mime_type),
          label: null,
          can_open: true,
        })),
      };
    },
    async fetch(pool, recordId, attachmentId) {
      const id = attParseId(attachmentId);
      if (id == null) throw attErr(400, 'invalid_attachment_id');
      const r = await pool.query(
        `SELECT file_name, mime_type, data_base64 FROM reports_sys_attachments
         WHERE id = $1 AND report_id = $2`,
        [id, recordId],
      );
      if (r.rows.length === 0) throw attErr(404, 'attachment_not_found');
      const row = r.rows[0];
      return attFileFromDataUrl(row.data_base64, {
        fileName: row.file_name,
        fallbackMime: row.mime_type,
      });
    },
  },

  location_withdrawal: attRowGroupsSource({
    table: 'location_withdrawal',
    columns: ['phase', 'disbursement_permit_images_json', 'delivery_permit_images_json'],
    titleFor: (row) => `أذون سحب الخامات — مرحلة: ${row.phase || '—'}`,
    groups: [
      { key: 'disbursement', column: 'disbursement_permit_images_json', label: 'أذن الصرف' },
      { key: 'delivery', column: 'delivery_permit_images_json', label: 'أذن التسليم' },
    ],
  }),

  daily_report: attRowGroupsSource({
    table: 'daily_reports',
    columns: ['project_name', 'report_datetime', 'document_path', 'images_json', 'expenses_json'],
    titleFor: (row) =>
      `التقرير اليومي — ${row.project_name || 'غير محدد'} — ${String(row.report_datetime || '').slice(0, 10)}`,
    groups: [
      { key: 'document', column: 'document_path', label: 'مستند التقرير', single: true },
      { key: 'image', column: 'images_json', label: 'صورة التقرير' },
      {
        key: 'expense',
        column: 'expenses_json',
        label: 'صورة بند صرف',
        extract: (value) => {
          if (!value || typeof value !== 'object') return null;
          if (!value.image_path) return null;
          return {
            data: value.image_path,
            label: `بند صرف: ${String(value.description || '').trim() || '—'}`,
          };
        },
      },
    ],
  }),

  detailed_report: attRowGroupsSource({
    table: 'detailed_reports',
    columns: ['project_name', 'report_datetime', 'attachments_json', 'expenses_json'],
    titleFor: (row) =>
      `التقرير المفصل — ${row.project_name || 'غير محدد'} — ${String(row.report_datetime || '').slice(0, 10)}`,
    groups: [
      {
        key: 'attachment',
        column: 'attachments_json',
        label: 'مرفق التقرير',
        extract: (value) => {
          if (!value || typeof value !== 'object') return null;
          const name = value.name != null ? String(value.name) : null;
          if (name && ATT_DETAILED_REPORT_METADATA_NAMES.has(name)) return null;
          if (!value.data) return null;
          return { data: value.data, fileName: name };
        },
      },
      {
        key: 'expense',
        column: 'expenses_json',
        label: 'صورة بند صرف',
        extract: (value) => {
          if (!value || typeof value !== 'object') return null;
          if (!value.image_path) return null;
          return {
            data: value.image_path,
            label: `بند صرف: ${String(value.description || '').trim() || '—'}`,
          };
        },
      },
    ],
  }),

  custody: attSingleColumnSource({
    table: 'engineer_custody',
    column: 'document_path',
    label: 'مستند العهدة',
  }),

  unit: attSingleColumnSource({
    table: 'units',
    column: 'image_path',
    label: 'صورة الوحدة',
    nameColumn: 'name',
  }),

  building_material: attSingleColumnSource({
    table: 'building_materials',
    column: 'image_path',
    label: 'صورة الخامة',
    nameColumn: 'material_name',
  }),

  building_cutlist: attSingleColumnSource({
    table: 'building_cutlist_images',
    column: 'image_path',
    label: 'صورة Cutlist',
  }),

  operation_report: attRowGroupsSource({
    table: 'operation_reports',
    columns: ['report_type', 'project_name', 'images_json'],
    titleFor: (row) => `${row.report_type || 'تقرير عمليات'} — ${row.project_name || 'غير محدد'}`,
    groups: [{ key: 'image', column: 'images_json', label: 'صورة تقرير العمليات' }],
  }),

  // بنود بيان الصرف صفوف منفصلة، لكنها تُعرض كسجل واحد: كل صفوف نفس المُرسِل
  // التي حُفظت في نفس اللحظة (created_at) هي بيان واحد.
  expense_statement: {
    async list(pool, recordId) {
      const anchor = await pool.query(
        `SELECT submitter_user_id, submitter_user_name, created_at, project_name
         FROM expense_statements WHERE id = $1`,
        [recordId],
      );
      if (anchor.rows.length === 0) throw attErr(404, 'record_not_found');
      const row = anchor.rows[0];
      const r = await pool.query(
        `SELECT id, description, image_path FROM expense_statements
         WHERE submitter_user_id = $1 AND created_at = $2 AND image_path IS NOT NULL
         ORDER BY id`,
        [row.submitter_user_id, row.created_at],
      );
      const items = [];
      for (const line of r.rows) {
        const item = attItemFromDataUrl(String(line.id), line.image_path, {
          label: `بند صرف: ${String(line.description || '').trim() || '—'}`,
        });
        if (item) items.push(item);
      }
      return {
        title:
          `بيان صرف — ${row.submitter_user_name || ''}` +
          (row.project_name ? ` — مشروع "${row.project_name}"` : ''),
        items,
      };
    },
    async fetch(pool, recordId, attachmentId) {
      const id = attParseId(attachmentId);
      if (id == null) throw attErr(400, 'invalid_attachment_id');
      const anchor = await pool.query(
        'SELECT submitter_user_id, created_at FROM expense_statements WHERE id = $1',
        [recordId],
      );
      if (anchor.rows.length === 0) throw attErr(404, 'record_not_found');
      const r = await pool.query(
        `SELECT description, image_path FROM expense_statements
         WHERE id = $1 AND submitter_user_id = $2 AND created_at = $3`,
        [id, anchor.rows[0].submitter_user_id, anchor.rows[0].created_at],
      );
      if (r.rows.length === 0) throw attErr(404, 'attachment_not_found');
      return attFileFromDataUrl(r.rows[0].image_path, { label: 'إيصال صرف' });
    },
  },

  projects_dashboard: {
    async list(pool, recordId) {
      const r = await pool.query(
        `SELECT variant, file_name, file_mime, length(file_data) AS data_len
         FROM projects_dashboard_sheet WHERE id = $1`,
        [recordId],
      );
      if (r.rows.length === 0) throw attErr(404, 'record_not_found');
      const row = r.rows[0];
      return {
        title: `Projects Dashboard (${row.variant || 'webdav'})`,
        items: [
          {
            id: 'file',
            file_name: row.file_name,
            mime_type: row.file_mime,
            size_bytes: Math.floor(((parseInt(row.data_len, 10) || 0) * 3) / 4),
            kind: 'file',
            label: 'شيت المشاريع',
            can_open: true,
          },
        ],
      };
    },
    async fetch(pool, recordId) {
      const r = await pool.query(
        'SELECT file_name, file_mime, file_data FROM projects_dashboard_sheet WHERE id = $1',
        [recordId],
      );
      if (r.rows.length === 0) throw attErr(404, 'record_not_found');
      const row = r.rows[0];
      return attFileFromDataUrl(row.file_data, {
        fileName: row.file_name,
        fallbackMime: row.file_mime,
      });
    },
  },

  // نسخ APK تصل إلى 100MB، فلا تُنقل عبر JSON — يُعرض بيانها فقط ويُنزّل من شاشة الإصدارات.
  app_release: {
    async list(pool, recordId) {
      const r = await pool.query(
        'SELECT version_label, file_name, size_bytes FROM app_releases WHERE id = $1',
        [recordId],
      );
      if (r.rows.length === 0) throw attErr(404, 'record_not_found');
      const row = r.rows[0];
      return {
        title: `نسخة التطبيق ${row.version_label || ''}`.trim(),
        items: [
          {
            id: 'file',
            file_name: row.file_name,
            mime_type: 'application/vnd.android.package-archive',
            size_bytes: parseInt(row.size_bytes, 10) || 0,
            kind: 'file',
            label: 'ملف APK',
            can_open: false,
          },
        ],
      };
    },
    async fetch() {
      throw attErr(413, 'attachment_too_large_use_app_versions_screen');
    },
  },
};

async function attAssertViewer(pool, userId) {
  const id = attParseId(userId);
  if (id == null) throw attErr(400, 'userId is required');
  const r = await pool.query('SELECT role FROM users WHERE id = $1', [id]);
  if (r.rows.length === 0) throw attErr(403, 'forbidden');
  if (!ATTACHMENT_VIEWER_ROLES.includes(String(r.rows[0].role || ''))) {
    throw attErr(403, 'forbidden');
  }
}

function attResolveSource(rawSource) {
  const source = String(rawSource || '').trim();
  const descriptor = ATTACHMENT_SOURCES[source];
  if (!descriptor) throw attErr(400, 'unknown_attachment_source');
  return descriptor;
}

function attSendError(res, e) {
  const status = e && e.status ? e.status : 500;
  res.status(status).json({ error: e && e.code ? e.code : String(e.message) });
}

function registerAttachmentRoutes(app, pool) {
  app.get('/attachments', async (req, res) => {
    try {
      await attAssertViewer(pool, req.query.userId);
      const descriptor = attResolveSource(req.query.source);
      const recordId = attParseId(req.query.recordId ?? req.query.record_id);
      if (recordId == null) throw attErr(400, 'recordId is required');
      const result = await descriptor.list(pool, recordId);
      res.json({
        source: String(req.query.source),
        record_id: recordId,
        title: result.title || '',
        items: result.items || [],
      });
    } catch (e) {
      attSendError(res, e);
    }
  });

  app.get('/attachments/file', async (req, res) => {
    try {
      await attAssertViewer(pool, req.query.userId);
      const descriptor = attResolveSource(req.query.source);
      const recordId = attParseId(req.query.recordId ?? req.query.record_id);
      if (recordId == null) throw attErr(400, 'recordId is required');
      const attachmentId = String(req.query.attachmentId ?? req.query.attachment_id ?? 'file');
      const file = await descriptor.fetch(pool, recordId, attachmentId);
      if (attEstimateBytes(file.data_base64) > ATTACHMENT_MAX_FETCH_BYTES) {
        throw attErr(413, 'attachment_too_large');
      }
      res.json(file);
    } catch (e) {
      attSendError(res, e);
    }
  });
}

module.exports = {
  registerAttachmentRoutes,
  ATTACHMENT_VIEWER_ROLES,
};
