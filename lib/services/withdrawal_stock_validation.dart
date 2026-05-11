import '../models/location_material_model.dart';
import '../models/project_stock_model.dart';

const String withdrawalInsufficientStockMessage =
    'عملية سحب غير ناجحة الرصيد غير كافي';

/// يتحقق من كفاية رصيد مخزن المشروع لكل خامة مطلوب سحبها من الموقع.
bool hasSufficientStockForWithdrawal({
  required List<LocationMaterialModel> locationMaterials,
  required List<ProjectStockModel> projectStock,
}) {
  ProjectStockModel? findStock(String name) {
    for (final r in projectStock) {
      if (r.materialName == name) return r;
    }
    return null;
  }

  for (final m in locationMaterials) {
    final qty =
        double.tryParse(m.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    if (qty <= 0) continue;
    final row = findStock(m.materialName);
    if (row == null) return false;
    final current =
        double.tryParse(row.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    if (current < qty) return false;
  }
  return true;
}
