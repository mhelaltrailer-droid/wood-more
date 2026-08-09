// =============================================================================
// تقريران إداريان:
//
// 1) /reports/material-withdrawals — المشاريع ومواقع العمل التي جرى سحب خامتها،
//    مع التمييز بين "طلب سحب فقط" و"تم إكمال السحب" وحالة إرفاق أذون الصرف/التسليم.
//    السحب موزّع على جدولين: `withdrawal_requests` (دورة الاعتماد) و
//    `location_withdrawal` (السحب الفعلي + المرفقات)، ولا رابط بينهما سوى
//    المفتاح الطبيعي (location_id, phase).
//
// 2) /reports/uploaded-files — كل الملفات المرفوعة حالياً (IR/MIR/MS/SD/MoS/ITP/
//    Shop-Drawing/PO/أذون السحب) مع اسم المشروع وتاريخ الرفع والمستخدم والنوع.
//    كل الملفات base64 داخل أعمدة TEXT، لذا لا تُقرأ البايتات هنا إطلاقاً —
//    يُحسب الحجم من `length()` فقط.
// =============================================================================

/// مسار الموقع الكامل داخل شجرة `project_locations` ("موقع فرعي / موقع عمل").
const WFR_LOCATION_PATH_CTE = `
  WITH RECURSIVE loc_path AS (
    SELECT id, parent_id, project_id, name::text AS path
    FROM project_locations
    WHERE parent_id IS NULL
    UNION ALL
    SELECT c.id, c.parent_id, c.project_id, (lp.path || ' / ' || c.name)::text
    FROM project_locations c
    INNER JOIN loc_path lp ON lp.id = c.parent_id
  )
`;

/// عدد عناصر مصفوفة JSON مخزّنة كنص، مع حماية من الصفوف القديمة غير الصالحة.
function wfrJsonArrayLen(column) {
  return `CASE WHEN ${column} ~ '^\\s*\\[' THEN json_array_length(${column}::json) ELSE 0 END`;
}

function wfrDay(value) {
  return String(value || '').slice(0, 10);
}

function wfrIntOrNull(value) {
  if (value === undefined || value === null || String(value).trim() === '') return null;
  const n = parseInt(String(value), 10);
  return Number.isInteger(n) ? n : null;
}

function wfrPhaseLabel(phase) {
  switch (String(phase || '').trim().toLowerCase()) {
    case 'first_fix':
      return 'التأسيس (First Fix)';
    case 'second_fix':
      return 'التشطيب (Second Fix)';
    case 'finish':
      return 'التسليم (Finish)';
    default:
      return String(phase || '—');
  }
}

const WFR_STATUS_LABELS = {
  completed: 'تم إكمال عملية السحب مع إرفاق الملفات',
  completed_no_files: 'تم إكمال عملية السحب بدون مرفقات',
  fulfilled_without_record: 'تم إغلاق الطلب دون تسجيل سحب فعلي',
  rejected: 'طلب سحب مرفوض',
  approved_pending: 'طلب سحب معتمد — بانتظار إكمال السحب',
  request_only: 'طلب سحب فقط — بانتظار الاعتماد',
};

function wfrApprovalLabel(status) {
  switch (String(status || '').trim().toLowerCase()) {
    case 'approved':
      return 'موافقة';
    case 'rejected':
      return 'رفض';
    case 'pending':
      return 'بانتظار الرد';
    default:
      return '—';
  }
}

/// يشتق حالة السحب من صف الطلب وصف السحب الفعلي معاً.
function wfrDeriveStatus(row) {
  const attachmentsCount =
    (parseInt(row.disbursement_count, 10) || 0) + (parseInt(row.delivery_count, 10) || 0);
  if (row.withdrawal_id != null) {
    return {
      status: attachmentsCount > 0 ? 'completed' : 'completed_no_files',
      is_completed: true,
      attachments_count: attachmentsCount,
    };
  }
  const overall = String(row.overall_status || '').trim().toLowerCase();
  if (overall === 'rejected') {
    return { status: 'rejected', is_completed: false, attachments_count: 0 };
  }
  if (row.fulfilled_at != null && String(row.fulfilled_at).trim() !== '') {
    return { status: 'fulfilled_without_record', is_completed: false, attachments_count: 0 };
  }
  if (overall === 'approved') {
    return { status: 'approved_pending', is_completed: false, attachments_count: 0 };
  }
  return { status: 'request_only', is_completed: false, attachments_count: 0 };
}

