import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/models/location_material_model.dart';
import 'package:wood_and_more_app/models/location_withdrawal_model.dart';
import 'package:wood_and_more_app/services/project_warehouse_loading.dart';

void main() {
  test('warehouseLocationPhaseKey normalizes phase casing', () {
    expect(
      warehouseLocationPhaseKey(5, 'SECOND_FIX'),
      warehouseLocationPhaseKey(5, LocationMaterialModel.phaseSecondFix),
    );
    expect(
      warehouseLocationPhaseKey(5, 'unknown'),
      warehouseLocationPhaseKey(5, LocationMaterialModel.phaseFirstFix),
    );
  });

  test('indexMaterialsByLocationPhase groups and sorts materials', () {
    final indexed = indexMaterialsByLocationPhase([
      const LocationMaterialModel(
        id: 1,
        locationId: 10,
        phase: LocationMaterialModel.phaseFirstFix,
        materialName: 'Zeta',
        quantity: '1',
      ),
      const LocationMaterialModel(
        id: 2,
        locationId: 10,
        phase: LocationMaterialModel.phaseFirstFix,
        materialName: 'Alpha',
        quantity: '2',
      ),
      const LocationMaterialModel(
        id: 3,
        locationId: 11,
        phase: LocationMaterialModel.phaseSecondFix,
        materialName: 'Beta',
        quantity: '3',
      ),
    ]);

    final firstFixKey = warehouseLocationPhaseKey(
      10,
      LocationMaterialModel.phaseFirstFix,
    );
    expect(indexed[firstFixKey]?.map((m) => m.materialName).toList(), [
      'Alpha',
      'Zeta',
    ]);
    expect(
      indexed[warehouseLocationPhaseKey(11, LocationMaterialModel.phaseSecondFix)]
          ?.single
          .materialName,
      'Beta',
    );
  });

  test('indexWithdrawalsByLocationPhase keeps latest key per location and phase',
      () {
    final indexed = indexWithdrawalsByLocationPhase([
      LocationWithdrawalModel(
        id: 1,
        locationId: 7,
        phase: LocationMaterialModel.phaseFirstFix,
        userId: 1,
        userName: 'A',
        createdAt: DateTime(2026, 5, 1),
      ),
      LocationWithdrawalModel(
        id: 2,
        locationId: 7,
        phase: LocationMaterialModel.phaseSecondFix,
        userId: 2,
        userName: 'B',
        createdAt: DateTime(2026, 5, 2),
      ),
    ]);

    expect(
      indexed[warehouseLocationPhaseKey(7, LocationMaterialModel.phaseFirstFix)]
          ?.userName,
      'A',
    );
    expect(
      indexed[warehouseLocationPhaseKey(7, LocationMaterialModel.phaseSecondFix)]
          ?.userName,
      'B',
    );
  });

  test('warehouseLoadErrorMessage maps network failures to Arabic guidance', () {
    expect(
      warehouseLoadErrorMessage(
        Exception('ClientException: SocketException: connection abort'),
      ),
      contains('انقطع الاتصال'),
    );
    expect(
      warehouseLoadErrorMessage(Exception('server error')),
      contains('تعذّر تحميل بيانات المخازن'),
    );
  });
}
