import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/utils/material_name_compare.dart';

void main() {
  final materials = [
    {'id': 1, 'name': 'ST 10mm'},
    {'id': 2, 'name': 'Wood Panel 18mm'},
    {'id': 3, 'name': 'ST10mm'},
  ];

  test('exact duplicate ignores case and extra spaces', () {
    expect(findDuplicateMaterialName('st 10mm', materials), 'ST 10mm');
    expect(findDuplicateMaterialName('ST  10mm', materials), 'ST 10mm');
    expect(findDuplicateMaterialName('Wood Panel 18mm', materials), 'Wood Panel 18mm');
  });

  test('similar matches when spaces differ but not exact duplicate', () {
    final similar = findSimilarMaterialNames('ST10mm', materials);
    expect(similar, contains('ST 10mm'));
    expect(similar, isNot(contains('ST10mm')));
  });

  test('new loose name finds stored variants as similar', () {
    final similar = findSimilarMaterialNames('st 10 mm', materials);
    expect(similar, containsAll(['ST 10mm', 'ST10mm']));
  });

  test('excludeId skips current material when editing', () {
    expect(findDuplicateMaterialName('ST 10mm', materials, excludeId: 1), isNull);
    expect(findSimilarMaterialNames('ST10mm', materials, excludeId: 3), contains('ST 10mm'));
  });

  test('no duplicate or similar for unique name', () {
    expect(findDuplicateMaterialName('Glass 6mm', materials), isNull);
    expect(findSimilarMaterialNames('Glass 6mm', materials), isEmpty);
  });
}
