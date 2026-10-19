/**
 * تخزين مضمّن في أعمدة TEXT/JSON: إما data URL قديم (DB) أو مرجع R2 كـ JSON.
 * الكتابة الجديدة تفضّل R2 عند التهيئة؛ القراءة تفك المرجع إلى data URL للتوافق مع الواجهة.
 */
const crypto = require('crypto');
const {
  isR2Configured,
  stripBase64Payload,
  r2PutObject,
  r2GetObjectBuffer,
  r2DeleteObject,
} = require('./r2');

function safeFileSuffix(name) {
  const base = String(name || 'file').replace(/[^a-zA-Z0-9._-]+/g, '_');
  return base.slice(0, 80) || 'file';
}

function guessMimeFromDataUrl(raw) {
  const s = String(raw || '');
  if (!s.startsWith('data:')) return 'application/octet-stream';
  const semi = s.indexOf(';');
  if (semi < 5) return 'application/octet-stream';
  return s.slice(5, semi).trim() || 'application/octet-stream';
}

function parseR2Ref(stored) {
  const s = String(stored || '').trim();
  if (!s.startsWith('{')) return null;
  try {
    const obj = JSON.parse(s);
    if (obj && String(obj.storage_backend) === 'r2' && obj.storage_key) {
      return {
        storage_backend: 'r2',
        storage_key: String(obj.storage_key),
        mime_type: String(obj.mime_type || 'application/octet-stream'),
        size_bytes: parseInt(String(obj.size_bytes || '0'), 10) || 0,
      };
    }
  } catch (_) {}
  return null;
}

function encodeR2Ref({ storage_key, mime_type, size_bytes }) {
  return JSON.stringify({
    storage_backend: 'r2',
    storage_key,
    mime_type: mime_type || 'application/octet-stream',
    size_bytes: size_bytes || 0,
  });
}

/**
 * يخزّن حمولة base64/data-URL. إن كان R2 مضبوطًا يعيد JSON مرجع؛ وإلا يعيد النص كما هو.
 */
async function storeInlineBlob({
  keyPrefix,
  ownerId,
  raw,
  fileName,
  mimeType,
}) {
  const s = String(raw || '').trim();
  if (!s) return null;
  if (!isR2Configured()) return s;

  const mime = mimeType || guessMimeFromDataUrl(s);
  const rawB64 = stripBase64Payload(s);
  const body = Buffer.from(rawB64, 'base64');
  const key = `${keyPrefix}/${ownerId}/${crypto.randomUUID()}-${safeFileSuffix(fileName)}`;
  await r2PutObject({ key, body, contentType: mime });
  return encodeR2Ref({
    storage_key: key,
    mime_type: mime,
    size_bytes: body.length,
  });
}

async function loadInlineBlobToDataUrl(stored) {
  const s = String(stored || '').trim();
  if (!s) return null;
  const ref = parseR2Ref(s);
  if (ref) {
    const buf = await r2GetObjectBuffer(ref.storage_key);
    return `data:${ref.mime_type};base64,${buf.toString('base64')}`;
  }
  return s;
}

async function loadInlineBlobToBase64(stored) {
  const s = String(stored || '').trim();
  if (!s) return '';
  const ref = parseR2Ref(s);
  if (ref) {
    const buf = await r2GetObjectBuffer(ref.storage_key);
    return buf.toString('base64');
  }
  return stripBase64Payload(s);
}

async function deleteInlineBlobIfR2(stored) {
  const ref = parseR2Ref(stored);
  if (ref) await r2DeleteObject(ref.storage_key);
}

async function storeInlineBlobList({
  keyPrefix,
  ownerId,
  items,
  fileNamePrefix,
}) {
  const out = [];
  const list = Array.isArray(items) ? items : [];
  for (let i = 0; i < list.length; i++) {
    const stored = await storeInlineBlob({
      keyPrefix,
      ownerId,
      raw: list[i],
      fileName: `${fileNamePrefix || 'image'}-${i + 1}`,
    });
    if (stored) out.push(stored);
  }
  return out;
}

async function loadInlineBlobListToDataUrls(items) {
  const list = Array.isArray(items) ? items : [];
  const out = [];
  for (const item of list) {
    const dataUrl = await loadInlineBlobToDataUrl(item);
    if (dataUrl) out.push(dataUrl);
  }
  return out;
}

async function deleteInlineBlobListIfR2(items) {
  const list = Array.isArray(items) ? items : [];
  for (const item of list) {
    await deleteInlineBlobIfR2(item);
  }
}

module.exports = {
  parseR2Ref,
  encodeR2Ref,
  storeInlineBlob,
  loadInlineBlobToDataUrl,
  loadInlineBlobToBase64,
  deleteInlineBlobIfR2,
  storeInlineBlobList,
  loadInlineBlobListToDataUrls,
  deleteInlineBlobListIfR2,
  guessMimeFromDataUrl,
};
