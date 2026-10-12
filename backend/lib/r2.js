/**
 * Cloudflare R2 (S3-compatible) helpers for attachment blobs.
 * Requires env: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET
 * Optional: R2_ENDPOINT (defaults to https://<ACCOUNT_ID>.r2.cloudflarestorage.com)
 */
const { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } =
  require('@aws-sdk/client-s3');

let _client = null;
let _warnedMissing = false;

function r2Config() {
  const accountId = String(process.env.R2_ACCOUNT_ID || '').trim();
  const accessKeyId = String(process.env.R2_ACCESS_KEY_ID || '').trim();
  const secretAccessKey = String(process.env.R2_SECRET_ACCESS_KEY || '').trim();
  const bucket = String(process.env.R2_BUCKET || '').trim();
  const endpoint = String(
    process.env.R2_ENDPOINT ||
      (accountId ? `https://${accountId}.r2.cloudflarestorage.com` : ''),
  ).trim();
  return { accountId, accessKeyId, secretAccessKey, bucket, endpoint };
}

function isR2Configured() {
  const c = r2Config();
  return Boolean(c.accessKeyId && c.secretAccessKey && c.bucket && c.endpoint);
}

function getR2Client() {
  if (!isR2Configured()) {
    if (!_warnedMissing) {
      console.warn(
        'R2: not configured (missing R2_* env). New attachments stay in DB.',
      );
      _warnedMissing = true;
    }
    return null;
  }
  if (_client) return _client;
  const c = r2Config();
  _client = new S3Client({
    region: 'auto',
    endpoint: c.endpoint,
    credentials: {
      accessKeyId: c.accessKeyId,
      secretAccessKey: c.secretAccessKey,
    },
  });
  return _client;
}

function stripBase64Payload(raw) {
  let s = String(raw || '').trim();
  const idx = s.indexOf('base64,');
  if (idx !== -1) s = s.slice(idx + 'base64,'.length);
  return s.replace(/\s/g, '');
}

async function r2PutObject({ key, body, contentType }) {
  const client = getR2Client();
  if (!client) throw new Error('r2_not_configured');
  const { bucket } = r2Config();
  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: body,
      ContentType: contentType || 'application/octet-stream',
    }),
  );
  return { bucket, key };
}

async function r2GetObjectBuffer(key) {
  const client = getR2Client();
  if (!client) throw new Error('r2_not_configured');
  const { bucket } = r2Config();
  const out = await client.send(
    new GetObjectCommand({ Bucket: bucket, Key: key }),
  );
  const chunks = [];
  for await (const chunk of out.Body) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  return Buffer.concat(chunks);
}

async function r2DeleteObject(key) {
  if (!key) return;
  const client = getR2Client();
  if (!client) return;
  const { bucket } = r2Config();
  try {
    await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
  } catch (e) {
    console.warn('R2 deleteObject failed:', key, e.message);
  }
}

module.exports = {
  isR2Configured,
  stripBase64Payload,
  r2PutObject,
  r2GetObjectBuffer,
  r2DeleteObject,
};
