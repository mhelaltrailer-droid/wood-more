import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/detailed_report_model.dart';
import '../models/project_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';
import '../services/storage_service.dart';

class NewIconScreen extends StatefulWidget {
  final UserModel currentUser;

  const NewIconScreen({super.key, required this.currentUser});

  @override
  State<NewIconScreen> createState() => _NewIconScreenState();
}

class _NewIconScreenState extends State<NewIconScreen> {
  final _db = getStorage();
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;

  int _confirmed = 0;
  int _edited = 0;
  int _postponed = 0;
  int _totalTodayPlans = 0;
  int _tomorrowPlansCount = 0;
  int _projectsWithoutTomorrowPlan = 0;
  List<_ProjectExecutionItem> _projectItems = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final today = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final tomorrow = today.add(const Duration(days: 1));

      final List<DetailedReportModel> todayPlans = await _db.getDetailedReports(
        dateFrom: today,
        dateTo: today,
      );
      final List<DetailedReportModel> tomorrowPlans = await _db.getDetailedReports(
        dateFrom: tomorrow,
        dateTo: tomorrow,
      );
      final List<ProjectModel> projects = await _db.getProjects();

      int confirmed = 0;
      int edited = 0;
      int postponed = 0;
      final items = <_ProjectExecutionItem>[];

      if (_db is ApiStorageService) {
        final api = _db as ApiStorageService;
        for (final plan in todayPlans) {
          String status = 'pending';
          String? postponeReason;
          final sourcePlanId = plan.id;
          if (sourcePlanId != null) {
            final latest = await api.getLatestExecutedPlanStatus(
              sourcePlanId: sourcePlanId,
              userId: plan.userId,
            );
            status = latest?['status']?.toString() ?? 'pending';
            final reasonLabel = latest?['postpone_reason_label']?.toString();
            final reasonCustom = latest?['postpone_custom_reason']?.toString();
            postponeReason = (reasonCustom != null && reasonCustom.trim().isNotEmpty)
                ? reasonCustom.trim()
                : (reasonLabel != null && reasonLabel.trim().isNotEmpty ? reasonLabel.trim() : null);
          }
          if (status == 'confirmed') confirmed++;
          if (status == 'confirmed_edited') edited++;
          if (status == 'postponed') postponed++;
          items.add(
            _ProjectExecutionItem(
              projectName: _displayProjectName(plan),
              engineerName: plan.userName,
              status: status,
              postponeReason: postponeReason,
            ),
          );
        }
      } else {
        items.addAll(
          todayPlans.map(
            (plan) => _ProjectExecutionItem(
              projectName: _displayProjectName(plan),
              engineerName: plan.userName,
              status: 'pending',
              postponeReason: null,
            ),
          ),
        );
      }

      final tomorrowProjectIds = tomorrowPlans
          .map((e) => e.projectId)
          .whereType<int>()
          .toSet();
      final allProjectIds = projects.map((e) => e.id).toSet();
      final withoutPlan = allProjectIds.difference(tomorrowProjectIds).length;

      if (!mounted) return;
      setState(() {
        _confirmed = confirmed;
        _edited = edited;
        _postponed = postponed;
        _totalTodayPlans = todayPlans.length;
        _tomorrowPlansCount = tomorrowPlans.length;
        _projectsWithoutTomorrowPlan = withoutPlan;
        _projectItems = items;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحميل بيانات New icon: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _displayProjectName(DetailedReportModel plan) {
    final name = plan.projectName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (plan.projectId != null) return 'مشروع #${plan.projectId}';
    return 'غير محدد';
  }

  String _statusLabel(String status) {
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

  Color _statusColor(String status) {
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

  Widget _kpiCard({
    required String title,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 26)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('New icon'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'تقرير خطة اليوم: ${fmt.format(_selectedDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickDate,
                    icon: const Icon(Icons.date_range),
                    label: const Text('تغيير التاريخ'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _kpiCard(
                  title: 'تم التنفيذ',
                  value: _confirmed,
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
                _kpiCard(
                  title: 'تنفيذ + تعديل',
                  value: _edited,
                  color: Colors.blue,
                  icon: Icons.edit_note,
                ),
                _kpiCard(
                  title: 'تم التأجيل',
                  value: _postponed,
                  color: Colors.orange,
                  icon: Icons.pause_circle,
                ),
                _kpiCard(
                  title: 'إجمالي خطط اليوم',
                  value: _totalTodayPlans,
                  color: const Color(0xFF1B5E20),
                  icon: Icons.summarize,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'جاهزية خطة الغد',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text('عدد خطط الغد المسجلة: $_tomorrowPlansCount'),
                    const SizedBox(height: 4),
                    Text('عدد المشاريع بدون خطة غد: $_projectsWithoutTomorrowPlan'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل المشاريع (اليوم)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    if (_projectItems.isEmpty)
                      const Text('لا توجد خطط يومية في هذا التاريخ.')
                    else
                      ..._projectItems.map((item) {
                        final color = _statusColor(item.status);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.projectName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text('المهندس: ${item.engineerName}'),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.circle, size: 10, color: color),
                                  const SizedBox(width: 6),
                                  Text(_statusLabel(item.status)),
                                ],
                              ),
                              if (item.postponeReason != null && item.postponeReason!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('سبب التأجيل: ${item.postponeReason}'),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectExecutionItem {
  final String projectName;
  final String engineerName;
  final String status;
  final String? postponeReason;

  const _ProjectExecutionItem({
    required this.projectName,
    required this.engineerName,
    required this.status,
    required this.postponeReason,
  });
}
