/**
 * حماية سكربتات التطوير من التنفيذ غير المقصود على Neon (الإنتاج).
 *
 * الاستخدام بعد تحميل dotenv:
 *   const { assertNeonConfirmed, describeDbTarget } = require('./lib/db_target_guard');
 *   assertNeonConfirmed({ action: 'وصف مختصر للعملية' });
 *
 * للسماح بتنفيذ مقصود على Neon:
 *   CONFIRM_PRODUCTION=1   أو   --confirm-production
 */
function databaseUrl() {
  return String(process.env.DATABASE_URL || '').trim();
}

function isNeonUrl(url = databaseUrl()) {
  return /neon\.tech/i.test(url);
}

function hasProductionConfirm() {
  if (String(process.env.CONFIRM_PRODUCTION || '').trim() === '1') return true;
  return process.argv.some(
    (a) => a === '--confirm-production' || a === '--confirm-production=1',
  );
}

function describeDbTarget(url = databaseUrl()) {
  if (!url) return 'none (DATABASE_URL unset — use PG* / local Postgres)';
  if (isNeonUrl(url)) {
    try {
      const host = new URL(url).hostname;
      return `Neon (${host})`;
    } catch (_) {
      return 'Neon';
    }
  }
  return 'non-Neon DATABASE_URL';
}

/**
 * يمنع تشغيل سكربت ضد Neon إلا بعد تأكيد صريح.
 * التطوير اليومي: اترك DATABASE_URL فارغاً واستخدم Postgres المحلي.
 */
function assertNeonConfirmed({ action = 'this script' } = {}) {
  const url = databaseUrl();
  if (!isNeonUrl(url)) {
    return { target: url ? 'other' : 'local', url };
  }
  if (hasProductionConfirm()) {
    console.warn(`[db-guard] Confirmed: ${action} → ${describeDbTarget(url)}`);
    return { target: 'neon', url };
  }
  console.error(`
[db-guard] Refusing to run against Neon without confirmation.
  Action : ${action}
  Target : ${describeDbTarget(url)}

Daily development should NOT use production Neon (burns CU-hours).
  • Unset DATABASE_URL in backend/.env
  • Use local Postgres: docker compose up postgres
  • Or PGHOST=localhost PGUSER=wood_more PGPASSWORD=wood_more PGDATABASE=wood_more

To run intentionally against Neon, add ONE of:
  CONFIRM_PRODUCTION=1
  --confirm-production
`);
  process.exit(1);
}

module.exports = {
  databaseUrl,
  isNeonUrl,
  hasProductionConfirm,
  describeDbTarget,
  assertNeonConfirmed,
};
