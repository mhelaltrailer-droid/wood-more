import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/operation_reports_store.dart';

class OperationReportsTrackingScreen extends StatefulWidget {
  final UserModel currentUser;

  const OperationReportsTrackingScreen({super.key, required this.currentUser});

  @override
  State<OperationReportsTrackingScreen> createState() => _OperationReportsTrackingScreenState();
}

class _OperationReportsTrackingScreenState extends State<OperationReportsTrackingScreen> {
  late Future<void> _loadFuture;
  String _typeFilter = 'الكل';
  String _statusFilter = 'الكل';

  static const List<String> _types = ['الكل', 'تقرير معاينة', 'تقرير إثبات حالة', 'تقرير تلفيات'];
  static const List<String> _statuses = [
    'الكل',
    'مرسل',
    'تحت المراجعة',
    'بانتظار المدير',
    'معتمد',
    'مرفوض',
    'مرتجع للتعديل',
  ];

  List<OperationTrackingReport> _applyFilters(List<OperationTrackingReport> allRows) {
    return allRows.where((row) {
      final typeOk = _typeFilter == 'الكل' || row.reportType == _typeFilter;
      final statusOk = _statusFilter == 'الكل' || row.status == _statusFilter;
      return typeOk && statusOk;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFuture = OperationReportsStore.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('متابعة تقارير التشغيل'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              setState(() {
                _loadFuture = OperationReportsStore.ensureLoaded(force: true);
              });
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<List<OperationTrackingReport>>(
            valueListenable: OperationReportsStore.reports,
            builder: (context, allRows, _) {
              final rows = _applyFilters(allRows);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(rows: rows, total: allRows.length),
                  const SizedBox(height: 12),
                  _FiltersCard(
                    typeFilter: _typeFilter,
                    statusFilter: _statusFilter,
                    types: _types,
                    statuses: _statuses,
                    onTypeChanged: (value) => setState(() => _typeFilter = value),
                    onStatusChanged: (value) => setState(() => _statusFilter = value),
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('لا توجد تقارير مطابقة للفلاتر الحالية'),
                        ),
                      ),
                    )
                  else
                    ...rows.map((row) => _ReportTile(row: row)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<OperationTrackingReport> rows;
  final int total;

  const _SummaryCard({required this.rows, required this.total});

  @override
  Widget build(BuildContext context) {
    int countByStatus(String status) => rows.where((r) => r.status == status).length;

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص سريع',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('الإجمالي: $total', Colors.blueGrey),
                _chip('تحت المراجعة: ${countByStatus('تحت المراجعة')}', const Color(0xFF1565C0)),
                _chip('بانتظار المدير: ${countByStatus('بانتظار المدير')}', const Color(0xFF6A1B9A)),
                _chip('معتمد: ${countByStatus('معتمد')}', const Color(0xFF2E7D32)),
                _chip('مرفوض: ${countByStatus('مرفوض')}', const Color(0xFFC62828)),
                _chip('مرتجع: ${countByStatus('مرتجع للتعديل')}', const Color(0xFFEF6C00)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final String typeFilter;
  final String statusFilter;
  final List<String> types;
  final List<String> statuses;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onStatusChanged;

  const _FiltersCard({
    required this.typeFilter,
    required this.statusFilter,
    required this.types,
    required this.statuses,
    required this.onTypeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: typeFilter,
              decoration: const InputDecoration(
                labelText: 'نوع التقرير',
                border: OutlineInputBorder(),
              ),
              items: types.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value != null) onTypeChanged(value);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: statusFilter,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                border: OutlineInputBorder(),
              ),
              items: statuses.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value != null) onStatusChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final OperationTrackingReport row;

  const _ReportTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final submittedAt = row.submittedAtIso != null ? DateTime.tryParse(row.submittedAtIso!) : null;
    final isNew = submittedAt != null && now.difference(submittedAt).inHours < 24;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isNew ? const Color(0xFFE8F5E9) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        title: Row(
          children: [
            Expanded(
              child: Text('${row.reportNo} - ${row.reportType}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (isNew)
              Container(
                margin: const EdgeInsetsDirectional.only(start: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'جديد',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المشروع: ${row.projectName}'),
              Text('المهندس: ${row.engineerName}'),
              Text('المرحلة الحالية: ${row.stage}'),
              Text('التاريخ: ${row.dateText}'),
            ],
          ),
        ),
        trailing: _StatusBadge(status: row.status),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'معتمد' => const Color(0xFF2E7D32),
      'مرفوض' => const Color(0xFFC62828),
      'مرتجع للتعديل' => const Color(0xFFEF6C00),
      'بانتظار المدير' => const Color(0xFF6A1B9A),
      'تحت المراجعة' => const Color(0xFF1565C0),
      _ => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
