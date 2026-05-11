import '../models/location_material_model.dart';
import '../models/location_withdrawal_model.dart';
import '../models/project_location_model.dart';

String warehouseLoadErrorMessage(Object error) {
  final message = error.toString();
  if (message.contains('connection abort') ||
      message.contains('SocketException') ||
      message.contains('ClientException')) {
    return 'انقطع الاتصال أثناء التحميل. تأكّد من الشبكة أو انتظر قليلاً ثم أعد المحاولة.';
  }
  return 'تعذّر تحميل بيانات المخازن. تحقّق من الاتصال ثم أعد المحاولة.';
}

String warehouseLocationPhaseKey(int locationId, String phase) {
  final normalized = phase.trim().toLowerCase();
  final safe = normalized == LocationMaterialModel.phaseSecondFix
      ? LocationMaterialModel.phaseSecondFix
      : LocationMaterialModel.phaseFirstFix;
  return '${locationId}_$safe';
}

Map<String, List<LocationMaterialModel>> indexMaterialsByLocationPhase(
  Iterable<LocationMaterialModel> materials,
) {
  final out = <String, List<LocationMaterialModel>>{};
  for (final material in materials) {
    final key = warehouseLocationPhaseKey(material.locationId, material.phase);
    out.putIfAbsent(key, () => []).add(material);
  }
  for (final entry in out.entries) {
    entry.value.sort((a, b) => a.materialName.compareTo(b.materialName));
  }
  return out;
}

Map<String, LocationWithdrawalModel?> indexWithdrawalsByLocationPhase(
  Iterable<LocationWithdrawalModel> withdrawals,
) {
  return {
    for (final withdrawal in withdrawals)
      warehouseLocationPhaseKey(withdrawal.locationId, withdrawal.phase):
          withdrawal,
  };
}

class ProjectWarehouseSnapshot {
  final List<ProjectLocationModel> locations;
  final Map<String, List<LocationMaterialModel>> materialsByLocationPhase;
  final Map<String, LocationWithdrawalModel?> withdrawalByLocationPhase;

  const ProjectWarehouseSnapshot({
    required this.locations,
    required this.materialsByLocationPhase,
    required this.withdrawalByLocationPhase,
  });
}

Future<ProjectWarehouseSnapshot> loadProjectWarehouseSnapshot(
  dynamic storage,
  int projectId,
) async {
  final results = await Future.wait<dynamic>([
    storage.getProjectLocations(projectId),
    storage.getLocationMaterialsForProject(projectId),
    storage.getLocationWithdrawalsForProject(projectId),
  ]);
  final locations = results[0] as List<ProjectLocationModel>;
  final allMaterials = results[1] as List<LocationMaterialModel>;
  final withdrawals = results[2] as List<LocationWithdrawalModel>;
  return ProjectWarehouseSnapshot(
    locations: locations,
    materialsByLocationPhase: indexMaterialsByLocationPhase(allMaterials),
    withdrawalByLocationPhase: indexWithdrawalsByLocationPhase(withdrawals),
  );
}
