/// جلسة «View as» للمسؤول الأساسي فقط — لا تُحفظ بين عمليات فتح التطبيق.
class ViewAsRoleSession {
  ViewAsRoleSession._();

  /// `null` أو فارغ = وضع المسؤول الأساسي (الصلاحيات الكاملة).
  static String? _viewAsRole;
  static int? _requesterUserId;

  static String? get viewAsRole {
    final r = _viewAsRole?.trim();
    return (r == null || r.isEmpty) ? null : r;
  }

  static int? get requesterUserId => _requesterUserId;

  static bool get isActive => viewAsRole != null;

  /// تسمية عنصر القائمة لوضع المسؤول الكامل.
  static const String primaryLabel = 'المسؤول الأساسي';

  /// قيمة القائمة التي تعني العودة للوضع الكامل (ليست دوراً في DB).
  static const String primaryOptionValue = '__primary__';

  static void setViewAs({
    required int requesterUserId,
    String? role,
  }) {
    _requesterUserId = requesterUserId;
    final r = role?.trim();
    if (r == null ||
        r.isEmpty ||
        r == primaryOptionValue ||
        r == 'app_admin') {
      _viewAsRole = null;
    } else {
      _viewAsRole = r;
    }
  }

  static void clear() {
    _viewAsRole = null;
    _requesterUserId = null;
  }

  /// تُرسل مع كل طلب API ليطبّق السيرفر الدور المعروض.
  static Map<String, String> apiHeaders() {
    final role = viewAsRole;
    final uid = _requesterUserId;
    if (role == null || uid == null) return const {};
    return {
      'X-View-As-Role': role,
      'X-Requester-User-Id': '$uid',
    };
  }
}
