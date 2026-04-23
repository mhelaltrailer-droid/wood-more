import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_persistence.dart';
import '../services/route_persistence.dart';
import '../services/route_restore.dart';
import '../core/route_observer.dart';
import 'attendance_screen.dart';
import 'attendance_reports_screen.dart';
import 'reports_screen.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_project_structure_screen.dart';
import 'contractor_report_screen.dart';
import 'engineer_projects_screen.dart';
import 'engineer_withdraw_materials_screen.dart';
import 'detailed_report_screen.dart';
import 'site_engineer_finances_entry_screen.dart';
import 'tomorrow_work_plan_screen.dart';
import 'today_work_plan_screen.dart';
import 'aggregated_detailed_daily_report_screen.dart';
import 'accountant_custody_screen.dart';
import 'accountant_finance_screen.dart';
import 'activity_logs_screen.dart';
import 'daily_movement_screen.dart';
import 'new_icon_screen.dart';
import 'operation_reports_screen.dart';
import 'operation_reports_tracking_screen.dart';
import 'login_screen.dart';

/// الصفحة الرئيسية - تختلف حسب دور المستخدم
class HomeScreen extends StatefulWidget {
  final UserModel currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      RouteObserverProvider.routeObserver.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void dispose() {
    RouteObserverProvider.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    saveLastRoute('home');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.forest, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Wood & More'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await clearCurrentUser();
              await clearLastRoute();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: currentUser.isSiteEngineer
          ? _EngineerHome(user: currentUser)
          : currentUser.isAccountant
              ? _AccountantHome(user: currentUser)
              : _ManagerHome(user: currentUser),
    );
  }
}

/// واجهة الصفحة الرئيسية للمهندس - تظهر أيقونة الحضور
class _EngineerHome extends StatelessWidget {
  final UserModel user;

