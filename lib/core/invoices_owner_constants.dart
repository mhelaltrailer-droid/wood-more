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

const Set<String> _invoicesOwnerCreatorEmails = {
  'ah-amin',
  'qs-user',
  'ali',
};

bool isInvoicesOwnerCreatorEmail(String email) =>
    _invoicesOwnerCreatorEmails.contains(email.trim().toLowerCase());

bool isInvoicesOwnerAhAminEmail(String email) =>
    email.trim().toLowerCase() == invoicesOwnerCreatorEmail.toLowerCase();
