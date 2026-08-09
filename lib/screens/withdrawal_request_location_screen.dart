import 'package:flutter/material.dart';

import '../models/location_material_model.dart';
import '../models/withdrawal_request_model.dart';
import '../services/storage_service.dart';
import '../utils/notification_time_display.dart';
import '../utils/withdrawal_request_action_display.dart';

/// عرض مكان العمل الخاص بطلب سحب خامات — للقراءة فقط (بدون أي إجراء).
class WithdrawalRequestLocationScreen extends StatefulWidget {
  final WithdrawalRequestModel request;

  const WithdrawalRequestLocationScreen({super.key, required this.request});

  @override
  State<WithdrawalRequestLocationScreen> createState() =>
      _WithdrawalRequestLocationScreenState();
}

class _WithdrawalRequestLocationScreenState
    extends State<WithdrawalRequestLocationScreen> {
  final _db = getStorage();
  List<LocationMaterialModel> _materials = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _db.getLocationMaterials(
        widget.request.locationId,
        phase: widget.request.phase,
      ) as List<LocationMaterialModel>;
      if (!mounted) return;
      setState(() {
        _materials = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مكان العمل — طلب سحب خامات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMaterials,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _requestCard(),
            const SizedBox(height: 16),
            _decisionsCard(),
            const SizedBox(height: 16),
            _materialsCard(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) => Row(
        children: [
          Icon(icon, color: const Color(0xFF1B5E20)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  Widget _requestCard() {
    final r = widget.request;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('بيانات الطلب', Icons.description_outlined),
            const SizedBox(height: 12),
            _row('رقم الطلب', '${r.id}'),
            _row('المهندس', r.engineerUserName),
            _row('المشروع', r.projectName ?? 'مشروع #${r.projectId}'),
            _row('مكان العمل', r.locationPathLabel.isEmpty ? '—' : r.locationPathLabel),
            _row('المرحلة', LocationMaterialModel.phaseLabel(r.phase)),
            _row('تاريخ ووقت الإرسال', formatNotificationDateTime(r.createdAt)),
            if (r.fulfilledAt != null)
              _row('تم إتمام السحب', formatNotificationDateTime(r.fulfilledAt!)),
          ],
        ),
      ),
    );
  }

  Widget _decisionsCard() {
    final r = widget.request;
    final semLine = withdrawalOwnActionLine(r, withdrawalRoleSem);
    final omLine = withdrawalOwnActionLine(r, withdrawalRoleOm);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('سجل القرارات', Icons.fact_check_outlined),
            const SizedBox(height: 12),
            Text(
              'مدير المشروعات: ${semLine ?? 'لم يتخذ قراراً بعد'}',
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'مدير العمليات: ${omLine ?? 'لم يتخذ قراراً بعد'}',
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _materialsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('الخامات المطلوبة', Icons.inventory_2_outlined),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                'تعذر تحميل الخامات',
                style: TextStyle(color: Colors.red.shade700),
              )
            else if (_materials.isEmpty)
              const Text('لا توجد خامات مسجلة لهذا المكان في هذه المرحلة')
            else
              ..._materials.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Color(0xFF1B5E20)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m.materialName)),
                      Text(
                        '${m.quantity} ${m.unit}'.trim(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
