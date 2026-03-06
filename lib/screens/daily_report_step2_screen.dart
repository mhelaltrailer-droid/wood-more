import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import '../services/storage_service.dart';
import 'daily_report_step3_screen.dart';

/// الخطوة 2: الخامات (5 تكرارات) — الخامة، الكمية، الوحدة
class DailyReportStep2Screen extends StatefulWidget {
  final UserModel user;
  final DailyReportData report;

  const DailyReportStep2Screen({super.key, required this.user, required this.report});

  @override
  State<DailyReportStep2Screen> createState() => _DailyReportStep2ScreenState();
}

class _DailyReportStep2ScreenState extends State<DailyReportStep2Screen> {
  final _db = getStorage();
  List<String> _materialsList = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final list = await _db.getMaterials();
    setState(() => _materialsList = list);
  }

  void _goNext() {
    final report = DailyReportData(
      userName: widget.report.userName,
      userId: widget.report.userId,
      projectId: widget.report.projectId,
      projectName: widget.report.projectName,
      reportDate: widget.report.reportDate,
      workPlace: widget.report.workPlace,
      workReport: widget.report.workReport,
      executedToday: widget.report.executedToday,
      supervisorName: widget.report.supervisorName,
      contractorName: widget.report.contractorName,
      workersCount: widget.report.workersCount,
      tomorrowPlan: widget.report.tomorrowPlan,
      documentPath: widget.report.documentPath,
      imagePaths: widget.report.imagePaths,
      notes: widget.report.notes,
      materials: widget.report.materials,
      expenses: widget.report.expenses,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyReportStep3Screen(user: widget.user, report: report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير اليومي - الخامات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'اختر الخامات والكميات والوحدات (حتى 5 أنواع)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (i) => _MaterialRow(
                index: i + 1,
                item: widget.report.materials[i],
                materialsList: _materialsList,
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _goNext,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF1B5E20),
            ),
            child: const Text('التالي'),
          ),
        ],
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  final int index;
  final MaterialItem item;
  final List<String> materialsList;
  final VoidCallback onChanged;

  const _MaterialRow({
    required this.index,
    required this.item,
    required this.materialsList,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الخامة $index', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (narrow) ...[
              _materialDropdown(),
              const SizedBox(height: 10),
              _quantityField(),
              const SizedBox(height: 10),
              _unitDropdown(),
            ] else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _materialDropdown(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _quantityField(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _unitDropdown(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _materialDropdown() {
    return DropdownButtonFormField<String>(
      value: item.materialName.isEmpty || !materialsList.contains(item.materialName) ? null : item.materialName,
      decoration: const InputDecoration(
        labelText: 'الخامة',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      selectedItemBuilder: (context) => [
        const Text('—', overflow: TextOverflow.ellipsis, maxLines: 1),
        ...materialsList.map((s) => Text(s, overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        ...materialsList.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis, maxLines: 1))),
      ],
      onChanged: (s) {
        item.materialName = s ?? '';
        onChanged();
      },
    );
  }

  Widget _quantityField() {
    return TextFormField(
      initialValue: item.quantity,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'الكمية',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (v) => item.quantity = v,
    );
  }

  Widget _unitDropdown() {
    return DropdownButtonFormField<String>(
      value: item.unit.isEmpty ? null : (materialUnits.contains(item.unit) ? item.unit : null),
      decoration: const InputDecoration(
        labelText: 'الوحدة',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      selectedItemBuilder: (context) => [
        const Text('—', overflow: TextOverflow.ellipsis, maxLines: 1),
        ...materialUnits.map((u) => Text(u, overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
      items: [
        const DropdownMenuItem(value: null, child: Text('—')),
        ...materialUnits.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis, maxLines: 1))),
      ],
      onChanged: (u) {
        item.unit = u ?? '';
        onChanged();
      },
    );
  }
}
