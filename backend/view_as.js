/**
 * View as — للمسؤول الأساسي (mouhammedhelal@gmail.com) فقط.
 * الهيدر: X-View-As-Role + X-Requester-User-Id
 */
const PRIMARY_APP_ADMIN_EMAIL = 'mouhammedhelal@gmail.com';

const VIEW_AS_ALLOWED_ROLES = new Set([
  'site_engineer',
  'site_engineer_manager',
  'projects_manager',
  'general_supervisor',
  'operation_manager',
  'accountant',
  'document_controller',
  'technical_office',
  'top_management',
  'op_coordinator',
  'qs',
  'finance',
]);

function normEmail(email) {
  return String(email || '')
    .trim()
    .toLowerCase();
}

function isPrimaryAppAdminEmail(email) {
  return normEmail(email) === PRIMARY_APP_ADMIN_EMAIL.toLowerCase();
}

/** يقرأ هيدرات View as على الطلب (بدون التحقق من البريد بعد). */
function attachViewAsHeaders(req, _res, next) {
  const rawRole = String(req.headers['x-view-as-role'] || '').trim();
  const rawUid = parseInt(String(req.headers['x-requester-user-id'] || ''), 10);
  const roleOk = rawRole && VIEW_AS_ALLOWED_ROLES.has(rawRole);
  req.viewAsRole = roleOk ? rawRole : null;
  req.viewAsRequesterId = Number.isInteger(rawUid) && rawUid > 0 ? rawUid : null;
  next();
}

/**
 * إن كان المستخدم هو المسؤول الأساسي ونشط View as لنفسه → يستبدل role.
 * لا يغيّر البريد/الـ id (السجلات تبقى باسمه).
 */
function applyViewAsToUser(user, req) {
  if (!user || !req) return user;
  const role = req.viewAsRole;
  const requesterId = req.viewAsRequesterId;
  if (!role || !requesterId) return user;
  const uid = parseInt(user.id, 10);
  if (uid !== requesterId) return user;
  if (!isPrimaryAppAdminEmail(user.email)) return user;
  return {
    ...user,
    role,
    _viewAsActive: true,
  };
}

/** صلاحيات الإيميل الخاصة بالمسؤول الأساسي — تُلغى أثناء View as. */
function primaryAdminPowersActive(email, req) {
  if (!isPrimaryAppAdminEmail(email)) return false;
  if (req && req.viewAsRole && req.viewAsRequesterId) return false;
  return true;
}

function primaryAdminPowersActiveForUser(user, req) {
  if (!user) return false;
  if (user._viewAsActive) return false;
  return primaryAdminPowersActive(user.email, req);
}

module.exports = {
  PRIMARY_APP_ADMIN_EMAIL,
  VIEW_AS_ALLOWED_ROLES,
  isPrimaryAppAdminEmail,
  attachViewAsHeaders,
  applyViewAsToUser,
  primaryAdminPowersActive,
  primaryAdminPowersActiveForUser,
};