function wfrWithdrawalRow(row) {
  const derived = wfrDeriveStatus(row);
  const phase = row.phase || 'first_fix';
  return {
    project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
    project_name: row.project_name || '',
    location_id: row.location_id != null ? parseInt(row.location_id, 10) : null,
    location_name: row.location_name || '',
    location_path: row.location_path || row.location_name || '',
    location_type: row.location_type || '',
    phase,
    phase_label: wfrPhaseLabel(phase),
    request_id: row.request_id != null ? parseInt(row.request_id, 10) : null,
    request_created_at: row.request_created_at || null,
    engineer_user_id: row.engineer_user_id != null ? parseInt(row.engineer_user_id, 10) : null,
    engineer_user_name: row.engineer_user_name || '',
    sem_status: row.sem_status || null,
    sem_status_label: row.request_id != null ? wfrApprovalLabel(row.sem_status) : '—',
    sem_reason: row.sem_reason || null,
    om_status: row.om_status || null,
    om_status_label: row.request_id != null ? wfrApprovalLabel(row.om_status) : '—',
    om_reason: row.om_reason || null,
    overall_status: row.overall_status || null,
    fulfilled_at: row.fulfilled_at || null,
    withdrawal_id: row.withdrawal_id != null ? parseInt(row.withdrawal_id, 10) : null,
    withdrawal_created_at: row.withdrawal_created_at || null,
    withdrawal_user_id: row.withdrawal_user_id != null ? parseInt(row.withdrawal_user_id, 10) : null,
    withdrawal_user_name: row.withdrawal_user_name || '',
    disbursement_files_count: parseInt(row.disbursement_count, 10) || 0,
    delivery_files_count: parseInt(row.delivery_count, 10) || 0,
    attachments_count: derived.attachments_count,
    is_completed: derived.is_completed,
    status: derived.status,
    status_label: WFR_STATUS_LABELS[derived.status] || derived.status,
  };
}

function wfrSortByDateDesc(rows, key) {
  return rows.sort((a, b) => String(b[key] || '').localeCompare(String(a[key] || '')));
}

// ——— تقرير الملفات المرفوعة ———

/// كل مصدر يُستعلم على حدة بدل UNION واحد: الجداول تُنشأ بكسل عند الإقلاع،
/// فيتجاوز التقرير أي جدول غير موجود بدل أن يفشل بالكامل.
const WFR_FILE_KIND_LABELS = {
  IR: 'IR',
  MIR: 'MIR',
  MS: 'MS',
  SD: 'SD',
  MOS: 'MoS',
  ITP: 'ITP',
  SHOP_DRAWING: 'Shop-Drawing',
  PO: 'PO',
  DISBURSEMENT_PERMIT: 'أذن الصرف',
  DELIVERY_PERMIT: 'أذن التسليم',
};

function wfrFileRow(row) {
  const kindCode = String(row.kind_code || '').toUpperCase();
  return {
    source: row.source,
    record_id: row.record_id != null ? parseInt(row.record_id, 10) : null,
    attachment_ref: row.attachment_ref != null ? String(row.attachment_ref) : 'file',
    project_id: row.project_id != null ? parseInt(row.project_id, 10) : null,
    project_name: row.project_name || 'غير محدد',
    uploaded_at: row.uploaded_at || null,
    user_id: row.user_id != null ? parseInt(row.user_id, 10) : null,
    user_name: row.user_name || '',
    kind_code: kindCode,
    kind_label: WFR_FILE_KIND_LABELS[kindCode] || kindCode,
    file_name: row.file_name || '',
    mime_type: row.mime_type || '',
    size_bytes: parseInt(row.size_bytes, 10) || 0,
    context_label: row.context_label || '',
  };
}

/// يبني شرط الفترة + المشروع لاستعلام مصدر ملفات واحد.
function wfrFileFilters({ dateColumn, projectColumn, fromDay, toDay, projectId, startIndex }) {
  const clauses = [
    `substring(${dateColumn} from 1 for 10)::date >= $${startIndex}::date`,
    `substring(${dateColumn} from 1 for 10)::date <= $${startIndex + 1}::date`,
  ];
  const params = [fromDay, toDay];
  if (projectId != null) {
    clauses.push(`${projectColumn} = $${startIndex + 2}`);
    params.push(projectId);
  }
  return { sql: clauses.join(' AND '), params };
}

