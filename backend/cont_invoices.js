/**
 * Cont-Invoices — مستخلصات المقاول (مسودات + بنود كميات/أسعار).
 * تداول: draft → pending_price → pending_pm → pending_om → approved
 *        → partially_paid → paid (دفعات خزينة بعد الاعتماد)
 */

const crypto = require('crypto');
const {
  applyViewAsToUser,
  primaryAdminPowersActiveForUser,
} = require('./view_as');
const {
  isR2Configured,
  stripBase64Payload,
  r2PutObject,
  r2GetObjectBuffer,
} = require('./lib/r2');

const CI_PAYMENT_MAX_BYTES = 10 * 1024 * 1024;
const CI_PAYMENT_MAX_FILES = 8;
const CI_PAYMENT_ALLOWED_MIME = new Set([
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'application/pdf',
]);

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

function ciNormEmail(email) {
  return String(email || '').trim().toLowerCase();
}

const CI_QS_EMAILS = new Set(['qs-user', 'qs@app.com']);
const CI_AH_AMIN_EMAIL = 'ah-amin';
const CI_PM_EMAIL = 'abdelrhmanellaithy828@gmail.com';
const CI_OM_EMAIL = 'shams';

const CI_ACTOR_AH_AMIN_ID = 15;
const CI_ACTOR_PM_ID = 12;
const CI_ACTOR_OM_ID = 11;

function ciIsPrimaryAdmin(user, req) {
  return primaryAdminPowersActiveForUser(user, req);
}

function ciIsQs(user) {
  return CI_QS_EMAILS.has(ciNormEmail(user?.email));
}

function ciIsAhAmin(user) {
  return ciNormEmail(user?.email) === CI_AH_AMIN_EMAIL;
}

function ciIsPm(user) {
  return ciNormEmail(user?.email) === CI_PM_EMAIL;
}

function ciIsOm(user) {
  return ciNormEmail(user?.email) === CI_OM_EMAIL;
}

function ciCanAccessList(user, req) {
  const role = ciStr(user?.role);
  return (
    ciIsAppAdmin(user) ||
    ciIsPrimaryAdmin(user, req) ||
    ciIsQs(user) ||
    ciIsAhAmin(user) ||
    ciIsPm(user) ||
    ciIsOm(user) ||
    role === 'qs' ||
    role === 'accountant' ||
    role === 'finance' ||
    role === 'projects_manager' ||
    role === 'operation_manager'
  );
}

function ciCanCreate(user, req) {
  return ciIsQs(user) || ciIsPrimaryAdmin(user, req);
}

function ciCanDelete(user, req) {
  return ciIsPrimaryAdmin(user, req);
}

function ciStatusLabelAr(status) {
  switch (String(status || '').trim()) {
    case 'draft':
      return 'مسودة';
    case 'pending_price':
      return 'مراجعة السعر';
    case 'pending_pm':
      return 'مراجعة مدير المشروعات';
    case 'pending_om':
      return 'اعتماد العمليات';
    case 'approved':
      return 'معتمد';
    case 'partially_paid':
      return 'صرف جزئي';
    case 'paid':
      return 'تم الصرف';
    default:
      return String(status || '');
  }
}

function ciLineEditMode(user, req, status) {
  if (ciIsPrimaryAdmin(user, req)) return 'full';
  const st = String(status || 'draft').trim();
  if (st === 'draft' && ciIsQs(user)) return 'full';
  if (st === 'pending_price' && ciIsAhAmin(user)) return 'price_only';
  if (st === 'pending_pm' && ciIsPm(user)) return 'full';
  return 'none';
}

function ciMergePriceOnlyLines(existingRows, incomingRaw) {
  const incoming = Array.isArray(incomingRaw) ? incomingRaw : [];
  const byId = new Map();
  const bySort = new Map();
  for (const raw of incoming) {
    const idRaw = raw.id;
    const id =
      idRaw == null || idRaw === ''
        ? null
        : parseInt(String(idRaw), 10);
    if (Number.isFinite(id)) byId.set(id, raw);
    const sort = parseInt(String(raw.sort_order ?? raw.sortOrder ?? ''), 10);
    if (Number.isFinite(sort)) bySort.set(sort, raw);
  }
  return existingRows.map((row, index) => {
    const id = parseInt(row.id, 10);
    const inc =
      (Number.isFinite(id) && byId.get(id)) ||
      bySort.get(parseInt(row.sort_order, 10) || index);
    if (!inc) {
      return {
        id: row.id,
        sort_order: row.sort_order,
        item_no: row.item_no,
        line_kind: row.line_kind,
        structure_location_id: row.structure_location_id,
        location_label: row.location_label,
        description: row.description,
        unit: row.unit,
        prev_qty: row.prev_qty,
        current_qty: row.current_qty,
        total_qty: row.total_qty,
        base_qty: row.base_qty,
        unit_price: row.unit_price,
        prev_percent: row.prev_percent,
        percent: row.percent,
        deduction_kind: row.deduction_kind,
        counterparty_contractor_id: row.counterparty_contractor_id,
        counterparty_contractor_name: row.counterparty_contractor_name,
      };
    }
    const newPrice = inc.unit_price ?? inc.unitPrice;
    return {
      id: row.id,
      sort_order: row.sort_order,
      item_no: row.item_no,
      line_kind: row.line_kind,
      structure_location_id: row.structure_location_id,
      location_label: row.location_label,
      description: row.description,
      unit: row.unit,
      prev_qty: row.prev_qty,
      current_qty: row.current_qty,
      total_qty: row.total_qty,
      base_qty: row.base_qty,
      unit_price: newPrice != null && newPrice !== '' ? newPrice : row.unit_price,
      prev_percent: row.prev_percent,
      percent: row.percent,
      deduction_kind: row.deduction_kind,
      counterparty_contractor_id: row.counterparty_contractor_id,
      counterparty_contractor_name: row.counterparty_contractor_name,
    };
  });
}

async function ciLoadActions(pool, invoiceId) {
  const r = await pool.query(
    `SELECT * FROM cont_invoice_actions
     WHERE invoice_id = $1
     ORDER BY created_at ASC, id ASC`,
    [invoiceId],
  );
  return r.rows.map((row) => ({
    id: parseInt(row.id, 10),
    invoice_id: parseInt(row.invoice_id, 10),
    actor_user_id:
      row.actor_user_id != null ? parseInt(row.actor_user_id, 10) : null,
    actor_user_name: row.actor_user_name || '',
    action: row.action || '',
    comment: row.comment || '',
    created_at: row.created_at,
  }));
}

async function ciLogAction(client, invoiceId, user, action, comment) {
  await client.query(
    `INSERT INTO cont_invoice_actions (
      invoice_id, actor_user_id, actor_user_name, action, comment
    ) VALUES ($1,$2,$3,$4,$5)`,
    [
      invoiceId,
      user.id != null ? parseInt(user.id, 10) : null,
      user.name || '',
      action,
      comment || '',
    ],
  );
}

async function ciAssigneeUser(pool, userId) {
  const r = await pool.query(
    'SELECT id, name FROM users WHERE id = $1',
    [userId],
  );
  const row = r.rows[0];
  if (!row) return { id: userId, name: '' };
  return { id: parseInt(row.id, 10), name: row.name || '' };
}

async function ciGetUser(pool, userId, req) {
  const r = await pool.query(
    'SELECT id, name, email, role FROM users WHERE id = $1',
    [userId],
  );
  return applyViewAsToUser(r.rows[0] || null, req);
}

