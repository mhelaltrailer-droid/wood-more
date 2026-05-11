import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/detailed_report_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import 'detailed_report_finances_screen.dart';
import 'detailed_report_screen.dart';

// مستقبلاً: عرض بنود الصرف لكل «خطة عمل اليوم» ضمن «تقرير متابعة خطط الأعمال» لواجهة مدير المشروعات.

/// «الماليات» لمهندس الموقع: اختيار تاريخ مرتبط بخطة العمل المحفوظة → عرض الخطة للقراءة فقط → التالي → بنود الصرف.
class SiteEngineerFinancesEntryScreen extends StatefulWidget {
  final UserModel user;

  const SiteEngineerFinancesEntryScreen({super.key, required this.user});

  @override
  State<SiteEngineerFinancesEntryScreen> createState() => _SiteEngineerFinancesEntryScreenState();
}

class _SiteEngineerFinancesEntryScreenState extends State<SiteEngineerFinancesEntryScreen> {
  final _db = getStorage();
  late DateTime _selectedDate;
  bool _loading = false;

  static DateTime _todayOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _minSelectable() => _todayOnly().subtract(const Duration(days: 3));

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayOnly();
  }

  Future<void> _pickDate() async {
    final t = _todayOnly();
    final minD = _minSelectable();
    final lastDate = DateTime(t.year + 2, 12, 31);
    var initial = _selectedDate;
    if (initial.isBefore(minD)) initial = minD;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minD,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<List<DetailedReportModel>> _fetchPlansForDate(DateTime day) async {
    final reports = await _db.getDetailedReports(
      dateFrom: day,
      dateTo: day,
      userId: widget.user.id,
    );
    final syntheticBySourceId = <int, DetailedReportModel>{};
    if (_db is ApiStorageService) {
      try {
        final reopened = await _db.getPostponedReopenedPlans(
          reopenDate: day,
          userId: widget.user.id,
        );
        for (final item in reopened) {
          final sourcePlanIdRaw = item['source_plan_id'];
          final sourcePlanId = sourcePlanIdRaw is int ? sourcePlanIdRaw : int.tryParse('$sourcePlanIdRaw');
          final planMapRaw = item['plan'];
          if (sourcePlanId == null || planMapRaw is! Map) continue;
          final planMap = Map<String, dynamic>.from(planMapRaw);
          final cloned = DetailedReportModel.fromMap(planMap);
          syntheticBySourceId[sourcePlanId] = DetailedReportModel(
            id: sourcePlanId,
            userId: cloned.userId,
            userName: cloned.userName,
            reportDatetime: day,
            projectId: cloned.projectId,
            projectName: cloned.projectName,
            supervisorId: cloned.supervisorId,
            createdAt: cloned.createdAt,
            summary: cloned.summary,
            lines: cloned.lines,
            expenses: cloned.expenses,
            attachments: cloned.attachments,
          );
        }
      } catch (_) {}
    }
    return [
      ...reports,
      ...syntheticBySourceId.entries
          .where((entry) => !reports.any((r) => r.id == entry.key))
          .map((e) => e.value),
    ];
  }

  Future<DetailedReportModel?> _pickPlanFromList(List<DetailedReportModel> reports) async {
    final fmt = DateFormat('yyyy-MM-dd');
    return showModalBottomSheet<DetailedReportModel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.72,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 10),
                const Text('اختر خطة العمل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('عدد الخطط: ${reports.length}'),
                const Divider(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = reports[i];
                      final projectName = (p.projectName != null && p.projectName!.trim().isNotEmpty)
                          ? p.projectName!.trim()
                          : (p.projectId != null ? 'مشروع #${p.projectId}' : 'مشروع غير محدد');
                      return ListTile(
                        onTap: () => Navigator.of(ctx).pop(p),
                        title: Text(projectName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('تاريخ التنفيذ: ${fmt.format(p.reportDatetime)}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openReadOnlyPlanThenFinances(DetailedReportModel plan) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => DetailedReportScreen(
          user: widget.user,
          appBarTitle: 'خطة العمل — عرض',
          showSummaryField: true,
          summaryFieldLabel: 'تفاصيل خطة العمل',
          summaryMaxLines: 6,
          showAttachmentsSection: false,
          showPlannedExecutionDate: true,
          showCraftsmanAndAssistantCounts: true,
          readOnly: true,
          showExecutionActions: false,
          initialReport: plan,
          continueToFinancesOnNext: false,
          onReadOnlyProceedToFinances: (c) async {
            await Navigator.of(c).push<void>(
              MaterialPageRoute(
                builder: (_) => DetailedReportFinancesScreen(user: widget.user, report: plan),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _loadAndShowPlan() async {
    setState(() => _loading = true);
    try {
      final merged = await _fetchPlansForDate(_selectedDate);
      if (!mounted) return;
      if (merged.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد خطة محفوظة لهذا التاريخ لنفس مهندس الموقع')),
        );
        return;
      }
      DetailedReportModel? chosen;
      if (merged.length == 1) {
        chosen = merged.first;
      } else {
        chosen = await _pickPlanFromList(merged);
        if (chosen == null) return;
      }
      await _openReadOnlyPlanThenFinances(chosen);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy/MM/dd').format(_selectedDate);
    final t = _todayOnly();
    final isToday = _selectedDate.year == t.year && _selectedDate.month == t.month && _selectedDate.day == t.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الماليات — خطة عمل اليوم'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'اختر تاريخ تنفيذ الخطة المحفوظة. يُعرض اليوم افتراضياً؛ يمكن الرجوع حتى ثلاثة أيام مضت أو اختيار أي يوم لاحق. الخطة تُعرض للقراءة فقط، ثم «التالي» لبنود الصرف وخصم الرصيد.',
            style: TextStyle(fontSize: 15, height: 1.35),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('اسم مهندس الموقع'),
            subtitle: Text(widget.user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ خطة العمل',
                    border: const OutlineInputBorder(),
                    helperText: isToday
                        ? 'الافتراضي: اليوم — مسموح: 3 أيام مضت حتى أي يوم لاحق'
                        : 'مسموح: من ${_minSelectable().year}/${_minSelectable().month}/${_minSelectable().day} فما بعد',
                  ),
                  child: Text(dateText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _loading ? null : _pickDate,
                child: const Text('تغيير'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _loadAndShowPlan,
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.visibility),
            label: Text(_loading ? 'جاري التحميل...' : 'عرض الخطة المحفوظة'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
