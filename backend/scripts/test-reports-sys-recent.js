/**
 * Smoke tests for recent Reports-SYS changes:
 * - full access tabs (archive, all) for app_admin
 * - delete restricted to primary admin email
 */
const BASE = process.env.API_BASE || 'http://127.0.0.1:3000';
const PRIMARY_EMAIL = 'mouhammedhelal@gmail.com';

async function get(path) {
  const r = await fetch(`${BASE}${path}`);
  const text = await r.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: r.status, body };
}

async function del(path) {
  const r = await fetch(`${BASE}${path}`, { method: 'DELETE' });
  const text = await r.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: r.status, body };
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

async function main() {
  const usersRes = await get(
    `/users?requesterEmail=${encodeURIComponent(PRIMARY_EMAIL)}`,
  );
  assert(usersRes.status === 200, 'users list failed');
  const users = usersRes.body;
  const admin = users.find(
    (u) => String(u.email).toLowerCase() === PRIMARY_EMAIL.toLowerCase(),
  );
  const engineer = users.find((u) => u.role === 'site_engineer');
  assert(admin, 'primary admin not found');
  assert(engineer, 'site engineer not found');

  const archive = await get(
    `/reports-sys/inbox?userId=${admin.id}&tab=archive&requesterEmail=${encodeURIComponent(admin.email)}`,
  );
  assert(archive.status === 200, `archive tab failed: ${archive.status}`);

  const all = await get(
    `/reports-sys/inbox?userId=${admin.id}&tab=all&requesterEmail=${encodeURIComponent(admin.email)}`,
  );
  assert(all.status === 200, `all tab failed: ${all.status}`);

  const delEngineer = await del(
    `/reports-sys/999999?userId=${engineer.id}&requesterEmail=${encodeURIComponent(engineer.email)}`,
  );
  assert(delEngineer.status === 403, `engineer delete should be 403, got ${delEngineer.status}`);

  const delAdmin = await del(
    `/reports-sys/999999?userId=${admin.id}&requesterEmail=${encodeURIComponent(admin.email)}`,
  );
  assert(
    delAdmin.status === 404,
    `admin delete missing report should be 404, got ${delAdmin.status}`,
  );

  console.log('=== Recent Reports-SYS checks passed ===');
  console.log('✓ archive tab for app_admin');
  console.log('✓ all tab for app_admin');
  console.log('✓ delete forbidden for engineer');
  console.log('✓ delete allowed path for primary admin (404 on missing id)');
}

main().catch((e) => {
  console.error('FAILED:', e.message);
  process.exit(1);
});
