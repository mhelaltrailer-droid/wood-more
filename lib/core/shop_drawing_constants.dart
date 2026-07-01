/// ثوابت ميزة Shop-Drawing & PO (مستقلة عن Reports-SYS).
const shopDrawingPmEmail = 'abdelrhmanellaithy828@gmail.com';

const shopDrawingMaxAttachmentBytes = 5 * 1024 * 1024;
const shopDrawingMaxAttachments = 10;

const shopDrawingRoleTechnicalOffice = 'technical_office';
const shopDrawingRoleTopManagement = 'top_management';

/// قيمة API لنوع Shop-Drawing.
const shopDrawingDocumentTypeShopDrawing = 'shop_drawing';

/// قيمة API لنوع PO.
const shopDrawingDocumentTypePo = 'po';

const shopDrawingHomeIconLabel = 'SD & PO';

/// قيمة القائمة المنسدلة لاختيار مشروع غير موجود في جدول المشاريع.
const shopDrawingOtherProjectDropdownValue = -1;

const shopDrawingOtherProjectDropdownLabel = 'مشروع آخر';

bool isShopDrawingPmEmail(String email) =>
    email.trim().toLowerCase() == shopDrawingPmEmail.toLowerCase();

String shopDrawingDocumentTypeLabel(String documentType) {
  return documentType == shopDrawingDocumentTypePo ? 'PO' : 'Shop-Drawing';
}

bool isValidShopDrawingDocumentType(String documentType) {
  return documentType == shopDrawingDocumentTypeShopDrawing ||
      documentType == shopDrawingDocumentTypePo;
}

String shopDrawingEventType(int drawingId) => 'shop_drawing_$drawingId';

int? parseShopDrawingIdFromEventType(String eventType) {
  final t = eventType.trim();
  if (!t.startsWith('shop_drawing_')) return null;
  return int.tryParse(t.substring('shop_drawing_'.length));
}

/// يُرجع الرابط المُطبَّع أو null إن كان فارغاً. يرمي [FormatException] إن كان غير صالح.
String? normalizeShopDrawingExternalUrl(String? raw) {
  final input = raw?.trim() ?? '';
  if (input.isEmpty) return null;
  var candidate = input;
  if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
    candidate = 'https://$candidate';
  }
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
    throw const FormatException('invalid_url');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw const FormatException('invalid_url');
  }
  return uri.toString();
}
