import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/location_material_model.dart';
import 'package:wood_and_more_app/models/project_stock_model.dart';
import 'package:wood_and_more_app/services/withdrawal_stock_validation.dart';

void main() {
  group('hasSufficientStockForWithdrawal', () {
    test('returns true when every required material is covered', () {
      final ok = hasSufficientStockForWithdrawal(
        locationMaterials: [
          LocationMaterialModel(
            id: 1,
            locationId: 1,
            phase: LocationMaterialModel.phaseFirstFix,
            materialName: 'خشب',
            quantity: '5',
            unit: 'متر',
          ),
        ],
        projectStock: [
          ProjectStockModel(
            id: 1,
            projectId: 1,
            materialName: 'خشب',
            quantity: '10',
            unit: 'متر',
          ),
        ],
      );

      expect(ok, isTrue);
    });

    test('returns false when stock is below required quantity', () {
      final ok = hasSufficientStockForWithdrawal(
        locationMaterials: [
          LocationMaterialModel(
            id: 1,
            locationId: 1,
            phase: LocationMaterialModel.phaseFirstFix,
            materialName: 'خشب',
            quantity: '6',
            unit: 'متر',
          ),
        ],
        projectStock: [
          ProjectStockModel(
            id: 1,
            projectId: 1,
            materialName: 'خشب',
            quantity: '5',
            unit: 'متر',
          ),
        ],
      );

      expect(ok, isFalse);
    });

    test('returns false when material is missing from project stock', () {
      final ok = hasSufficientStockForWithdrawal(
        locationMaterials: [
          LocationMaterialModel(
            id: 1,
            locationId: 1,
            phase: LocationMaterialModel.phaseFirstFix,
            materialName: 'مسامير',
            quantity: '1',
            unit: 'كجم',
          ),
        ],
        projectStock: const [],
      );

      expect(ok, isFalse);
    });

    test('ignores zero-quantity location materials', () {
      final ok = hasSufficientStockForWithdrawal(
        locationMaterials: [
          LocationMaterialModel(
            id: 1,
            locationId: 1,
            phase: LocationMaterialModel.phaseFirstFix,
            materialName: 'خشب',
            quantity: '0',
            unit: 'متر',
          ),
        ],
        projectStock: const [],
      );

      expect(ok, isTrue);
    });
  });
}
