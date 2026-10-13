const String invoiceStructureIconId = 'invoice_structure';
const String invoiceStructureRouteName = 'invoice-structure';
const String invoiceStructureHomeLabel = 'هيكلة المستخلصات';

const String invoiceStructureMeasureFlooring = 'flooring';
const String invoiceStructureMeasureWpc = 'wpc';

String invoiceStructureMeasureLabel(String? measureType) {
  switch ((measureType ?? '').toLowerCase()) {
    case invoiceStructureMeasureFlooring:
      return 'Flooring';
    case invoiceStructureMeasureWpc:
      return 'WPC';
    default:
      return '—';
  }
}
