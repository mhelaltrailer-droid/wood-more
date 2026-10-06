import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/widgets/home_icon_builder.dart';

void main() {
  group('attendanceRequiredToOpenIcons', () {
    test('Friday does not require attendance', () {
      // 2026-04-10 is a Friday.
      expect(
        HomeIconBuilder.attendanceRequiredToOpenIcons(DateTime(2026, 4, 10)),
        isFalse,
      );
    });

    test('Saturday–Thursday still require attendance', () {
      // 2026-04-11 Saturday … 2026-04-16 Thursday.
      for (var day = 11; day <= 16; day++) {
        expect(
          HomeIconBuilder.attendanceRequiredToOpenIcons(DateTime(2026, 4, day)),
          isTrue,
          reason: 'day $day should require attendance',
        );
      }
    });
  });
}
