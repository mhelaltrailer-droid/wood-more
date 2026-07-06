import 'package:intl/intl.dart';

import 'egypt_local_time.dart';

/// تنسيق وقت الإشعارات بتوقيت مصر المحلي (UTC+3).
String formatNotificationDateTime(DateTime value) {
  return DateFormat('yyyy/MM/dd hh:mm a', 'ar')
      .format(toEgyptWallClock(value));
}

String formatNotificationDateTimeCompact(DateTime value) {
  return DateFormat('dd/MM/yyyy HH:mm', 'ar').format(toEgyptWallClock(value));
}