  const _EngineerHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'مرحباً، ${user.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          // تسجيل الحضور والانصراف → خطة عمل اليوم → خطة عمل الغد → المخزن → الماليات → تقارير التشغيل → التقرير اليومي → المشروعات
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'attendance', AttendanceScreen(currentUser: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF0D3B0D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 80,
                    color: Colors.white.withOpacity(0.95),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تسجيل الحضور والانصراف',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اضغط للتسجيل',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'today-work-plan', TodayWorkPlanScreen(user: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.today, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'خطة عمل اليوم',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'عرض خطة اليوم حسب التاريخ لنفس مهندس الموقع (قراءة فقط)',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'tomorrow-work-plan', TomorrowWorkPlanScreen(user: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_note, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'خطة عمل الغد',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نسخة مطابقة حاليا لخطوات التقرير المفصل لحين تخصيصها',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'engineer-withdraw-materials', EngineerWithdrawMaterialsScreen(user: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.warehouse, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'المخزن (سحب الخامات)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'عرض الخامات المتاحة للسحب لكل مكان فرعي وإتمام السحب مع أذن الصرف والتسليم',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'engineer-finances', SiteEngineerFinancesEntryScreen(user: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.payments_outlined, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'الماليات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نفس واجهة الصرف الأربعة والرصيد (على تقرير محفوظ أو مسار كامل جديد)',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'operation-reports', OperationReportsScreen(user: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.fact_check_outlined, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'تقارير التشغيل',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'معاينة، إثبات حالة، تلفيات مع إرفاق الصور',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(
                context,
                'detailed-report',
                DetailedReportScreen(user: user, continueToFinancesOnNext: false),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.assessment_outlined, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'التقرير اليومي',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تفاصيل العمل والمواقع ثم «حفظ التقرير» — الماليات من أيقونة «الماليات»',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'engineer-projects', EngineerProjectsScreen(user: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.business, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'المشروعات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'عرض التشوينات والنماذج والقطعيات حسب المبنى',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'مهندس موقع',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// واجهة الصفحة الرئيسية للمحاسب: العهدة + الماليات فقط
class _AccountantHome extends StatelessWidget {
  final UserModel user;

  const _AccountantHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'مرحباً، ${user.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'accountant-custody', AccountantCustodyScreen(currentUser: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.handshake, size: 64, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 16),
                  const Text(
                    'العهدة',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تقرير العهدة حسب المستخدم والمدة وتصدير PDF',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'accountant-finance', AccountantFinanceScreen(currentUser: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet, size: 64, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 16),
                  const Text(
                    'الماليات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أرصدة المستخدمين، إضافة/سحب رصيد، وإنشاء تقرير',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// واجهة الصفحة الرئيسية لمدير المهندسين ومسؤول التطبيق
class _ManagerHome extends StatelessWidget {
  final UserModel user;

  const _ManagerHome({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'مرحباً، ${user.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          // بطاقة تقارير الحضور
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'attendance-reports', AttendanceReportsScreen(currentUser: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: const Color(0xFF1B5E20),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تقارير الحضور والانصراف',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'عرض سجلات جميع المهندسين',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF1B5E20).withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(
                context,
                'new-icon',
                NewIconScreen(currentUser: user),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.auto_graph, size: 64, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 16),
                  const Text(
                    'New icon',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ملخص خطة اليوم + جاهزية خطة الغد لمدير المهندسين',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedOperationTrackingCard(user: user),
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            if (user.canViewActivityLogs)
              InkWell(
                onTap: () async {
                  await pushAndSaveRoute(
                    context,
                    'daily-movement',
                    DailyMovementScreen(currentUser: user),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.insights, size: 64, color: const Color(0xFF1B5E20)),
                      const SizedBox(height: 16),
                      const Text(
                        'الحركة اليومية',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ملخص يومي لتنفيذ/تعديل/تأجيل الخطط',
                        style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            if (user.canViewActivityLogs) const SizedBox(height: 20),
            // بطاقة التقارير (التقارير اليومية) - لمسؤول التطبيق فقط
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(context, 'reports', ReportsScreen(currentUser: user));
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.summarize,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'التقارير',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تقارير يومية حسب المهندس والتاريخ والمشروع',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF1B5E20).withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(
                context,
                'aggregated-detailed-daily',
                AggregatedDetailedDailyReportScreen(currentUser: user),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.table_rows, size: 64, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 16),
                  const Text(
                    'التقرير اليومي المجمع',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'من التقارير المفصّلة: مشروع، مهندس، مقاول، عمال، موقع، سحب خامات بنفس اليوم',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              await pushAndSaveRoute(context, 'contractor-report', ContractorReportScreen(admin: user));
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.engineering, size: 64, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 16),
                  const Text(
                    'تقارير المقاول',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تقرير حسب اسم المقاول والفترة مع المشاريع وعدد العمال',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProjectStructureScreen(admin: user))),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.account_tree, size: 64, color: const Color(0xFF1B5E20)),
                    const SizedBox(height: 16),
                    const Text('هيكلة المشروعات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('هيكل مواقع المشروع: مواقع فرعية ومواقع عمل (للتقرير المفصل)', style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'admin-dashboard',
                  AdminDashboardScreen(currentUser: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF0D3B0D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 64, color: Colors.white.withOpacity(0.95)),
                    const SizedBox(height: 16),
                    const Text(
                      'لوح التحكم',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إدارة المستخدمين والمشروعات والمناطق والمباني والخامات',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            if (user.canViewActivityLogs)
              InkWell(
                onTap: () async {
                  await pushAndSaveRoute(
                    context,
                    'activity-logs',
                    ActivityLogsScreen(currentUser: user),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1B5E20).withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.manage_search, size: 64, color: const Color(0xFF1B5E20)),
                      const SizedBox(height: 16),
                      const Text(
                        'سجل الحركة',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'رصد كل الحركات على النظام خلال مدة محددة',
                        style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            if (user.canViewActivityLogs) const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(context, 'dashboard', const DashboardScreen());
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF0D3B0D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.dashboard, size: 64, color: Colors.white.withOpacity(0.95)),
                    const SizedBox(height: 16),
                    const Text(
                      'Management Dashboard',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fast daily visibility: progress, issues, and missing reports.',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _AnimatedOperationTrackingCard extends StatefulWidget {
  final UserModel user;

  const _AnimatedOperationTrackingCard({required this.user});

  @override
  State<_AnimatedOperationTrackingCard> createState() => _AnimatedOperationTrackingCardState();
}

class _AnimatedOperationTrackingCardState extends State<_AnimatedOperationTrackingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        final glowOpacity = 0.18 + (0.14 * t);
        final scale = 1.0 + (0.018 * t);
        final dy = -2.0 * t;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'operation-reports-tracking',
                  OperationReportsTrackingScreen(currentUser: widget.user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withOpacity(glowOpacity),
                      blurRadius: 14 + (8 * t),
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.fact_check, size: 64, color: Colors.white.withOpacity(0.95)),
                    const SizedBox(height: 16),
                    const Text(
                      'متابعة تقارير التشغيل',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'متابعة كل أنواع التقارير وحالة كل تقرير في دورة المراجعة',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.92)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
