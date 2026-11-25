import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/screens/accountant_finance_screen.dart';

void main() {
  group('lastFridayOnOrBefore', () {
    test('الجمعة تُعاد نفسها', () {
      // 2026-11-20 = Friday
      final d = DateTime(2026, 11, 20);
      expect(lastFridayOnOrBefore(d), DateTime(2026, 11, 20));
    });

    test('الخميس يعود لجمعة الأسبوع السابق', () {
      // 2026-11-26 = Thursday → Friday 2026-11-20
      final d = DateTime(2026, 11, 26);
      expect(lastFridayOnOrBefore(d), DateTime(2026, 11, 20));
    });

    test('الإثنين يعود لآخر جمعة', () {
      // 2026-11-23 = Monday → Friday 2026-11-20
      final d = DateTime(2026, 11, 23);
      expect(lastFridayOnOrBefore(d), DateTime(2026, 11, 20));
    });
  });

  group('sanitizePdfUserFileName', () {
    test('يستبدل الرموز غير الآمنة', () {
      expect(sanitizePdfUserFileName('Eng/Ali:Test'), 'Eng_Ali_Test');
    });

    test('الاسم الفارغ يصبح مستخدم', () {
      expect(sanitizePdfUserFileName('   '), 'مستخدم');
    });
  });
}