const CI_LINE_KINDS = new Set([
  'execution',
  'holiday',
  'transport',
  'deduction',
  'note_on_other',
]);

function ciNormalizeKind(raw) {
  const k = ciStr(raw.line_kind ?? raw.lineKind ?? 'execution').toLowerCase();
  return CI_LINE_KINDS.has(k) ? k : 'execution';
}

function ciExecutionDue(baseQty, unitPrice, prevPercent, percent) {
  const base = ciNum(baseQty) * ciNum(unitPrice);
  const delta = Math.max(0, ciNum(percent) - ciNum(prevPercent));
  return Math.round(base * (delta / 100) * 100) / 100;
}

function ciNormalizeLine(raw, index) {
  const kind = ciNormalizeKind(raw);
  const locationLabel = ciStr(raw.location_label ?? raw.locationLabel);
  const description = ciStr(raw.description);
  const unit = ciStr(raw.unit) || (kind === 'execution' ? 'م2' : 'مقط');
  const prevQty = ciNum(raw.prev_qty ?? raw.prevQty);
  const currentQty = ciNum(raw.current_qty ?? raw.currentQty);
  const baseQtyRaw = raw.base_qty ?? raw.baseQty;
  const baseQty =
    baseQtyRaw == null || baseQtyRaw === ''
      ? prevQty + currentQty
      : ciNum(baseQtyRaw);
  const totalQty = kind === 'execution' ? baseQty : prevQty + currentQty;
  const unitPrice = ciNum(raw.unit_price ?? raw.unitPrice);
  const prevPercent = Math.min(100, Math.max(0, ciNum(raw.prev_percent ?? raw.prevPercent, 0)));
  const percentRaw = ciNum(raw.percent, kind === 'execution' ? 0 : 100);
  const percent =
    kind === 'execution'
      ? Math.min(100, Math.max(0, percentRaw))
      : percentRaw;
  const structureLocationIdRaw =
    raw.structure_location_id ?? raw.structureLocationId;
  const structureLocationId =
    structureLocationIdRaw == null || structureLocationIdRaw === ''
      ? null
      : parseInt(String(structureLocationIdRaw), 10);
  const counterpartyIdRaw =
    raw.counterparty_contractor_id ?? raw.counterpartyContractorId;
  const counterpartyContractorId =
    counterpartyIdRaw == null || counterpartyIdRaw === ''
      ? null
      : parseInt(String(counterpartyIdRaw), 10);
  const counterpartyContractorName = ciStr(
    raw.counterparty_contractor_name ?? raw.counterpartyContractorName,
  );
  const deductionKind = ciStr(raw.deduction_kind ?? raw.deductionKind);

  let lineTotal;
  if (kind === 'execution') {
    lineTotal = ciExecutionDue(baseQty, unitPrice, prevPercent, percent);
  } else if (kind === 'deduction') {
    const amt = Math.abs(ciNum(raw.amount ?? unitPrice ?? currentQty));
    lineTotal = -Math.round(amt * 100) / 100;
  } else {
    // holiday | transport | note_on_other
    // تفضيل amount إن وُجد، وإلا عدد × قيمة اليومية
    const amountRaw = raw.amount;
    let amt;
    if (amountRaw != null && amountRaw !== '') {
      amt = Math.abs(ciNum(amountRaw));
    } else if (baseQty > 0 && unitPrice > 0) {
      amt = Math.abs(baseQty * unitPrice);
    } else {
      amt = Math.abs(ciNum(unitPrice || currentQty));
    }
    lineTotal = Math.round(amt * 100) / 100;
  }

  const itemNoRaw = raw.item_no ?? raw.itemNo;
  const itemNo =
    itemNoRaw == null || itemNoRaw === ''
      ? index + 1
      : parseInt(String(itemNoRaw), 10) || index + 1;
  return {
    sort_order: index,
    item_no: itemNo,
    line_kind: kind,
    structure_location_id: Number.isFinite(structureLocationId)
      ? structureLocationId
      : null,
    location_label: locationLabel,
    description,
    unit,
    prev_qty: prevQty,
    current_qty: currentQty,
    total_qty: totalQty,
    base_qty: baseQty,
    unit_price: unitPrice,
    prev_percent: prevPercent,
    percent,
    deduction_kind: deductionKind,
    counterparty_contractor_id: Number.isFinite(counterpartyContractorId)
      ? counterpartyContractorId
      : null,
    counterparty_contractor_name: counterpartyContractorName,
    line_total: lineTotal,
  };
}

function ciRound2(n) {
  return Math.round((Number(n) + Number.EPSILON) * 100) / 100;
}

function ciPaymentAttachmentToJson(row) {
  return {
    id: row.id != null ? parseInt(row.id, 10) : null,
    payment_id:
      row.payment_id != null ? parseInt(row.payment_id, 10) : null,
    file_name: ciStr(row.file_name),
    mime_type: ciStr(row.mime_type),
    size_bytes: parseInt(String(row.size_bytes || 0), 10) || 0,
  };
}

function ciPaymentToJson(row) {
  let attachments = Array.isArray(row._attachments) ? row._attachments : [];
  if (!attachments.length && ciStr(row.file_name)) {
    attachments = [
      {
        id: null,
        payment_id: row.id,
        file_name: row.file_name,
        mime_type: row.mime_type,
        size_bytes: row.size_bytes,
      },
    ];
  }
  return {
    id: row.id != null ? parseInt(row.id, 10) : null,
    invoice_id:
      row.invoice_id != null ? parseInt(row.invoice_id, 10) : null,
    amount: ciNum(row.amount),
    note: row.note || '',
    has_attachment: attachments.length > 0,
    file_name: attachments[0] ? ciStr(attachments[0].file_name) : '',
    mime_type: attachments[0] ? ciStr(attachments[0].mime_type) : '',
    size_bytes: attachments[0]
      ? parseInt(String(attachments[0].size_bytes || 0), 10) || 0
      : 0,
    attachments: attachments.map(ciPaymentAttachmentToJson),
    created_by_user_id:
      row.created_by_user_id != null
        ? parseInt(row.created_by_user_id, 10)
        : null,
    created_by_user_name: row.created_by_user_name || '',
    created_at: row.created_at || null,
  };
}

function ciSafeFileSuffix(name) {
  const base = String(name || 'voucher').replace(/[^a-zA-Z0-9._-]+/g, '_');
  return base.slice(0, 80) || 'voucher';
}

function ciMimeFromName(name) {
  const ext = String(name || '')
    .split('.')
    .pop()
    .toLowerCase();
  if (ext === 'pdf') return 'application/pdf';
  if (ext === 'png') return 'image/png';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'jpg' || ext === 'jpeg') return 'image/jpeg';
  return '';
}

function ciReadPaymentAttachment(raw) {
  const src = raw && typeof raw === 'object' ? raw : {};
  const name = ciStr(src.file_name ?? src.fileName);
  const mime = ciStr(src.mime_type ?? src.mimeType) || ciMimeFromName(name);
  const size = parseInt(String(src.size_bytes ?? src.sizeBytes ?? '0'), 10) || 0;
  const data = String(src.data_base64 ?? src.dataBase64 ?? '').trim();
  if (!name || !data) return { error: 'attachment_required' };
  const mimeOk = CI_PAYMENT_ALLOWED_MIME.has(mime.toLowerCase());
  if (!mimeOk) return { error: 'attachment_type_not_allowed' };
  if (size <= 0 || size > CI_PAYMENT_MAX_BYTES) {
    return { error: 'attachment_too_large' };
  }
  return { ok: true, name, mime, size, data };
}

