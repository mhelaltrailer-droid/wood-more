/// ثوابت وحدة Invoices (Owner).
const String invoicesOwnerCreatorEmail = 'ah-amin';
const String invoicesOwnerQsCreatorEmailQsUser = 'QS-User';
const String invoicesOwnerQsCreatorEmailAli = 'Ali';

const int invoicesOwnerMaxAttachmentBytes = 5 * 1024 * 1024;
const int invoicesOwnerMaxAttachments = 4;

const String invoicesOwnerHomeIconLabel = 'Invoices (Owner)';

const String invoicesOwnerOtherProjectDropdownValueKey = 'other';
const int invoicesOwnerOtherProjectDropdownValue = -1;
const String invoicesOwnerOtherProjectDropdownLabel = 'مشروع آخر';

const String invoicesOwnerStatusPendingQs = 'pending_qs';
const String invoicesOwnerStatusPendingTo = 'pending_technical_office';
const String invoicesOwnerStatusPendingPm = 'pending_projects_manager';
const String invoicesOwnerStatusPendingFinance = 'pending_finance';
const String invoicesOwnerStatusPendingOm = 'pending_operation_manager';
const String invoicesOwnerStatusReturnedCreator = 'returned_to_creator';
const String invoicesOwnerStatusApproved = 'approved';

/// بنود قائمة مراجعة مدير العمليات قبل الاعتماد النهائي (اختيارية).
const List<({String key, String label})> invoicesOwnerOmChecklistItems = [
  (key: 'prepare_progress', label: 'اعداد progress'),
  (key: 'review_progress', label: 'مراجعه progress'),
  (
    key: 'prepare_invoice_ir_mir_ms',
    label: 'اعداد المستخلص و مراجعه (IR+MIR+MS)',
  ),
  (key: 'review_invoice_execution', label: 'مراجعه المستخلص (التنفيذ)'),
  (key: 'finance_review', label: 'المراجعه المالية للمستخلص'),
];

/// صفوف نموذج PDF Export بعد الاعتماد (نصوص الصورة + المسئول الثابت).
const List<({String key, String itemLabel, String responsible})>
    invoicesOwnerOmChecklistPdfRows = [
  (
    key: 'prepare_progress',
    itemLabel: 'إعداد Progress',
    responsible: 'إدارة التنفيذ',
  ),
  (
    key: 'review_progress',
    itemLabel: 'مراجعة Progress',
    responsible: 'إدارة العمليات',
  ),
  (
    key: 'prepare_invoice_ir_mir_ms',
    itemLabel: 'إعداد المستخلص ومراجعة (IR + MIR - MS)',
    responsible: 'المكتب الفني + QS',
  ),
  (
    key: 'review_invoice_execution',
    itemLabel: 'مراجعة المستخلص',
    responsible: 'إدارة التنفيذ',
  ),
  (
    key: 'finance_review',
    itemLabel: 'مراجعة المستخلص',
    responsible: 'إدارة الحسابات',
  ),
];

const Set<String> _invoicesOwnerCreatorEmails = {
  'ah-amin',
  'qs-user',
  'ali',
};

bool isInvoicesOwnerCreatorEmail(String email) =>
    _invoicesOwnerCreatorEmails.contains(email.trim().toLowerCase());

bool isInvoicesOwnerAhAminEmail(String email) =>
    email.trim().toLowerCase() == invoicesOwnerCreatorEmail.toLowerCase();
