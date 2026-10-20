const String contInvoicesIconId = 'cont_invoices';
const String contInvoicesRouteName = 'cont-invoices';
const String contInvoicesHomeLabel = 'Cont-Invoices';

const String contProgressIconId = 'cont_progress';
const String contProgressRouteName = 'cont-progress';
const String contProgressHomeLabel = 'مستخلص مقاول-Progress';
const String contInvoicesDefaultContractType = 'تركيب';
const String contInvoicesContractTypeOther = 'آخر';

const List<String> contInvoicesContractTypeChoices = [
  contInvoicesDefaultContractType,
  contInvoicesContractTypeOther,
];

/// تداول Cont-Invoices — بالبريد كما في قاعدة البيانات.
const String contInvoicesQsEmail = 'QS-User';
const String contInvoicesQsEmailAlt = 'qs@app.com';
const String contInvoicesAhAminEmail = 'ah-amin';
const String contInvoicesPmEmail = 'abdelrhmanellaithy828@gmail.com';
const String contInvoicesOmEmail = 'shams';

const String contStatusDraft = 'draft';
const String contStatusPendingPrice = 'pending_price';
const String contStatusPendingPm = 'pending_pm';
const String contStatusPendingOm = 'pending_om';
const String contStatusApproved = 'approved';
const String contStatusPartiallyPaid = 'partially_paid';
const String contStatusPaid = 'paid';

const int contPaymentVoucherMaxBytes = 10 * 1024 * 1024;
const int contPaymentVoucherMaxFiles = 8;
const List<String> contPaymentVoucherExtensions = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'webp',
];

const String contractorAccountsIconId = 'contractor_accounts';
const String contractorAccountsRouteName = 'contractor-accounts';
const String contractorAccountsHomeLabel = 'حسابات المقاولين';

bool canPrintContInvoiceStatement(String status) {
  return status == contStatusApproved ||
      status == contStatusPartiallyPaid ||
      status == contStatusPaid;
}

String contInvoiceStatusLabelAr(String status) {
  switch (status) {
    case contStatusDraft:
      return 'مسودة';
    case contStatusPendingPrice:
      return 'مراجعة السعر';
    case contStatusPendingPm:
      return 'مراجعة مدير المشروعات';
    case contStatusPendingOm:
      return 'اعتماد العمليات';
    case contStatusApproved:
      return 'معتمد';
    case contStatusPartiallyPaid:
      return 'صرف جزئي';
    case contStatusPaid:
      return 'تم الصرف';
    default:
      return status;
  }
}

bool isContInvoicesQsEmail(String email) {
  final e = email.trim().toLowerCase();
  return e == contInvoicesQsEmail.toLowerCase() ||
      e == contInvoicesQsEmailAlt.toLowerCase();
}

bool isContInvoicesAhAminEmail(String email) =>
    email.trim().toLowerCase() == contInvoicesAhAminEmail.toLowerCase();

bool isContInvoicesPmEmail(String email) =>
    email.trim().toLowerCase() == contInvoicesPmEmail.toLowerCase();

bool isContInvoicesOmEmail(String email) =>
    email.trim().toLowerCase() == contInvoicesOmEmail.toLowerCase();

const List<String> contInvoicesUnitOptions = [
  'عدد',
  'م2',
  'م',
  'مقط',
  'يومية',
];

const String contLineKindExecution = 'execution';
const String contLineKindHoliday = 'holiday';
const String contLineKindTransport = 'transport';
const String contLineKindDeduction = 'deduction';
const String contLineKindNoteOnOther = 'note_on_other';

const List<String> contDeductionKindOptions = [
  'مقطوعية',
  'تركيب وزر',
  'معالجة',
  'أخرى',
];

