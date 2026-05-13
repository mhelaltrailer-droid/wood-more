import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/detailed_report_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';
import 'detailed_report_screen.dart';

class TodayWorkPlanScreen extends StatefulWidget {
  final UserModel user;

  const TodayWorkPlanScreen({super.key, required this.user});

  @override
  State<TodayWorkPlanScreen> createState() => _TodayWorkPlanScreenState();
}

class _TodayWorkPlanScreenState extends State<TodayWorkPlanScreen> {
  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateFromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'غير محدد';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _fmtDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  final _db = getStorage();
  late DateTime _selectedDate;
  bool _loading = false;
  List<UserModel> _siteEngineers = [];
  UserModel? _selectedPlanOwner;

  int get _planOwnerUserId =>
      widget.user.canManageAnySiteWorkPlan && _selectedPlanOwner != null
      ? _selectedPlanOwner!.id
      : widget.user.id;

  static DateTime _todayOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _todayOnly();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.user.canManageAnySiteWorkPlan) {
        try {
          final list = await _db.getSiteEngineers();
          if (mounted) {
            setState(() {
              _siteEngineers = list;
              if (_selectedPlanOwner == null && list.isNotEmpty) {
                _selectedPlanOwner = list.first;
              }
            });
          }
        } catch (_) {}
      }
      if (mounted) await _loadPlan(silentIfEmpty: true);
    });
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'تم التنفيذ';
      case 'confirmed_edited':
        return 'تم التنفيذ بعد تعديل';
      case 'postponed':
        return 'تم التأجيل';
      default:
        return 'بانتظار الإجراء';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'confirmed_edited':
        return Colors.blue;
      case 'postponed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<Map<int, Map<String, String?>>> _loadPlanStatuses(
    List<DetailedReportModel> reports,
  ) async {
    final out = <int, Map<String, String?>>{};
    if (_db is! ApiStorageService) return out;
    final api = _db;
    for (final r in reports) {
      if (r.id == null) continue;
      try {
        final latest = await api.getLatestExecutedPlanStatus(
          sourcePlanId: r.id!,
          userId: r.userId,
        );
        final status = latest?['status']?.toString();
        String? postponeText;
        if (status == 'postponed') {
          final reasonLabel = latest?['postpone_reason_label']?.toString();
          final reasonCustom = latest?['postpone_custom_reason']?.toString();
          final reasonNotes = latest?['postpone_notes']?.toString();
          final reopenDate = latest?['postpone_reopen_date']?.toString();
          postponeText =
              (reasonCustom != null && reasonCustom.trim().isNotEmpty)
              ? 'تم التأجيل: ${reasonCustom.trim()}'
              : 'تم التأجيل: ${reasonLabel ?? 'سبب غير محدد'}';
          if (reopenDate != null && reopenDate.trim().isNotEmpty) {
            postponeText =
                '$postponeText\nتاريخ إعادة الفتح: ${_fmtDateFromString(reopenDate)}';
          }
          if (reasonNotes != null && reasonNotes.trim().isNotEmpty) {
            postponeText = '$postponeText\nملاحظات: ${reasonNotes.trim()}';
          }
        }
        out[r.id!] = {
          'status': status,
          'modificationSummary': latest?['modification_summary']?.toString(),
          'postponedReasonText': postponeText,
          'postponeReopenDate': latest?['postpone_reopen_date']?.toString(),
          'sourcePlanDate': latest?['plan_date']?.toString(),
        };
      } catch (_) {}
    }
    return out;
  }

  Future<DetailedReportModel?> _pickPlanFromList(
    List<DetailedReportModel> reports,
    Map<int, Map<String, String?>> statuses,
  ) async {
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
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'اختر الخطة المراد عرضها',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text('عدد الخطط: ${reports.length}'),
                const Divider(height: 20),
                Expanded(
                  child: ListView.separated(
                    itemCount: reports.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = reports[i];
                      final details = p.id != null ? statuses[p.id!] : null;
                      final status = details?['status'];
                      final color = _statusColor(status);
                      final projectName =
                          (p.projectName != null &&
                              p.projectName!.trim().isNotEmpty)
                          ? p.projectName!.trim()
                          : (p.projectId != null
                                ? 'مشروع #${p.projectId}'
                                : 'مشروع غير محدد');
                      return ListTile(
                        onTap: () => Navigator.of(ctx).pop(p),
                        title: Text(
                          projectName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'تاريخ التنفيذ: ${fmt.format(p.reportDatetime)}',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: color.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
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

  Future<void> _pickOtherDateAndLoad() async {
    final t = _todayOnly();
    final yesterday = t.subtract(const Duration(days: 1));
    final tomorrow = t.add(const Duration(days: 1));
    var initial = _selectedDate;
    if (initial.isBefore(yesterday)) initial = yesterday;
    if (initial.isAfter(tomorrow)) initial = tomorrow;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: yesterday,
      lastDate: tomorrow,
    );
    if (picked == null) return;
    setState(
      () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
    );
    await _loadPlan(silentIfEmpty: false);
  }

  Future<void> _loadPlan({bool silentIfEmpty = false}) async {
    setState(() => _loading = true);
    try {
      final reports = await _db.getDetailedReports(
        dateFrom: _selectedDate,
        dateTo: _selectedDate,
        userId: _planOwnerUserId,
      );
      final syntheticBySourceId = <int, DetailedReportModel>{};
      if (_db is ApiStorageService) {
        try {
          final reopened = await _db.getPostponedReopenedPlans(
            reopenDate: _selectedDate,
            userId: _planOwnerUserId,
          );
          for (final item in reopened) {
            final sourcePlanIdRaw = item['source_plan_id'];
            final sourcePlanId = sourcePlanIdRaw is int
                ? sourcePlanIdRaw
                : int.tryParse('$sourcePlanIdRaw');
            final planMapRaw = item['plan'];
            if (sourcePlanId == null || planMapRaw is! Map) continue;
            final planMap = Map<String, dynamic>.from(planMapRaw);
            final cloned = DetailedReportModel.fromMap(planMap);
            syntheticBySourceId[sourcePlanId] = DetailedReportModel(
              id: sourcePlanId,
              userId: cloned.userId,
              userName: cloned.userName,
              reportDatetime: _selectedDate,
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
      final mergedReports = <DetailedReportModel>[
        ...reports,
        ...syntheticBySourceId.entries
            .where((entry) => !reports.any((r) => r.id == entry.key))
            .map((entry) => entry.value),
      ];
      if (!mounted) return;
      if (mergedReports.isEmpty) {
        if (!silentIfEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.user.canManageAnySiteWorkPlan
                    ? 'لا توجد خطة مسجلة لهذا التاريخ للمهندس المحدد'
                    : 'لا توجد خطة مسجلة لهذا التاريخ لنفس مهندس الموقع',
              ),
            ),
          );
        }
        return;
      }
      final statuses = await _loadPlanStatuses(mergedReports);
      DetailedReportModel? sourcePlan;
      if (mergedReports.length == 1) {
        sourcePlan = mergedReports.first;
      } else {
        sourcePlan = await _pickPlanFromList(mergedReports, statuses);
        if (sourcePlan == null) return;
      }
      final selectedPlan = sourcePlan;
      final selectedStatus = selectedPlan.id != null
          ? statuses[selectedPlan.id!]
          : null;
      final initialExecutionStatus = selectedStatus?['status'];
      final initialPostponedReasonText = selectedStatus?['postponedReasonText'];
      final initialModificationSummary = selectedStatus?['modificationSummary'];
      final reopenDate = selectedStatus?['postponeReopenDate'];
      final sourcePlanDate = selectedStatus?['sourcePlanDate'];
      String? executionInfoMessage;
      if ((initialExecutionStatus == 'postponed') &&
          reopenDate != null &&
          _fmtDateFromString(reopenDate) == _fmtDate(_selectedDate)) {
        final reasonText = (initialPostponedReasonText ?? '')
            .split('\n')
            .where((line) => !line.trim().startsWith('تاريخ إعادة الفتح:'))
            .join('\n')
            .trim();
        executionInfoMessage =
            'الخطة مؤجلة من يوم (${_fmtDateFromString(sourcePlanDate)}) ليوم (${_fmtDate(_selectedDate)}) . السبب ${reasonText.isEmpty ? 'غير محدد' : reasonText}';
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetailedReportScreen(
            user: widget.user,
            appBarTitle: 'خطة عمل اليوم',
            showSummaryField: true,
            summaryFieldLabel: 'تفاصيل خطة العمل',
            summaryMaxLines: 6,
            showAttachmentsSection: false,
            showPlannedExecutionDate: true,
            showCraftsmanAndAssistantCounts: true,
            readOnly: true,
            showExecutionActions: true,
            initialReport: selectedPlan,
            initialExecutionStatus: initialExecutionStatus,
            initialPostponedReasonText: initialPostponedReasonText,
            initialModificationSummary: initialModificationSummary,
            executionInfoMessage: executionInfoMessage,
            onExecutionSubmit:
                ({
                  required DetailedReportModel plan,
                  required String action,
                  String? modificationSummary,
                  String? postponeReasonKey,
                  String? postponeReasonLabel,
                  String? postponeCustomReason,
                  String? postponeNotes,
                  DateTime? postponeReopenDate,
                  String? engineerFineTarget,
                }) async {
                  try {
                    if (_db is! ApiStorageService) {
                      throw Exception(
                        'حفظ الخطط المنفذة متاح عبر API فقط حالياً',
                      );
                    }
                    final status = action == 'postponed'
                        ? 'postponed'
                        : (action == 'confirmed_edited'
                              ? 'confirmed_edited'
                              : 'confirmed');
                    await _db.addExecutedPlan(
                      plan: plan,
                      userId: selectedPlan.userId,
                      userName: selectedPlan.userName,
                      planDate: plan.reportDatetime,
                      status: status,
                      sourcePlanId: selectedPlan.id,
                      modificationSummary: modificationSummary,
                      postponeReasonKey: postponeReasonKey,
                      postponeReasonLabel: postponeReasonLabel,
                      postponeCustomReason: postponeCustomReason,
                      postponeNotes: postponeNotes,
                      postponeReopenDate: postponeReopenDate,
                      engineerFineTarget: engineerFineTarget,
                    );
                    return true;
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تعذر حفظ التنفيذ: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return false;
                  }
                },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء تحميل الخطة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('yyyy/MM/dd').format(_selectedDate);
    final t = _todayOnly();
    final yesterday = t.subtract(const Duration(days: 1));
    final tomorrow = t.add(const Duration(days: 1));
    final isToday =
        _selectedDate.year == t.year &&
        _selectedDate.month == t.month &&
        _selectedDate.day == t.day;
    final isYesterday =
        _selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day;
    final isTomorrow =
        _selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('خطة عمل اليوم'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.user.canManageAnySiteWorkPlan &&
                _siteEngineers.isNotEmpty) ...[
              DropdownButtonFormField<UserModel>(
                value: _selectedPlanOwner,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'مهندس الموقع (الخطة)',
                  border: OutlineInputBorder(),
                  helperText: 'صلاحية خاصة: عرض وتعديل وحذف خطط أي مهندس',
                ),
                items: _siteEngineers
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _loading
                    ? null
                    : (u) async {
                        if (u == null) return;
                        setState(() => _selectedPlanOwner = u);
                        await _loadPlan(silentIfEmpty: false);
                      },
              ),
              const SizedBox(height: 12),
            ] else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('اسم مهندس الموقع'),
                subtitle: Text(
                  widget.user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'التاريخ',
                      border: const OutlineInputBorder(),
                      helperText: isToday
                          ? 'الافتراضي: اليوم — يمكنك اختيار أمس أو اليوم أو الغد'
                          : (isYesterday
                                ? 'تم اختيار الأمس'
                                : (isTomorrow ? 'تم اختيار الغد' : '')),
                    ),
                    child: Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _loading ? null : _pickOtherDateAndLoad,
                  child: const Text('تغيير'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading
                  ? null
                  : () => _loadPlan(silentIfEmpty: false),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_loading ? 'جاري التحميل...' : 'تحديث وعرض الخطة'),
            ),
          ],
        ),
      ),
    );
  }
}
