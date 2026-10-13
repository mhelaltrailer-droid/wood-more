const String invoiceStructureIconId = 'invoice_structure';
const String invoiceStructureRouteName = 'invoice-structure';
const String invoiceStructureHomeLabel = 'هيكلة المستخلصات';

/// Flooring → معاملة الأمتار
const String invoiceStructureMeasureFlooring = 'flooring';

/// WPC → معاملة الـ Units
const String invoiceStructureMeasureWpc = 'wpc';

String invoiceStructureMeasureLabel(String? measureType) {
  switch ((measureType ?? '').toLowerCase()) {
    case invoiceStructureMeasureFlooring:
      return 'Flooring (أمتار)';
    case invoiceStructureMeasureWpc:
      return 'WPC (Units)';
    default:
      return '—';
  }
}
