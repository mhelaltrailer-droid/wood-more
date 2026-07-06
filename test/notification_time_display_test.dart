import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wood_and_more_app/utils/notification_time_display.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

  test('formatNotificationDateTime يحوّل UTC إلى توقيت مصر (+3)', () {
    final utc = DateTime.utc(2026, 7, 5, 13, 25);
    final formatted = formatNotificationDateTime(utc);
    expect(formatted, contains('2026'));
    expect(formatted, contains('04:25'));
  });
}
