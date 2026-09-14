/// فترات التحديث الدوري لطلبات الـ API.
///
/// Neon على Free ينام بعد ~5 دقائق بدون استعلامات. أي polling أقصر من ذلك
/// ويبقي الجلسة مفتوحة يمنع Scale to Zero ويستهلك CU-hours.
class AppPollingIntervals {
  AppPollingIntervals._();

  /// عدّادات الشاشة الرئيسية (تبقى مفتوحة طويلاً).
  /// أطول من 5 دقائق حتى يتمكن Neon من النوم بين الطلبات.
  static const Duration homeBadges = Duration(minutes: 6);

  /// شاشات قوائم الإشعارات أثناء فتحها.
  static const Duration notificationLists = Duration(minutes: 2);

  /// شاشات Hub / طلبات سحب أثناء فتحها.
  static const Duration openHubScreens = Duration(minutes: 2);

  /// فحص System Lock أثناء الجلسة (مع فحص إضافي عند Resume).
  static const Duration systemLock = Duration(minutes: 6);
}
