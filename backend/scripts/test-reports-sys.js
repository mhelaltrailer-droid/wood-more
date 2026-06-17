/**
 * Reports-SYS integration smoke test — full workflow simulation.
 * Uses user IDs from API (no login required for reports-sys routes).
 * Run: node backend/scripts/test-reports-sys.js
 */
const BASE = process.env.API_BASE || 'http://localhost:3000';
const ADMIN_EMAIL = 'mouhammedhelal@gmail.com';

async function req(method, path, body) {
  const r = await fetch(`${BASE}${path}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await r.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch (_) {
    json = text;
  }
  return { status: r.status, json };
}

function assert(cond, msg) {
  if (!cond) throw new Error(`ASSERT: ${msg}`);
}

async function fetchUsers() {
  const r = await req('GET', `/users?requesterEmail=${encodeURIComponent(ADMIN_EMAIL)}`);
  assert(r.status === 200 && Array.isArray(r.json), 'users list');
  return r.json;
}

function pickUser(users, role, preferEmail) {
  if (preferEmail) {
    const byEmail = users.find(
      (u) => u.email?.toLowerCase() === preferEmail.toLowerCase(),
    );
    if (byEmail) return byEmail;
  }
  return users.find((u) => u.role === role);
}

async function main() {
  const stamp = Date.now();
  const results = [];
  const users = await fetchUsers();

  const creator = pickUser(users, 'site_engineer');
  const manager1 = pickUser(users, 'site_engineer_manager', 'mouhamedhelal.cor@gmail.com');
  const manager2 = pickUser(users, 'site_engineer_manager', 'abdelrhmanellaithy828@gmail.com');
  const om = pickUser(users, 'operation_manager', 'islam.shams2050@gmail.com');
  const admin = pickUser(users, 'app_admin', ADMIN_EMAIL);

  assert(creator && manager1 && manager2 && om && admin, 'missing test users');
  console.log('Users:', {
    creator: `${creator.name} (#${creator.id})`,
    manager1: `${manager1.name} (#${manager1.id})`,
    manager2: `${manager2.name} (#${manager2.id})`,
    om: `${om.name} (#${om.id})`,
    admin: `${admin.name} (#${admin.id})`,
  });

  const projects = await req('GET', '/projects');
  assert(projects.status === 200 && projects.json?.length, 'projects');
  const projectId = projects.json[0].id;

  const reportName = `تقرير_اختبار_${stamp}`;
  const reportName2 = `تقرير_اختبار_2_${stamp}`;
  const reportNameOther = `تقرير_مشروع_اخر_${stamp}`;

  let r = await req('POST', '/reports-sys', {
    userId: creator.id,
    reportName,
    reportType: 'تقرير معاينة',
    summary: 'ملخص اختبار آلي للنظام',
    notes: 'ملاحظة اختبار',
    projectId,
  });
  assert(r.status === 201, `create: ${r.status} ${JSON.stringify(r.json)}`);
  const reportId = r.json.id;
  assert(r.json.status === 'draft' && r.json.project_name, 'draft + project');
  results.push('✓ إنشاء مسودة مع مشروع');

  r = await req('POST', '/reports-sys', {
    userId: creator.id,
    reportName,
    reportType: 'تقرير تلفيات',
    summary: 'x',
    projectId,
  });
  assert(r.status === 409, 'duplicate name');
  results.push('✓ رفض الاسم المكرر');

  r = await req('POST', '/reports-sys', {
    userId: creator.id,
    reportName: reportNameOther,
    reportType: 'تقرير إثبات حالة',
    summary: 'مشروع يدوي',
    projectId: -1,
    projectName: 'مشروع تجريبي يدوي',
  });
  assert(r.status === 201 && r.json.project_name === 'مشروع تجريبي يدوي', 'other project');
  results.push('✓ مشروع اخر + اسم يدوي');

  r = await req('POST', `/reports-sys/${reportId}/submit`, {
    userId: creator.id,
    toUserId: manager1.id,
    comment: 'يرجى المراجعة',
  });
  assert(r.status === 200 && r.json.status === 'pending_review', 'submit');
  results.push('✓ إرسال للمسند إليه');

  r = await req('PUT', `/reports-sys/${reportId}`, {
    userId: creator.id,
    reportName,
    reportType: 'تقرير معاينة',
    summary: 'محاولة تعديل',
    projectId,
  });
  assert(r.status === 400 && r.json?.error === 'not_editable', 'block edit after send');
  results.push('✓ المنشئ لا يعدّل بعد الإرسال');

  r = await req('POST', `/reports-sys/${reportId}/respond`, {
    userId: manager1.id,
    action: 'forward',
    toUserId: manager2.id,
    comment: 'تم الاطلاع',
  });
  assert(r.status === 200 && r.json.current_assignee_user_id === manager2.id, 'forward');
  results.push('✓ توجيه بين المراجعين');

  r = await req('POST', `/reports-sys/${reportId}/respond`, {
    userId: manager1.id,
    action: 'forward',
    toUserId: creator.id,
  });
  assert(r.status === 403, 'prev user blocked');
  results.push('✓ المستخدم السابق لا يتصرف');

  r = await req('POST', `/reports-sys/${reportId}/respond`, {
    userId: manager2.id,
    action: 'reject',
  });
  assert(r.status === 400 && r.json?.error === 'reason_required', 'reject reason');
  results.push('✓ الرفض بدون سبب مرفوض');

  r = await req('POST', `/reports-sys/${reportId}/respond`, {
    userId: manager2.id,
    action: 'return',
    comment: 'أضف تفاصيل',
  });
  assert(r.status === 200 && r.json.status === 'returned_for_edit', 'return');
  results.push('✓ إرجاع للمنشئ');

  r = await req('PUT', `/reports-sys/${reportId}`, {
    userId: creator.id,
    reportName,
    reportType: 'تقرير معاينة',
    summary: 'ملخص محدّث',
    projectId,
  });
  assert(r.status === 200, 'edit after return');
  r = await req('POST', `/reports-sys/${reportId}/submit`, {
    userId: creator.id,
    toUserId: manager1.id,
  });
  assert(r.status === 200 && r.json.current_assignee_user_id === manager1.id, 'resubmit');
  results.push('✓ تعديل وإعادة إرسال');

  // الأرشفة: يجب أن يكون التقرير بحوزة من يملك صلاحية الأرشفة
  r = await req('POST', `/reports-sys/${reportId}/respond`, {
    userId: manager1.id,
    action: 'forward',
    toUserId: om.id,
    comment: 'للأرشفة',
  });
  assert(r.status === 200 && r.json.current_assignee_user_id === om.id, 'forward to OM');
  results.push('✓ توجيه لمدير العمليات للأرشفة');

  r = await req('POST', `/reports-sys/${reportId}/respond`, {
    userId: om.id,
    action: 'archive',
    comment: 'مقبول نهائياً',
  });
  assert(r.status === 200 && r.json.status === 'archived', 'archive by OM');
  results.push('✓ أرشفة بواسطة مدير العمليات');

  r = await req('POST', `/reports-sys/${reportId}/respond`, {
    userId: manager1.id,
    action: 'forward',
    toUserId: manager2.id,
  });
  assert(r.status === 400, 'no action on archived');
  results.push('✓ لا إجراء على المؤرشف');

  r = await req('POST', '/reports-sys', {
    userId: creator.id,
    reportName: reportName2,
    reportType: 'تقرير تلفيات',
    summary: 'لاختبار الرفض',
    projectId,
  });
  const rejectId = r.json.id;
  await req('POST', `/reports-sys/${rejectId}/submit`, {
    userId: creator.id,
    toUserId: manager1.id,
  });
  r = await req('POST', `/reports-sys/${rejectId}/respond`, {
    userId: manager1.id,
    action: 'reject',
    comment: 'بيانات غير كافية',
  });
  assert(r.status === 200 && r.json.status === 'rejected', 'rejected');
  results.push('✓ رفض مع سبب');

  r = await req('POST', `/reports-sys/${rejectId}/relaunch`, {
    userId: creator.id,
    reportName: `${reportName2}_جديد`,
  });
  assert(r.status === 201 && r.json.status === 'draft', 'relaunch');
  results.push('✓ إعادة إطلاق من مرفوض');

  r = await req('GET', `/reports-sys/pending-count?userId=${manager1.id}`);
  assert(r.status === 200, 'pending count');
  results.push('✓ عداد بانتظار الإجراء');

  r = await req(
    'GET',
    `/reports-sys/inbox?userId=${om.id}&tab=archive&requesterEmail=${encodeURIComponent(om.email)}`,
  );
  assert(r.status === 200 && r.json.some((x) => x.id === reportId), 'archive inbox');
  results.push('✓ تبويب الأرشيف');

  const detail = await req('GET', `/reports-sys/${reportId}`);
  assert(detail.json.actions?.length >= 5, 'timeline actions');
  assert(detail.json.reviewers?.length >= 1, 'reviewers list');
  results.push('✓ المسار الزمني والمطلعون');

  console.log('\n=== Reports-SYS: جميع الاختبارات نجحت ===\n');
  results.forEach((line) => console.log(line));
  console.log(`\n${results.length} checks passed.`);
}

main().catch((e) => {
  console.error('\n=== فشل الاختبار ===');
  console.error(e.message || e);
  process.exit(1);
});
