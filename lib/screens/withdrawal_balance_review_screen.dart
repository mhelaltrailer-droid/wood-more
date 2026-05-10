import 'package:flutter/material.dart';
import '../models/location_material_model.dart';
import '../models/project_stock_model.dart';
import '../services/storage_service.dart';

/// صف واحد لعرض خامة قُطعت من مخزن المشروع ضمن سحب موقع فرعي.
class WithdrawalMaterialSnapshot {
  final String materialName;
  final String unit;
  final String beforeDisplay;
  final String withdrawnDisplay;
  final String afterDisplay;

  const WithdrawalMaterialSnapshot({
    required this.materialName,
    required this.unit,
    required this.beforeDisplay,
    required this.withdrawnDisplay,
    required this.afterDisplay,
  });
}

/// يطابق منطق [DatabaseService.createLocationWithdrawal] للعرض قبل التنفيذ.
List<WithdrawalMaterialSnapshot> buildWithdrawalPreviewRows({
  required List<LocationMaterialModel> locationMaterials,
  required List<ProjectStockModel> projectStock,
}) {
  String fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2);
  }

  ProjectStockModel? findStock(String name) {
    for (final r in projectStock) {
      if (r.materialName == name) return r;
    }
    return null;
  }

  final out = <WithdrawalMaterialSnapshot>[];
  for (final m in locationMaterials) {
    final qty = double.tryParse(m.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    if (qty <= 0) continue;
    final unitFallback = m.unit.isEmpty ? 'وحدة' : m.unit;
    final row = findStock(m.materialName);
    if (row != null) {
      final current = double.tryParse(row.quantity.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final newQty = current - qty;
      final u = row.unit.isNotEmpty ? row.unit : unitFallback;
      out.add(WithdrawalMaterialSnapshot(
        materialName: m.materialName,
        unit: u,
        beforeDisplay: fmt(current),
        withdrawnDisplay: fmt(qty),
        afterDisplay: fmt(newQty),
      ));
    } else {
      out.add(WithdrawalMaterialSnapshot(
        materialName: m.materialName,
        unit: unitFallback,
        beforeDisplay: '—',
        withdrawnDisplay: fmt(qty),
        afterDisplay: '—',
      ));
    }
  }
  return out;
}

/// تحويل آمن لنتيجة `getProjectStock` (dynamic/Web) إلى قائمة مُعرَّفة النوع لتفادي خطأ sort على المتصفح.
List<ProjectStockModel> coerceProjectStockList(dynamic raw) {
  if (raw == null) return [];
  if (raw is List<ProjectStockModel>) return List<ProjectStockModel>.from(raw);
  final iter = raw as Iterable<dynamic>;
  return iter.map<ProjectStockModel>((dynamic e) {
    if (e is ProjectStockModel) return e;
    return ProjectStockModel.fromMap(Map<String, dynamic>.from(e as Map));
  }).toList();
}

/// مراجعة قبل السحب: (1) معاينة الخامات المقرر سحبها → (2) كل خامات مخزن المشروع (أرصدة حالية).
/// لا يُنفَّذ [createLocationWithdrawal] إلا عند الضغط على «تمت مراجعة أرصدة المخزن» في الخطوة الأخيرة.
class WithdrawalBalanceReviewScreen extends StatefulWidget {
  final List<WithdrawalMaterialSnapshot> withdrawnSnapshots;
  final int projectId;
  final String projectName;
  final int locationId;
  final String phase;
  final int userId;
  final String userName;
  final String disbursementPermitImagesJson;
  final String deliveryPermitImagesJson;
  /// عند إتمام السحب يُعلَّم الطلب كمُنجَز (بعد موافقة المديرين).
  final int? withdrawalRequestId;

  const WithdrawalBalanceReviewScreen({
    super.key,
    required this.withdrawnSnapshots,
    required this.projectId,
    this.projectName = '',
    required this.locationId,
    required this.phase,
    required this.userId,
    required this.userName,
    required this.disbursementPermitImagesJson,
    required this.deliveryPermitImagesJson,
    this.withdrawalRequestId,
  });

  @override
  State<WithdrawalBalanceReviewScreen> createState() => _WithdrawalBalanceReviewScreenState();
}

class _WithdrawalBalanceReviewScreenState extends State<WithdrawalBalanceReviewScreen> {
  final _db = getStorage();
  int _step = 1;
  List<ProjectStockModel> _fullStock = [];
  bool _loadingStock = false;
  bool _committingWithdrawal = false;

  Future<void> _openFullWarehouse() async {
    setState(() => _loadingStock = true);
    try {
      final dynamic raw = await _db.getProjectStock(widget.projectId);
      if (!mounted) return;
      final list = coerceProjectStockList(raw)
        ..sort((ProjectStockModel a, ProjectStockModel b) => a.materialName.compareTo(b.materialName));
      setState(() {
        _fullStock = list;
        _loadingStock = false;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStock = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل مخزن المشروع: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _executeWithdrawalAndFinish() async {
    setState(() => _committingWithdrawal = true);
    try {
      await _db.createLocationWithdrawal(
        locationId: widget.locationId,
        phase: widget.phase,
        userId: widget.userId,
        userName: widget.userName,
        disbursementPermitImagesJson: widget.disbursementPermitImagesJson,
        deliveryPermitImagesJson: widget.deliveryPermitImagesJson,
      );
      final wrId = widget.withdrawalRequestId;
      if (wrId != null) {
        try {
          await _db.fulfillWithdrawalRequest(
            requestId: wrId,
            engineerUserId: widget.userId,
          );
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _committingWithdrawal = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تنفيذ السحب: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.projectName.trim().isNotEmpty ? widget.projectName : 'مشروع #${widget.projectId}';

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 1 ? 'أرصدة الخامات المسحوبة' : 'مخزن المشروع — جميع الخامات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: _step == 1 ? _buildStep1(title) : _buildStep2(title),
    );
  }

  Widget _buildStep1(String projectTitle) {
    final rows = widget.withdrawnSnapshots;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(projectTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'معاينة قبل التنفيذ — لن يُخصم من مخزن المشروع إلا بعد إتمام المراجعة في الخطوة التالية والضغط على «تمت مراجعة أرصدة المخزن».',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        const Text(
          'الرصيد الحالي والكمية المقرر سحبها والرصيد المتوقع بعد السحب (حسب مخزن المشروع)',
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('لا توجد كميات مسحوبة مسجّلة لهذا الموقع.'),
            ),
          )
        else
          ...rows.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.materialName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      _kv('الرصيد قبل السحب', '${r.beforeDisplay} ${r.unit}'),
                      _kv('الكمية المسحوبة', '${r.withdrawnDisplay} ${r.unit}'),
                      _kv('الرصيد بعد السحب', '${r.afterDisplay} ${r.unit}'),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _loadingStock ? null : _openFullWarehouse,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _loadingStock
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('تأكيد الكميات'),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildStep2(String projectTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(projectTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'كل الخامات في مخزن المشروع والرصيد الحالي (قبل تنفيذ السحب). راجع الأرصدة ثم أكّد تنفيذ السحب.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ),
        Expanded(
          child: _fullStock.isEmpty
              ? const Center(child: Text('لا توجد خامات في مخزن المشروع.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _fullStock.length,
                  separatorBuilder: (_, i) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = _fullStock[i];
                    return ListTile(
                      title: Text(s.materialName, overflow: TextOverflow.ellipsis),
                      trailing: Text(
                        '${s.quantity} ${s.unit}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _committingWithdrawal ? null : _executeWithdrawalAndFinish,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _committingWithdrawal
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('تمت مراجعة أرصدة المخزن'),
          ),
        ),
      ],
    );
  }
}