function ciReadPaymentAttachments(body) {
  const b = body && typeof body === 'object' ? body : {};
  let list = [];
  if (Array.isArray(b.attachments)) list = b.attachments;
  else if (b.attachment && typeof b.attachment === 'object') {
    list = [b.attachment];
  } else if (ciStr(b.file_name ?? b.fileName)) {
    list = [b];
  }
  if (!list.length) return { error: 'attachment_required' };
  if (list.length > CI_PAYMENT_MAX_FILES) {
    return { error: 'too_many_attachments' };
  }
  const out = [];
  for (const raw of list) {
    const one = ciReadPaymentAttachment(raw);
    if (one.error) return one;
    out.push(one);
  }
  return { ok: true, items: out };
}

async function ciStorePaymentBlob({ invoiceId, name, mime, size, dataBase64 }) {
  const rawB64 = stripBase64Payload(dataBase64);
  if (isR2Configured()) {
    const key = `cont-invoices/${invoiceId}/payments/${crypto.randomUUID()}-${ciSafeFileSuffix(name)}`;
    const body = Buffer.from(rawB64, 'base64');
    await r2PutObject({ key, body, contentType: mime });
    return {
      storage_backend: 'r2',
      storage_key: key,
      data_base64: null,
      size_bytes: size || body.length,
    };
  }
  return {
    storage_backend: 'db',
    storage_key: null,
    data_base64: rawB64,
    size_bytes: size,
  };
}

function ciRowToJson(row, lines = [], actions = null, payments = null) {
  const totalAmount = ciNum(row.total_amount);
  const previouslyPaid = ciNum(row.previously_paid);
  const otherDeductions = ciNum(row.other_deductions);
  const amountDue =
    row.amount_due != null
      ? ciNum(row.amount_due)
      : ciRound2(totalAmount - previouslyPaid - otherDeductions);
  const status = row.status || 'draft';
  const out = {
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
    status,
    status_label_ar: ciStatusLabelAr(status),
    return_reason: row.return_reason || '',
    current_assignee_user_id:
      row.current_assignee_user_id != null
        ? parseInt(row.current_assignee_user_id, 10)
        : null,
    current_assignee_user_name: row.current_assignee_user_name || '',
    approved_at: row.approved_at || null,
    paid_at: row.paid_at || null,
    paid_by_user_id:
      row.paid_by_user_id != null ? parseInt(row.paid_by_user_id, 10) : null,
    paid_by_user_name: row.paid_by_user_name || '',
    created_by_user_id:
      row.created_by_user_id != null
        ? parseInt(row.created_by_user_id, 10)
        : null,
    created_by_user_name: row.created_by_user_name || '',
    created_at: row.created_at,
    updated_at: row.updated_at,
    paid_amount: 0,
    remaining_amount: 0,
    lines: lines.map((l) => ({
      id: l.id != null ? parseInt(l.id, 10) : null,
      sort_order: parseInt(l.sort_order, 10) || 0,
      item_no: l.item_no != null ? parseInt(l.item_no, 10) : null,
      line_kind: l.line_kind || 'execution',
      structure_location_id:
        l.structure_location_id != null
          ? parseInt(l.structure_location_id, 10)
          : null,
      location_label: l.location_label || '',
      description: l.description || '',
      unit: l.unit || 'عدد',
      prev_qty: ciNum(l.prev_qty),
      current_qty: ciNum(l.current_qty),
      total_qty: ciNum(l.total_qty),
      base_qty: ciNum(l.base_qty != null ? l.base_qty : l.total_qty),
      unit_price: ciNum(l.unit_price),
      prev_percent: ciNum(l.prev_percent, 0),
      percent: ciNum(l.percent, 100),
      deduction_kind: l.deduction_kind || '',
      counterparty_contractor_id:
        l.counterparty_contractor_id != null
          ? parseInt(l.counterparty_contractor_id, 10)
          : null,
      counterparty_contractor_name: l.counterparty_contractor_name || '',
      line_total: ciNum(l.line_total),
    })),
  };
  if (actions != null) {
    out.actions = actions;
  }
  let paidAmount =
    row.paid_amount != null ? ciNum(row.paid_amount) : 0;
  if (Array.isArray(payments)) {
    paidAmount = ciRound2(
      payments.reduce((sum, p) => sum + ciNum(p.amount), 0),
    );
    out.payments = payments.map(ciPaymentToJson);
  }
  out.paid_amount = paidAmount;
  out.remaining_amount = ciRound2(Math.max(0, amountDue - paidAmount));
  return out;
}

