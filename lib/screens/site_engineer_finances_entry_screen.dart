import 'package:flutter/material.dart';
import '../models/detailed_report_model.dart';
import '../models/user_model.dart';
import '../services/route_restore.dart';
import '../services/storage_service.dart';
import 'detailed_report_finances_screen.dart';
import 'detailed_report_screen.dart';

double _expenseTotal(DetailedReportModel r) {
  double t = 0;
  for (final e in r.expenses) {
    t += double.tryParse(e.amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
  }
  return t;
}

/// نقطة دخول «الماليات» لمهندس الموقع: نفس [DetailedReportFinancesScreen] المرتبطة بتقرير اليوم أو التدفق الكامل (خطوة العمل ثم الماليات).
class SiteEngineerFinancesEntryScreen extends StatefulWidget {
  final UserModel user;

  const SiteEngineerFinancesEntryScreen({super.key, required this.user});

  @override
  State<SiteEngineerFinancesEntryScreen> createState() => _SiteEngineerFinancesEntryScreenState();
}

class _SiteEngineerFinancesEntryScreenState extends State<SiteEngineerFinancesEntryScreen> {
  final _db = getStorage();
  late Future<List<DetailedReportModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadToday();
  }

  Future<List<DetailedReportModel>> _loadToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final list = await _db.getDetailedReports(
      dateFrom: today,
      dateTo: today,
      userId: widget.user.id,
    );
    return list.where((r) => _expenseTotal(r) <= 0).toList();
  }

  Future<void> _openFullFlow() async {
    await pushAndSaveRoute(
      context,
      'detailed-report',
      DetailedReportScreen(user: widget.user),
    );
    if (!mounted) return;
    setState(() => _future = _loadToday());
  }

  Future<void> _openFinances(DetailedReportModel report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailedReportFinancesScreen(user: widget.user, report: report),
      ),
    );
    if (!mounted) return;
    setState(() => _future = _loadToday());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الماليات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<DetailedReportModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('تعذر التحميل: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final pending = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'بنود الصرف الأربعة وخصم الرصيد كما في التقرير اليومي. اختر تقرير اليوم الذي لم يُسجَّل له صرف بعد، أو أنشئ تقريراً جديداً مع الماليات.',
                style: TextStyle(fontSize: 15, height: 1.35),
              ),
              const SizedBox(height: 20),
              if (pending.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'لا يوجد تقرير مفصل لمهندس الموقع لهذا اليوم بانتظار إدخال الماليات.',
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _openFullFlow,
                          icon: const Icon(Icons.add_chart),
                          label: const Text('إنشاء تقرير مع الماليات (خطوتان)'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                const Text('تقارير اليوم بدون صرف مسجّل:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...pending.map(
                  (r) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1B5E20)),
                      title: Text(
                        r.projectName?.trim().isNotEmpty == true ? r.projectName! : 'مشروع',
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${r.reportDatetime.hour.toString().padLeft(2, '0')}:${r.reportDatetime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => _openFinances(r),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _openFullFlow,
                icon: const Icon(Icons.playlist_add),
                label: const Text('مسار كامل: تفاصيل العمل ثم الماليات'),
              ),
            ],
          );
        },
      ),
    );
  }
}