async function wfrQuerySource(pool, sql, params) {
  try {
    const r = await pool.query(sql, params);
    return r.rows;
  } catch (e) {
    // جدول غير منشأ بعد على هذه البيئة — يُتجاوز المصدر بدل إسقاط التقرير.
    if (e && (e.code === '42P01' || e.code === '42703')) return [];
    throw e;
  }
}

function registerWithdrawalFilesReportRoutes(app, pool) {
  app.get('/reports/material-withdrawals', async (req, res) => {
    try {
      const fromDay = wfrDay(req.query.dateFrom);
      const toDay = wfrDay(req.query.dateTo);
      if (!fromDay || !toDay) {
        return res.status(400).json({ error: 'dateFrom and dateTo required' });
      }
      const projectId = wfrIntOrNull(req.query.projectId);
      const engineerUserId = wfrIntOrNull(req.query.engineerUserId);

      const disbursementCount = wfrJsonArrayLen('lw.disbursement_permit_images_json');
      const deliveryCount = wfrJsonArrayLen('lw.delivery_permit_images_json');

      // صفوف مبنية على الطلبات: كل طلب سحب صف مستقل، ويُربط بالسحب الفعلي فقط
      // عند اكتماله حتى لا يرث طلبٌ مرفوض قديم مرفقات سحب لاحق.
      const requestParams = [fromDay, toDay];
      let requestSql = `
        ${WFR_LOCATION_PATH_CTE}
        SELECT
          wr.id AS request_id,
          wr.created_at AS request_created_at,
          wr.engineer_user_id,
          wr.engineer_user_name,
          wr.sem_status, wr.sem_reason,
          wr.om_status, wr.om_reason,
          wr.overall_status, wr.fulfilled_at,
          wr.phase,
          pl.id AS location_id, pl.name AS location_name, pl.type AS location_type,
          lp.path AS location_path,
          pl.project_id, p.name AS project_name,
          lw.id AS withdrawal_id,
          lw.created_at AS withdrawal_created_at,
          lw.user_id AS withdrawal_user_id,
          lw.user_name AS withdrawal_user_name,
          ${disbursementCount} AS disbursement_count,
          ${deliveryCount} AS delivery_count
        FROM withdrawal_requests wr
        INNER JOIN project_locations pl ON pl.id = wr.location_id
        INNER JOIN projects p ON p.id = pl.project_id
        LEFT JOIN loc_path lp ON lp.id = wr.location_id
        LEFT JOIN location_withdrawal lw
          ON lw.location_id = wr.location_id
         AND lw.phase = wr.phase
         AND wr.fulfilled_at IS NOT NULL
        WHERE (
          (substring(wr.created_at from 1 for 10)::date >= $1::date
           AND substring(wr.created_at from 1 for 10)::date <= $2::date)
          OR (lw.created_at IS NOT NULL
           AND substring(lw.created_at from 1 for 10)::date >= $1::date
           AND substring(lw.created_at from 1 for 10)::date <= $2::date)
        )
      `;
      if (projectId != null) {
        requestParams.push(projectId);
        requestSql += ` AND pl.project_id = $${requestParams.length}`;
      }
      if (engineerUserId != null) {
        requestParams.push(engineerUserId);
        requestSql += ` AND wr.engineer_user_id = $${requestParams.length}`;
      }

      // سحوبات فعلية بلا طلب مكتمل مقابل (سحب مباشر أو بيانات أقدم من دورة الاعتماد).
      const orphanParams = [fromDay, toDay];
      let orphanSql = `
        ${WFR_LOCATION_PATH_CTE}
        SELECT
          NULL::int AS request_id,
          NULL::text AS request_created_at,
          NULL::int AS engineer_user_id,
          ''::text AS engineer_user_name,
          NULL::text AS sem_status, NULL::text AS sem_reason,
          NULL::text AS om_status, NULL::text AS om_reason,
          NULL::text AS overall_status, NULL::text AS fulfilled_at,
          lw.phase,
          pl.id AS location_id, pl.name AS location_name, pl.type AS location_type,
          lp.path AS location_path,
          pl.project_id, p.name AS project_name,
          lw.id AS withdrawal_id,
          lw.created_at AS withdrawal_created_at,
          lw.user_id AS withdrawal_user_id,
          lw.user_name AS withdrawal_user_name,
          ${disbursementCount} AS disbursement_count,
          ${deliveryCount} AS delivery_count
        FROM location_withdrawal lw
        INNER JOIN project_locations pl ON pl.id = lw.location_id
        INNER JOIN projects p ON p.id = pl.project_id
        LEFT JOIN loc_path lp ON lp.id = lw.location_id
        WHERE substring(lw.created_at from 1 for 10)::date >= $1::date
          AND substring(lw.created_at from 1 for 10)::date <= $2::date
          AND NOT EXISTS (
            SELECT 1 FROM withdrawal_requests wr2
            WHERE wr2.location_id = lw.location_id
              AND wr2.phase = lw.phase
              AND wr2.fulfilled_at IS NOT NULL
          )
      `;
      if (projectId != null) {
        orphanParams.push(projectId);
        orphanSql += ` AND pl.project_id = $${orphanParams.length}`;
      }
      if (engineerUserId != null) {
        orphanParams.push(engineerUserId);
        orphanSql += ` AND lw.user_id = $${orphanParams.length}`;
      }

      const [requestRows, orphanRows] = await Promise.all([
        wfrQuerySource(pool, requestSql, requestParams),
        wfrQuerySource(pool, orphanSql, orphanParams),
      ]);

      const out = [...requestRows, ...orphanRows].map(wfrWithdrawalRow);
      const statusFilter = String(req.query.status || '').trim();
      const filtered =
        statusFilter === '' || statusFilter === 'all'
          ? out
          : statusFilter === 'completed'
            ? out.filter((r) => r.is_completed)
            : statusFilter === 'not_completed'
              ? out.filter((r) => !r.is_completed)
              : out.filter((r) => r.status === statusFilter);

      filtered.sort((a, b) =>
        String(b.withdrawal_created_at || b.request_created_at || '').localeCompare(
          String(a.withdrawal_created_at || a.request_created_at || ''),
        ),
      );
      res.json(filtered);
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  app.get('/reports/uploaded-files', async (req, res) => {
    try {
      const fromDay = wfrDay(req.query.dateFrom);
      const toDay = wfrDay(req.query.dateTo);
      if (!fromDay || !toDay) {
        return res.status(400).json({ error: 'dateFrom and dateTo required' });
      }
      const projectId = wfrIntOrNull(req.query.projectId);
      const kindFilter = String(req.query.kind || '').trim().toUpperCase();

      const irMirFilters = wfrFileFilters({
        dateColumn: 'u.created_at',
        projectColumn: 'u.project_id',
        fromDay,
        toDay,
        projectId,
        startIndex: 1,
      });
      const irMirSql = `
        ${WFR_LOCATION_PATH_CTE}
        SELECT
          'ir_mir'::text AS source,
          u.id AS record_id,
          'file'::text AS attachment_ref,
          u.project_id, p.name AS project_name,
          u.created_at AS uploaded_at,
          u.user_id, u.user_name,
          UPPER(u.kind) AS kind_code,
          u.file_name, u.file_mime AS mime_type,
          (length(u.file_data) * 3 / 4) AS size_bytes,
          COALESCE(NULLIF(u.mir_name, ''), lp.path, '') AS context_label
        FROM ir_mir_uploads u
        INNER JOIN projects p ON p.id = u.project_id
        LEFT JOIN loc_path lp ON lp.id = u.location_id
        WHERE ${irMirFilters.sql}
      `;

      function recordAttachmentSql({ source, recordTable, attachmentTable, joinColumn, kindExpr }) {
        const filters = wfrFileFilters({
          dateColumn: 'a.created_at',
          projectColumn: 'r.project_id',
          fromDay,
          toDay,
          projectId,
          startIndex: 1,
        });
        return {
          sql: `
            SELECT
              '${source}'::text AS source,
              a.id AS record_id,
              'file'::text AS attachment_ref,
              r.project_id, p.name AS project_name,
              a.created_at AS uploaded_at,
              r.user_id, r.user_name,
              ${kindExpr} AS kind_code,
              a.file_name, a.file_mime AS mime_type,
              (length(a.file_data) * 3 / 4) AS size_bytes,
              r.record_name AS context_label
            FROM ${attachmentTable} a
            INNER JOIN ${recordTable} r ON r.id = a.${joinColumn}
            INNER JOIN projects p ON p.id = r.project_id
            WHERE ${filters.sql}
          `,
          params: filters.params,
        };
      }

      const msSd = recordAttachmentSql({
        source: 'ms_sd',
        recordTable: 'ms_sd_records',
        attachmentTable: 'ms_sd_attachments',
        joinColumn: 'record_id',
        kindExpr: `UPPER(r.kind)`,
      });
      const mosItp = recordAttachmentSql({
        source: 'mos_itp',
        recordTable: 'mos_itp_records',
        attachmentTable: 'mos_itp_attachments',
        joinColumn: 'record_id',
        kindExpr: `UPPER(r.kind)`,
      });

      const shopFilters = wfrFileFilters({
        dateColumn: 'a.created_at',
        projectColumn: 'd.project_id',
        fromDay,
        toDay,
        projectId,
        startIndex: 1,
      });
      const shopSql = `
        SELECT
          'shop_drawing'::text AS source,
          a.id AS record_id,
          'file'::text AS attachment_ref,
          d.project_id,
          COALESCE(NULLIF(p.name, ''), NULLIF(d.project_name, ''), 'غير محدد') AS project_name,
          a.created_at AS uploaded_at,
          d.created_by_user_id AS user_id,
          d.created_by_user_name AS user_name,
          CASE WHEN d.document_type = 'po' THEN 'PO' ELSE 'SHOP_DRAWING' END AS kind_code,
          a.file_name, a.mime_type,
          a.size_bytes,
          COALESCE(d.status, '') AS context_label
        FROM shop_drawing_attachments a
        INNER JOIN shop_drawings d ON d.id = a.drawing_id
        LEFT JOIN projects p ON p.id = d.project_id
        WHERE ${shopFilters.sql}
      `;

      // أذون الصرف/التسليم: مصفوفات data URL داخل صف السحب. تُفكّك في القاعدة
      // ويُعاد الطول فقط حتى لا تعبر البايتات إلى Node.
      const permitFilters = wfrFileFilters({
        dateColumn: 'lw.created_at',
        projectColumn: 'pl.project_id',
        fromDay,
        toDay,
        projectId,
        startIndex: 1,
      });
      const permitSql = `
        ${WFR_LOCATION_PATH_CTE}
        SELECT
          'location_withdrawal'::text AS source,
          lw.id AS record_id,
          (g.key || ':' || (t.idx - 1)) AS attachment_ref,
          pl.project_id, p.name AS project_name,
          lw.created_at AS uploaded_at,
          lw.user_id, lw.user_name,
          g.kind_code,
          (g.label || ' ' || t.idx) AS file_name,
          COALESCE(NULLIF(split_part(split_part(substring(t.elem from 1 for 80), ';', 1), ':', 2), ''), 'image/jpeg') AS mime_type,
          (length(t.elem) * 3 / 4) AS size_bytes,
          COALESCE(lp.path, pl.name) AS context_label
        FROM location_withdrawal lw
        INNER JOIN project_locations pl ON pl.id = lw.location_id
        INNER JOIN projects p ON p.id = pl.project_id
        LEFT JOIN loc_path lp ON lp.id = lw.location_id
        CROSS JOIN LATERAL (
          VALUES
            ('disbursement', 'DISBURSEMENT_PERMIT', 'أذن الصرف', lw.disbursement_permit_images_json),
            ('delivery', 'DELIVERY_PERMIT', 'أذن التسليم', lw.delivery_permit_images_json)
        ) AS g(key, kind_code, label, col)
        CROSS JOIN LATERAL json_array_elements_text(
          CASE WHEN g.col ~ '^\\s*\\[' THEN g.col::json ELSE '[]'::json END
        ) WITH ORDINALITY AS t(elem, idx)
        WHERE ${permitFilters.sql}
      `;

      const [irMirRows, msSdRows, mosItpRows, shopRows, permitRows] = await Promise.all([
        wfrQuerySource(pool, irMirSql, irMirFilters.params),
        wfrQuerySource(pool, msSd.sql, msSd.params),
        wfrQuerySource(pool, mosItp.sql, mosItp.params),
        wfrQuerySource(pool, shopSql, shopFilters.params),
        wfrQuerySource(pool, permitSql, permitFilters.params),
      ]);

      let out = [...irMirRows, ...msSdRows, ...mosItpRows, ...shopRows, ...permitRows].map(
        wfrFileRow,
      );
      if (kindFilter && kindFilter !== 'ALL') {
        out = out.filter((r) => r.kind_code === kindFilter);
      }
      res.json(wfrSortByDateDesc(out, 'uploaded_at'));
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });
}

module.exports = {
  registerWithdrawalFilesReportRoutes,
};