async function ciLoadPayments(pool, invoiceId) {
  const r = await pool.query(
    `SELECT * FROM cont_invoice_payments
     WHERE invoice_id = $1
     ORDER BY created_at ASC, id ASC`,
    [invoiceId],
  );
  const ids = r.rows
    .map((row) => parseInt(row.id, 10))
    .filter((id) => Number.isFinite(id));
  const attByPay = new Map();
  if (ids.length) {
    const a = await pool.query(
      `SELECT * FROM cont_invoice_payment_attachments
       WHERE payment_id = ANY($1::int[])
       ORDER BY id ASC`,
      [ids],
    );
    for (const row of a.rows) {
      const pid = parseInt(row.payment_id, 10);
      if (!attByPay.has(pid)) attByPay.set(pid, []);
      attByPay.get(pid).push(row);
    }
  }
  return r.rows.map((row) => ({
    ...row,
    _attachments: attByPay.get(parseInt(row.id, 10)) || [],
  }));
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
        invoice_id, sort_order, item_no, line_kind, structure_location_id,
        location_label, description, unit,
        prev_qty, current_qty, total_qty, base_qty, unit_price,
        prev_percent, percent, deduction_kind,
        counterparty_contractor_id, counterparty_contractor_name, line_total
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19)`,
      [
        invoiceId,
        line.sort_order,
        line.item_no,
        line.line_kind,
        line.structure_location_id,
        line.location_label,
        line.description,
        line.unit,
        line.prev_qty,
        line.current_qty,
        line.total_qty,
        line.base_qty,
        line.unit_price,
        line.prev_percent,
        line.percent,
        line.deduction_kind,
        line.counterparty_contractor_id,
        line.counterparty_contractor_name,
        line.line_total,
      ],
    );
  }
  return Math.round(total * 100) / 100;
}

async function ciSyncStructureFromLines(client, projectId, rawLines) {
  if (!Number.isFinite(projectId)) return;
  const lines = Array.isArray(rawLines) ? rawLines : [];
  for (const raw of lines) {
    const kind = ciNormalizeKind(raw);
    if (kind !== 'execution') continue;
    const locIdRaw = raw.structure_location_id ?? raw.structureLocationId;
    const locId =
      locIdRaw == null || locIdRaw === ''
        ? null
        : parseInt(String(locIdRaw), 10);
    if (!Number.isFinite(locId)) continue;
    const baseQty = ciNum(raw.base_qty ?? raw.baseQty);
    const unitPrice = ciNum(raw.unit_price ?? raw.unitPrice);
    const measure = await client.query(
      `SELECT measure_type FROM invoice_structure_projects WHERE project_id = $1`,
      [projectId],
    );
    const measureType = measure.rows[0]?.measure_type || 'flooring';
    if (measureType === 'wpc') {
      await client.query(
        `UPDATE invoice_structure_locations
         SET unit_value = $1, updated_at = NOW()
         WHERE id = $2 AND project_id = $3`,
        [unitPrice, locId, projectId],
      );
    } else {
      await client.query(
        `UPDATE invoice_structure_locations
         SET total_meters = $1, meter_price = $2, updated_at = NOW()
         WHERE id = $3 AND project_id = $4`,
        [baseQty, unitPrice, locId, projectId],
      );
    }
  }
}

async function ciUpsertPendingFromLines(client, {
  invoiceId,
  projectId,
  beneficiaryContractorId,
  beneficiaryContractorName,
  rawLines,
}) {
  await client.query(
    `DELETE FROM cont_invoice_pending_cross
     WHERE source_invoice_id = $1 AND applied_invoice_id IS NULL`,
    [invoiceId],
  );
  const lines = Array.isArray(rawLines) ? rawLines : [];
  for (const raw of lines) {
    const kind = ciNormalizeKind(raw);
    const line = ciNormalizeLine(raw, 0);
    const amount = Math.abs(ciNum(line.line_total));
    if (!(amount > 0)) continue;

    // يوميات ملاحظات + خصم على مقاول آخر → خصم (debit) على المقاول الآخر
    if (kind === 'note_on_other' && line.counterparty_contractor_name) {
      await client.query(
        `INSERT INTO cont_invoice_pending_cross (
          project_id, source_invoice_id,
          beneficiary_contractor_id, beneficiary_contractor_name,
          target_contractor_id, target_contractor_name,
          amount, description, pending_kind
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'debit')`,
        [
          Number.isFinite(projectId) ? projectId : null,
          invoiceId,
          Number.isFinite(beneficiaryContractorId) ? beneficiaryContractorId : null,
          beneficiaryContractorName || '',
          line.counterparty_contractor_id,
          line.counterparty_contractor_name,
          amount,
          line.description ||
            `يوميات ملاحظات — خصم (من ${beneficiaryContractorName || 'مقاول'})`,
        ],
      );
      continue;
    }

    // خصم على فاتورة الحالي:
    // - مع مقاول آخر → credit له (يصرف له لاحقاً لمعالجة التقصير)
    // - بدون مقاول → unlinked لحين الربط
    if (kind === 'deduction') {
      if (line.counterparty_contractor_name) {
        await client.query(
          `INSERT INTO cont_invoice_pending_cross (
            project_id, source_invoice_id,
            beneficiary_contractor_id, beneficiary_contractor_name,
            target_contractor_id, target_contractor_name,
            amount, description, pending_kind
          ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'credit')`,
          [
            Number.isFinite(projectId) ? projectId : null,
            invoiceId,
            Number.isFinite(beneficiaryContractorId) ? beneficiaryContractorId : null,
            beneficiaryContractorName || '',
            line.counterparty_contractor_id,
            line.counterparty_contractor_name,
            amount,
            line.description ||
              `صرف خصم تقصير (من ${beneficiaryContractorName || 'مقاول'})`,
          ],
        );
      } else {
        await client.query(
          `INSERT INTO cont_invoice_pending_cross (
            project_id, source_invoice_id,
            beneficiary_contractor_id, beneficiary_contractor_name,
            target_contractor_id, target_contractor_name,
            amount, description, pending_kind
          ) VALUES ($1,$2,$3,$4,NULL,'',$5,$6,'unlinked')`,
          [
            Number.isFinite(projectId) ? projectId : null,
            invoiceId,
            Number.isFinite(beneficiaryContractorId) ? beneficiaryContractorId : null,
            beneficiaryContractorName || '',
            amount,
            line.description || 'خصم معلّق غير مربوط بمقاول',
          ],
        );
      }
    }
  }
}

async function ciApplyPendingToInvoice(client, {
  invoiceId,
  projectId,
  contractorId,
  contractorName,
  existingLines,
}) {
  const params = [];
  const where = [
    `applied_invoice_id IS NULL`,
    `pending_kind IN ('debit', 'credit')`,
  ];
  if (Number.isFinite(contractorId) && contractorName) {
    params.push(contractorId, contractorName);
    where.push(
      `(target_contractor_id = $1 OR LOWER(TRIM(target_contractor_name)) = LOWER(TRIM($2)))`,
    );
  } else if (Number.isFinite(contractorId)) {
    params.push(contractorId);
    where.push(`target_contractor_id = $1`);
  } else if (contractorName) {
    params.push(contractorName);
    where.push(`LOWER(TRIM(target_contractor_name)) = LOWER(TRIM($1))`);
  } else {
    return existingLines;
  }
  if (Number.isFinite(projectId)) {
    params.push(projectId);
    where.push(`(project_id IS NULL OR project_id = $${params.length})`);
  }
  const pending = await client.query(
    `SELECT * FROM cont_invoice_pending_cross
     WHERE ${where.join(' AND ')}
     ORDER BY id ASC`,
    params,
  );
  if (!pending.rows.length) return existingLines;

  const out = Array.isArray(existingLines) ? [...existingLines] : [];
  for (const row of pending.rows) {
    const pendingKind = String(row.pending_kind || 'debit');
    if (pendingKind === 'credit') {
      out.push({
        line_kind: 'transport',
        location_label: '',
        description: row.description || 'صرف خصم تقصير معلّق',
        unit: 'مقط',
        base_qty: 1,
        unit_price: ciNum(row.amount),
        amount: ciNum(row.amount),
        percent: 100,
        prev_percent: 0,
      });
    } else {
      out.push({
        line_kind: 'deduction',
        location_label: '',
        description: row.description || 'خصم معلّق من مقاول آخر',
        unit: 'مقط',
        base_qty: 1,
        unit_price: ciNum(row.amount),
        amount: ciNum(row.amount),
        percent: 100,
        prev_percent: 0,
        deduction_kind: 'أخرى',
      });
    }
    await client.query(
      `UPDATE cont_invoice_pending_cross
       SET applied_invoice_id = $1, applied_at = NOW()
       WHERE id = $2`,
      [invoiceId, row.id],
    );
  }
  return out;
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
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS line_kind TEXT NOT NULL DEFAULT 'execution'`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS structure_location_id INTEGER`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS base_qty NUMERIC(14,4) NOT NULL DEFAULT 0`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS prev_percent NUMERIC(8,2) NOT NULL DEFAULT 0`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS deduction_kind TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS counterparty_contractor_id INTEGER`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_lines ADD COLUMN IF NOT EXISTS counterparty_contractor_name TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_invoice_pending_cross (
      id SERIAL PRIMARY KEY,
      project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
      source_invoice_id INTEGER REFERENCES cont_invoices(id) ON DELETE CASCADE,
      beneficiary_contractor_id INTEGER,
      beneficiary_contractor_name TEXT NOT NULL DEFAULT '',
      target_contractor_id INTEGER,
      target_contractor_name TEXT NOT NULL DEFAULT '',
      amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      description TEXT NOT NULL DEFAULT '',
      pending_kind TEXT NOT NULL DEFAULT 'debit',
      applied_invoice_id INTEGER REFERENCES cont_invoices(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      applied_at TIMESTAMPTZ
    )
  `);
  await pool.query(
    `ALTER TABLE cont_invoice_pending_cross
     ADD COLUMN IF NOT EXISTS pending_kind TEXT NOT NULL DEFAULT 'debit'`,
  );
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_pending_cross_target
    ON cont_invoice_pending_cross (target_contractor_id, applied_invoice_id)
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_pending_cross_unlinked
    ON cont_invoice_pending_cross (pending_kind, applied_invoice_id)
  `);
  await pool.query(
    `ALTER TABLE cont_invoices ADD COLUMN IF NOT EXISTS return_reason TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(
    `ALTER TABLE cont_invoices ADD COLUMN IF NOT EXISTS current_assignee_user_id INTEGER`,
  );
  await pool.query(
    `ALTER TABLE cont_invoices ADD COLUMN IF NOT EXISTS current_assignee_user_name TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(
    `ALTER TABLE cont_invoices ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ`,
  );
  await pool.query(
    `ALTER TABLE cont_invoices ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ`,
  );
  await pool.query(
    `ALTER TABLE cont_invoices ADD COLUMN IF NOT EXISTS paid_by_user_id INTEGER`,
  );
  await pool.query(
    `ALTER TABLE cont_invoices ADD COLUMN IF NOT EXISTS paid_by_user_name TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_invoice_actions (
      id SERIAL PRIMARY KEY,
      invoice_id INTEGER NOT NULL REFERENCES cont_invoices(id) ON DELETE CASCADE,
      actor_user_id INTEGER,
      actor_user_name TEXT NOT NULL DEFAULT '',
      action TEXT NOT NULL DEFAULT '',
      comment TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_invoice_actions_invoice
    ON cont_invoice_actions (invoice_id, created_at ASC)
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_invoice_payments (
      id SERIAL PRIMARY KEY,
      invoice_id INTEGER NOT NULL REFERENCES cont_invoices(id) ON DELETE CASCADE,
      amount NUMERIC(14,2) NOT NULL DEFAULT 0,
      note TEXT NOT NULL DEFAULT '',
      created_by_user_id INTEGER,
      created_by_user_name TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_invoice_payments_invoice
    ON cont_invoice_payments (invoice_id, created_at ASC)
  `);
  await pool.query(
    `ALTER TABLE cont_invoice_payments ADD COLUMN IF NOT EXISTS file_name TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_payments ADD COLUMN IF NOT EXISTS mime_type TEXT NOT NULL DEFAULT ''`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_payments ADD COLUMN IF NOT EXISTS size_bytes INTEGER NOT NULL DEFAULT 0`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_payments ADD COLUMN IF NOT EXISTS data_base64 TEXT`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_payments ADD COLUMN IF NOT EXISTS storage_backend TEXT NOT NULL DEFAULT 'db'`,
  );
  await pool.query(
    `ALTER TABLE cont_invoice_payments ADD COLUMN IF NOT EXISTS storage_key TEXT`,
  );
  await pool.query(`
    CREATE TABLE IF NOT EXISTS cont_invoice_payment_attachments (
      id SERIAL PRIMARY KEY,
      payment_id INTEGER NOT NULL REFERENCES cont_invoice_payments(id) ON DELETE CASCADE,
      invoice_id INTEGER NOT NULL REFERENCES cont_invoices(id) ON DELETE CASCADE,
      file_name TEXT NOT NULL DEFAULT '',
      mime_type TEXT NOT NULL DEFAULT '',
      size_bytes INTEGER NOT NULL DEFAULT 0,
      data_base64 TEXT,
      storage_backend TEXT NOT NULL DEFAULT 'db',
      storage_key TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE INDEX IF NOT EXISTS idx_cont_payment_attachments_payment
    ON cont_invoice_payment_attachments (payment_id, id)
  `);
  await pool.query(`
    INSERT INTO cont_invoice_payment_attachments (
      payment_id, invoice_id, file_name, mime_type, size_bytes,
      data_base64, storage_backend, storage_key, created_at
    )
    SELECT
      p.id, p.invoice_id, p.file_name, p.mime_type, p.size_bytes,
      p.data_base64, COALESCE(NULLIF(p.storage_backend, ''), 'db'),
      p.storage_key, p.created_at
    FROM cont_invoice_payments p
    WHERE COALESCE(p.file_name, '') <> ''
      AND NOT EXISTS (
        SELECT 1 FROM cont_invoice_payment_attachments a
        WHERE a.payment_id = p.id
      )
  `);
  await pool.query(`
    INSERT INTO cont_invoice_payments (
      invoice_id, amount, note,
      created_by_user_id, created_by_user_name, created_at
    )
    SELECT
      i.id,
      i.amount_due,
      'ترحيل صرف سابق',
      i.paid_by_user_id,
      COALESCE(i.paid_by_user_name, ''),
      COALESCE(i.paid_at, i.updated_at, NOW())
    FROM cont_invoices i
    WHERE i.status = 'paid'
      AND i.amount_due > 0
      AND NOT EXISTS (
        SELECT 1 FROM cont_invoice_payments p WHERE p.invoice_id = i.id
      )
  `);
}

function registerContInvoicesRoutes(app, pool) {
  /**
   * آخر نسبة تنفيذ لموقع في هيكلة المستخلصات (لنفس المقاول/المشروع).
   */
  app.get('/cont-invoices/location-progress', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciCanAccessList(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }

      const projectId = parseInt(String(req.query.projectId || ''), 10);
      const structureLocationId = parseInt(
        String(req.query.structureLocationId || ''),
        10,
      );
      const contractorIdRaw = req.query.contractorId;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const contractorName = ciStr(req.query.contractorName);
      const excludeIdRaw = req.query.excludeId;
      const excludeId =
        excludeIdRaw == null || excludeIdRaw === ''
          ? null
          : parseInt(String(excludeIdRaw), 10);

      if (!Number.isFinite(projectId) || !Number.isFinite(structureLocationId)) {
        return res.status(400).json({
          error: 'projectId and structureLocationId required',
        });
      }

      const params = [projectId, structureLocationId];
      let sql = `
        SELECT l.percent, l.prev_percent, l.base_qty, l.unit_price, l.line_total,
               i.id AS invoice_id, i.statement_date
        FROM cont_invoice_lines l
        INNER JOIN cont_invoices i ON i.id = l.invoice_id
        WHERE i.project_id = $1
          AND l.structure_location_id = $2
          AND l.line_kind = 'execution'`;
      if (Number.isFinite(contractorId) && contractorName) {
        params.push(contractorId, contractorName);
        sql += ` AND (i.contractor_id = $3 OR LOWER(TRIM(i.contractor_name)) = LOWER(TRIM($4)))`;
      } else if (Number.isFinite(contractorId)) {
        params.push(contractorId);
        sql += ` AND i.contractor_id = $3`;
      } else if (contractorName) {
        params.push(contractorName);
        sql += ` AND LOWER(TRIM(i.contractor_name)) = LOWER(TRIM($3))`;
      }
      if (Number.isFinite(excludeId)) {
        params.push(excludeId);
        sql += ` AND i.id <> $${params.length}`;
      }
      sql += `
        ORDER BY COALESCE(i.statement_date, i.created_at::date) DESC, i.id DESC, l.id DESC
        LIMIT 1`;

      const r = await pool.query(sql, params);
      if (!r.rows.length) {
        return res.json({
          has_previous: false,
          prev_percent: 0,
          base_qty: null,
          unit_price: null,
        });
      }
      const row = r.rows[0];
      return res.json({
        has_previous: true,
        prev_percent: ciNum(row.percent),
        base_qty: ciNum(row.base_qty),
        unit_price: ciNum(row.unit_price),
        from_invoice_id: parseInt(row.invoice_id, 10),
      });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /** خصومات معلّقة غير مربوطة بمقاول (Admin) */
  app.get('/cont-invoices/pending-unlinked', async (req, res) => {
    try {
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(userId)) {
        return res.status(400).json({ error: 'userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const r = await pool.query(
        `SELECT p.*,
                i.project_name AS source_project_name,
                i.statement_date AS source_statement_date
         FROM cont_invoice_pending_cross p
         LEFT JOIN cont_invoices i ON i.id = p.source_invoice_id
         WHERE p.pending_kind = 'unlinked'
           AND p.applied_invoice_id IS NULL
         ORDER BY p.created_at DESC, p.id DESC`,
      );
      res.json(
        r.rows.map((row) => ({
          id: parseInt(row.id, 10),
          project_id:
            row.project_id != null ? parseInt(row.project_id, 10) : null,
          source_invoice_id:
            row.source_invoice_id != null
              ? parseInt(row.source_invoice_id, 10)
              : null,
          source_project_name: row.source_project_name || '',
          source_statement_date: row.source_statement_date
            ? String(row.source_statement_date).slice(0, 10)
            : null,
          beneficiary_contractor_id:
            row.beneficiary_contractor_id != null
              ? parseInt(row.beneficiary_contractor_id, 10)
              : null,
          beneficiary_contractor_name: row.beneficiary_contractor_name || '',
          amount: ciNum(row.amount),
          description: row.description || '',
          pending_kind: row.pending_kind || 'unlinked',
          created_at: row.created_at,
        })),
      );
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

  /** ربط خصم معلّق غير مربوط بمقاول (يصبح credit له) */
  app.post('/cont-invoices/pending-unlinked/:id/assign', async (req, res) => {
    try {
      const userId = parseInt(String(req.body?.userId ?? req.query.userId ?? ''), 10);
      const id = parseInt(String(req.params.id || ''), 10);
      if (Number.isNaN(userId) || Number.isNaN(id)) {
        return res.status(400).json({ error: 'userId and id required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciIsAppAdmin(user)) return res.status(403).json({ error: 'forbidden' });

      const contractorIdRaw =
        req.body?.contractorId ?? req.body?.contractor_id;
      const contractorId =
        contractorIdRaw == null || contractorIdRaw === ''
          ? null
          : parseInt(String(contractorIdRaw), 10);
      const contractorName = ciStr(
        req.body?.contractorName ?? req.body?.contractor_name,
      );
      if (!Number.isFinite(contractorId) && !contractorName) {
        return res.status(400).json({ error: 'contractor required' });
      }

      const existing = await pool.query(
        `SELECT id FROM cont_invoice_pending_cross
         WHERE id = $1 AND pending_kind = 'unlinked' AND applied_invoice_id IS NULL`,
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }

      await pool.query(
        `UPDATE cont_invoice_pending_cross
         SET pending_kind = 'credit',
             target_contractor_id = $1,
             target_contractor_name = $2
         WHERE id = $3`,
        [
          Number.isFinite(contractorId) ? contractorId : null,
          contractorName,
          id,
        ],
      );
      res.json({ ok: true });
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
    }
  });

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
      if (!ciCanAccessList(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }

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
      if (!ciCanAccessList(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }

      const r = await pool.query(
        `SELECT i.*, COALESCE(pay.paid_amount, 0) AS paid_amount
         FROM cont_invoices i
         LEFT JOIN (
           SELECT invoice_id, SUM(amount)::numeric(14,2) AS paid_amount
           FROM cont_invoice_payments
           GROUP BY invoice_id
         ) pay ON pay.invoice_id = i.id
         ORDER BY i.updated_at DESC, i.id DESC`,
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
      if (!ciCanAccessList(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }

      const r = await pool.query('SELECT * FROM cont_invoices WHERE id = $1', [
        id,
      ]);
      if (!r.rows.length) return res.status(404).json({ error: 'not found' });
      const lines = await ciLoadLines(pool, id);
      const actions = await ciLoadActions(pool, id);
      const payments = await ciLoadPayments(pool, id);
      res.json(ciRowToJson(r.rows[0], lines, actions, payments));
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
      if (!ciCanCreate(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
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
      const ins = await client.query(
        `INSERT INTO cont_invoices (
          contractor_id, contractor_name, project_id, project_name,
          statement_date, contract_type, previously_paid, other_deductions,
          notes, status, created_by_user_id, created_by_user_name,
          current_assignee_user_id, current_assignee_user_name
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'draft',$10,$11,NULL,'')
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
      let linesPayload = b.lines || [];
      linesPayload = await ciApplyPendingToInvoice(client, {
        invoiceId,
        projectId: Number.isFinite(projectId) ? projectId : null,
        contractorId: Number.isFinite(contractorId) ? contractorId : null,
        contractorName,
        existingLines: linesPayload,
      });
      const totalAmount = await ciReplaceLines(client, invoiceId, linesPayload);
      await ciSyncStructureFromLines(
        client,
        Number.isFinite(projectId) ? projectId : null,
        linesPayload,
      );
      await ciUpsertPendingFromLines(client, {
        invoiceId,
        projectId: Number.isFinite(projectId) ? projectId : null,
        beneficiaryContractorId: Number.isFinite(contractorId)
          ? contractorId
          : null,
        beneficiaryContractorName: contractorName,
        rawLines: linesPayload,
      });
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
      await ciLogAction(client, invoiceId, user, 'create', '');
      await client.query('COMMIT');
      const lines = await ciLoadLines(pool, invoiceId);
      const actions = await ciLoadActions(pool, invoiceId);
      res.status(201).json(ciRowToJson(upd.rows[0], lines, actions));
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

      const existing = await pool.query(
        'SELECT * FROM cont_invoices WHERE id = $1',
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }
      const invRow = existing.rows[0];
      const editMode = ciLineEditMode(user, req, invRow.status);
      if (editMode === 'none') {
        return res.status(403).json({ error: 'forbidden' });
      }

      let contractorName = ciStr(invRow.contractor_name);
      let projectName = ciStr(invRow.project_name);
      let contractorId =
        invRow.contractor_id != null
          ? parseInt(invRow.contractor_id, 10)
          : null;
      let projectId =
        invRow.project_id != null ? parseInt(invRow.project_id, 10) : null;
      let statementDate = invRow.statement_date
        ? String(invRow.statement_date).slice(0, 10)
        : null;
      let contractType = invRow.contract_type || 'تركيب';
      let previouslyPaid = ciNum(invRow.previously_paid);
      let otherDeductions = ciNum(invRow.other_deductions);
      let notes = ciStr(invRow.notes);

      if (editMode === 'full') {
        contractorName = ciStr(b.contractor_name ?? b.contractorName);
        projectName = ciStr(b.project_name ?? b.projectName);
        if (!contractorName) {
          return res.status(400).json({ error: 'contractor_name required' });
        }
        if (!projectName) {
          return res.status(400).json({ error: 'project_name required' });
        }
        const contractorIdRaw = b.contractor_id ?? b.contractorId;
        const projectIdRaw = b.project_id ?? b.projectId;
        contractorId =
          contractorIdRaw == null || contractorIdRaw === ''
            ? null
            : parseInt(String(contractorIdRaw), 10);
        projectId =
          projectIdRaw == null || projectIdRaw === ''
            ? null
            : parseInt(String(projectIdRaw), 10);
        statementDate = ciStr(b.statement_date ?? b.statementDate) || null;
        contractType = ciStr(b.contract_type ?? b.contractType) || 'تركيب';
        previouslyPaid = ciNum(b.previously_paid ?? b.previouslyPaid);
        otherDeductions = ciNum(b.other_deductions ?? b.otherDeductions);
        notes = ciStr(b.notes);
      }

      let linesPayload = b.lines || [];
      if (editMode === 'price_only') {
        const dbLines = await ciLoadLines(pool, id);
        linesPayload = ciMergePriceOnlyLines(dbLines, linesPayload);
      }

      await client.query('BEGIN');
      if (editMode === 'full') {
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
      } else {
        await client.query(
          `UPDATE cont_invoices SET updated_at = NOW() WHERE id = $1`,
          [id],
        );
      }
      const totalAmount = await ciReplaceLines(client, id, linesPayload);
      await ciSyncStructureFromLines(
        client,
        Number.isFinite(projectId) ? projectId : null,
        linesPayload,
      );
      await ciUpsertPendingFromLines(client, {
        invoiceId: id,
        projectId: Number.isFinite(projectId) ? projectId : null,
        beneficiaryContractorId: Number.isFinite(contractorId)
          ? contractorId
          : null,
        beneficiaryContractorName: contractorName,
        rawLines: linesPayload,
      });
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
      await ciLogAction(
        client,
        id,
        user,
        editMode === 'price_only' ? 'update_prices' : 'update',
        '',
      );
      await client.query('COMMIT');
      const lines = await ciLoadLines(pool, id);
      const actions = await ciLoadActions(pool, id);
      res.json(ciRowToJson(upd.rows[0], lines, actions));
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  async function ciWorkflowRespond(pool, invoiceId, res) {
    const r = await pool.query('SELECT * FROM cont_invoices WHERE id = $1', [
      invoiceId,
    ]);
    if (!r.rows.length) {
      res.status(404).json({ error: 'not found' });
      return;
    }
    const lines = await ciLoadLines(pool, invoiceId);
    const actions = await ciLoadActions(pool, invoiceId);
    const payments = await ciLoadPayments(pool, invoiceId);
    res.json(ciRowToJson(r.rows[0], lines, actions, payments));
  }

  app.post('/cont-invoices/:id/submit', async (req, res) => {
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
      if (!ciIsQs(user) && !ciIsPrimaryAdmin(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      const comment = ciStr(b.comment ?? b.notes);
      const existing = await pool.query(
        'SELECT id, status FROM cont_invoices WHERE id = $1',
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }
      if (String(existing.rows[0].status) !== 'draft') {
        return res.status(400).json({ error: 'invalid_status' });
      }
      const assignee = await ciAssigneeUser(pool, CI_ACTOR_AH_AMIN_ID);
      await client.query('BEGIN');
      await client.query(
        `UPDATE cont_invoices SET
          status = 'pending_price',
          return_reason = '',
          current_assignee_user_id = $1,
          current_assignee_user_name = $2,
          updated_at = NOW()
         WHERE id = $3`,
        [assignee.id, assignee.name, id],
      );
      await ciLogAction(client, id, user, 'submit', comment);
      await client.query('COMMIT');
      await ciWorkflowRespond(pool, id, res);
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  app.post('/cont-invoices/:id/forward', async (req, res) => {
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
      const comment = ciStr(b.comment ?? b.notes);
      const existing = await pool.query(
        'SELECT id, status FROM cont_invoices WHERE id = $1',
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }
      const status = String(existing.rows[0].status);
      let newStatus;
      let assigneeId;
      if (status === 'pending_price') {
        if (!ciIsAhAmin(user) && !ciIsPrimaryAdmin(user, req)) {
          return res.status(403).json({ error: 'forbidden' });
        }
        newStatus = 'pending_pm';
        assigneeId = CI_ACTOR_PM_ID;
      } else if (status === 'pending_pm') {
        if (!ciIsPm(user) && !ciIsPrimaryAdmin(user, req)) {
          return res.status(403).json({ error: 'forbidden' });
        }
        newStatus = 'pending_om';
        assigneeId = CI_ACTOR_OM_ID;
      } else {
        return res.status(400).json({ error: 'invalid_status' });
      }
      const assignee = await ciAssigneeUser(pool, assigneeId);
      await client.query('BEGIN');
      await client.query(
        `UPDATE cont_invoices SET
          status = $1,
          return_reason = '',
          current_assignee_user_id = $2,
          current_assignee_user_name = $3,
          updated_at = NOW()
         WHERE id = $4`,
        [newStatus, assignee.id, assignee.name, id],
      );
      await ciLogAction(client, id, user, 'forward', comment);
      await client.query('COMMIT');
      await ciWorkflowRespond(pool, id, res);
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  app.post('/cont-invoices/:id/return', async (req, res) => {
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
      if (!ciIsOm(user) && !ciIsPrimaryAdmin(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      const comment = ciStr(b.comment ?? b.notes ?? b.return_reason);
      if (!comment) {
        return res.status(400).json({ error: 'comment_required' });
      }
      const existing = await pool.query(
        'SELECT id, status FROM cont_invoices WHERE id = $1',
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }
      if (String(existing.rows[0].status) !== 'pending_om') {
        return res.status(400).json({ error: 'invalid_status' });
      }
      const assignee = await ciAssigneeUser(pool, CI_ACTOR_PM_ID);
      await client.query('BEGIN');
      await client.query(
        `UPDATE cont_invoices SET
          status = 'pending_pm',
          return_reason = $1,
          current_assignee_user_id = $2,
          current_assignee_user_name = $3,
          updated_at = NOW()
         WHERE id = $4`,
        [comment, assignee.id, assignee.name, id],
      );
      await ciLogAction(client, id, user, 'return', comment);
      await client.query('COMMIT');
      await ciWorkflowRespond(pool, id, res);
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  app.post('/cont-invoices/:id/approve', async (req, res) => {
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
      if (!ciIsOm(user) && !ciIsPrimaryAdmin(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      const comment = ciStr(b.comment ?? b.notes);
      const existing = await pool.query(
        'SELECT id, status FROM cont_invoices WHERE id = $1',
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }
      if (String(existing.rows[0].status) !== 'pending_om') {
        return res.status(400).json({ error: 'invalid_status' });
      }
      await client.query('BEGIN');
      await client.query(
        `UPDATE cont_invoices SET
          status = 'approved',
          return_reason = '',
          current_assignee_user_id = NULL,
          current_assignee_user_name = '',
          approved_at = NOW(),
          updated_at = NOW()
         WHERE id = $1`,
        [id],
      );
      await ciLogAction(client, id, user, 'approve', comment);
      await client.query('COMMIT');
      await ciWorkflowRespond(pool, id, res);
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  app.post('/cont-invoices/:id/mark-paid', async (req, res) => {
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
      if (!ciIsAhAmin(user) && !ciIsPrimaryAdmin(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      const comment = ciStr(b.comment ?? b.notes ?? b.note);
      const existing = await pool.query(
        'SELECT id, status, amount_due FROM cont_invoices WHERE id = $1',
        [id],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: 'not found' });
      }
      const status = String(existing.rows[0].status || '');
      if (status !== 'approved' && status !== 'partially_paid') {
        return res.status(400).json({ error: 'invalid_status' });
      }
      const amountDue = ciNum(existing.rows[0].amount_due);
      const paidR = await pool.query(
        `SELECT COALESCE(SUM(amount), 0)::numeric AS paid_amount
         FROM cont_invoice_payments WHERE invoice_id = $1`,
        [id],
      );
      const alreadyPaid = ciNum(paidR.rows[0]?.paid_amount);
      const remaining = ciRound2(Math.max(0, amountDue - alreadyPaid));
      if (remaining <= 0) {
        return res.status(400).json({ error: 'already_paid' });
      }
      const amountRaw = b.amount ?? b.paid_amount ?? b.paidAmount;
      const amount =
        amountRaw == null || amountRaw === ''
          ? remaining
          : ciRound2(ciNum(amountRaw));
      if (!(amount > 0)) {
        return res.status(400).json({ error: 'amount_required' });
      }
      if (amount > remaining + 0.009) {
        return res.status(400).json({ error: 'amount_exceeds_remaining' });
      }
      const newPaid = ciRound2(alreadyPaid + amount);
      const newRemaining = ciRound2(Math.max(0, amountDue - newPaid));
      const newStatus = newRemaining <= 0.009 ? 'paid' : 'partially_paid';
      const attCheck = ciReadPaymentAttachments(b);
      if (attCheck.error) {
        return res.status(400).json({ error: attCheck.error });
      }
      const storedFiles = [];
      for (const item of attCheck.items) {
        storedFiles.push({
          meta: item,
          stored: await ciStorePaymentBlob({
            invoiceId: id,
            name: item.name,
            mime: item.mime,
            size: item.size,
            dataBase64: item.data,
          }),
        });
      }
      const first = storedFiles[0];

      await client.query('BEGIN');
      const payIns = await client.query(
        `INSERT INTO cont_invoice_payments (
          invoice_id, amount, note,
          created_by_user_id, created_by_user_name,
          file_name, mime_type, size_bytes, data_base64,
          storage_backend, storage_key
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        RETURNING id`,
        [
          id,
          amount,
          comment,
          userId,
          user.name || '',
          first.meta.name,
          first.meta.mime,
          first.stored.size_bytes,
          first.stored.data_base64,
          first.stored.storage_backend,
          first.stored.storage_key,
        ],
      );
      const paymentId = parseInt(payIns.rows[0].id, 10);
      for (const file of storedFiles) {
        await client.query(
          `INSERT INTO cont_invoice_payment_attachments (
            payment_id, invoice_id, file_name, mime_type, size_bytes,
            data_base64, storage_backend, storage_key
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            paymentId,
            id,
            file.meta.name,
            file.meta.mime,
            file.stored.size_bytes,
            file.stored.data_base64,
            file.stored.storage_backend,
            file.stored.storage_key,
          ],
        );
      }
      await client.query(
        `UPDATE cont_invoices SET
          status = $1,
          paid_at = CASE WHEN $1 = 'paid' THEN NOW() ELSE paid_at END,
          paid_by_user_id = $2,
          paid_by_user_name = $3,
          current_assignee_user_id = NULL,
          current_assignee_user_name = '',
          updated_at = NOW()
         WHERE id = $4`,
        [newStatus, userId, user.name || '', id],
      );
      await ciLogAction(
        client,
        id,
        user,
        newStatus === 'paid' ? 'mark_paid' : 'partial_pay',
        comment || String(amount),
      );
      await client.query('COMMIT');
      await ciWorkflowRespond(pool, id, res);
    } catch (e) {
      try {
        await client.query('ROLLBACK');
      } catch (_) {}
      res.status(500).json({ error: String(e.message) });
    } finally {
      client.release();
    }
  });

  async function ciSendPaymentFile(res, row) {
    if (!row || !ciStr(row.file_name)) {
      return res.status(404).json({ error: 'attachment_empty' });
    }
    let dataBase64 = '';
    if (String(row.storage_backend || 'db') === 'r2' && row.storage_key) {
      const buf = await r2GetObjectBuffer(row.storage_key);
      dataBase64 = buf.toString('base64');
    } else {
      dataBase64 = stripBase64Payload(row.data_base64 || '');
    }
    if (!dataBase64) return res.status(404).json({ error: 'attachment_empty' });
    return res.json({
      file_name: row.file_name,
      mime_type: row.mime_type || 'application/octet-stream',
      data_base64: dataBase64,
    });
  }

  app.get(
    '/cont-invoices/:id/payments/:paymentId/attachments/:attachmentId/file',
    async (req, res) => {
      try {
        const invoiceId = parseInt(String(req.params.id || ''), 10);
        const paymentId = parseInt(String(req.params.paymentId || ''), 10);
        const attachmentId = parseInt(String(req.params.attachmentId || ''), 10);
        const userId = parseInt(String(req.query.userId || ''), 10);
        if (
          Number.isNaN(invoiceId) ||
          Number.isNaN(paymentId) ||
          Number.isNaN(attachmentId) ||
          Number.isNaN(userId)
        ) {
          return res.status(400).json({ error: 'ids and userId required' });
        }
        const user = await ciGetUser(pool, userId, req);
        if (!user) return res.status(404).json({ error: 'user not found' });
        if (!ciCanAccessList(user, req)) {
          return res.status(403).json({ error: 'forbidden' });
        }
        const r = await pool.query(
          `SELECT * FROM cont_invoice_payment_attachments
           WHERE id = $1 AND payment_id = $2 AND invoice_id = $3`,
          [attachmentId, paymentId, invoiceId],
        );
        if (!r.rows.length) return res.status(404).json({ error: 'not found' });
        await ciSendPaymentFile(res, r.rows[0]);
      } catch (e) {
        res.status(500).json({ error: String(e.message) });
      }
    },
  );

  app.get('/cont-invoices/:id/payments/:paymentId/file', async (req, res) => {
    try {
      const invoiceId = parseInt(String(req.params.id || ''), 10);
      const paymentId = parseInt(String(req.params.paymentId || ''), 10);
      const userId = parseInt(String(req.query.userId || ''), 10);
      if (Number.isNaN(invoiceId) || Number.isNaN(paymentId) || Number.isNaN(userId)) {
        return res.status(400).json({ error: 'id, paymentId and userId required' });
      }
      const user = await ciGetUser(pool, userId, req);
      if (!user) return res.status(404).json({ error: 'user not found' });
      if (!ciCanAccessList(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }
      const child = await pool.query(
        `SELECT * FROM cont_invoice_payment_attachments
         WHERE payment_id = $1 AND invoice_id = $2
         ORDER BY id ASC LIMIT 1`,
        [paymentId, invoiceId],
      );
      if (child.rows.length) {
        await ciSendPaymentFile(res, child.rows[0]);
        return;
      }
      const r = await pool.query(
        `SELECT * FROM cont_invoice_payments
         WHERE id = $1 AND invoice_id = $2`,
        [paymentId, invoiceId],
      );
      if (!r.rows.length) return res.status(404).json({ error: 'not found' });
      await ciSendPaymentFile(res, r.rows[0]);
    } catch (e) {
      res.status(500).json({ error: String(e.message) });
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
      if (!ciCanDelete(user, req)) {
        return res.status(403).json({ error: 'forbidden' });
      }

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
