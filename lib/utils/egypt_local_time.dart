/// مصر UTC+3 ثابتاً (بدون توقيت صيفي منذ 2014).
const Duration egyptUtcOffset = Duration(hours: 3);

/// يحوّل أي [DateTime] إلى ساعة الحائط بتوقيت مصر (للعرض فقط).
DateTime toEgyptWallClock(DateTime value) {
  final utc = value.toUtc();
  final shifted = DateTime.fromMillisecondsSinceEpoch(
    utc.millisecondsSinceEpoch + egyptUtcOffset.inMilliseconds,
    isUtc: true,
  );
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
  );
}
