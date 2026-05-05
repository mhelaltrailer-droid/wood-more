import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_persistence.dart';
import '../services/route_persistence.dart';
import '../services/route_restore.dart';
import '../services/storage_service.dart';
import '../services/api_storage_service.dart';
import '../services/icon_visibility_service.dart';
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
import 'work_plan_tracking_report_screen.dart';
import 'icons_control_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';

/// الصفحة الرئيسية - تختلف حسب دور المستخدم
class HomeScreen extends StatefulWidget {
  final UserModel currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  bool _subscribed = false;
  Map<String, bool>? _iconConfig;
  int _unreadNotificationsCount = 0;

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
    _loadIconsConfig();
    _loadUnreadNotificationsCount();
  }

  @override
  void initState() {
    super.initState();
    _loadIconsConfig();
    _loadUnreadNotificationsCount();
  }

  Future<void> _loadIconsConfig() async {
    try {
      final storage = getStorage();
      final role = widget.currentUser.role;
      final all = storage is ApiStorageService
          ? await storage.getHomeIconsVisibilityConfig()
          : await storage.getHomeIconsVisibilityConfig();
      if (!mounted) return;
      setState(() {
        _iconConfig = all[role] ?? IconVisibilityService.defaultForRole(role);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _iconConfig = IconVisibilityService.defaultForRole(
          widget.currentUser.role,
        );
      });
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    if (widget.currentUser.role != 'site_engineer_manager') {
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = 0);
      return;
    }
    try {
      final storage = getStorage();
      final count = storage is ApiStorageService
          ? await storage.getUnreadNotificationsCount(widget.currentUser.id)
          : await storage.getUnreadNotificationsCount(widget.currentUser.id);
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _unreadNotificationsCount = 0);
    }
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
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.forest, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Wood & More'),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        actions: [
          if (currentUser.role == 'site_engineer_manager')
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(currentUser: currentUser),
                  ),
                );
                await _loadUnreadNotificationsCount();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications),
                  if (_unreadNotificationsCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        child: Text(
                          _unreadNotificationsCount > 99
                              ? '99+'
                              : '$_unreadNotificationsCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
          ? _EngineerHome(user: currentUser, iconConfig: _iconConfig)
          : currentUser.isAccountant
          ? _AccountantHome(user: currentUser, iconConfig: _iconConfig)
          : _ManagerHome(user: currentUser, iconConfig: _iconConfig),
    );
  }
}

/// واجهة الصفحة الرئيسية للمهندس - تظهر أيقونة الحضور
class _EngineerHome extends StatelessWidget {
  final UserModel user;
  final Map<String, bool>? iconConfig;

  const _EngineerHome({required this.user, required this.iconConfig});

  Future<bool> _hasTodayCheckIn() async {
    final db = getStorage();
    final today = DateTime.now();
    final attendance = await db.getAttendanceForUserOnDate(user.id, today);
    return attendance.checkIn != null;
  }

  Future<void> _openAfterAttendanceCheck({
    required BuildContext context,
    required String routeName,
    required Widget screen,
  }) async {
    final hasCheckIn = await _hasTodayCheckIn();
    if (!context.mounted) return;
    if (!hasCheckIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب تسجيل الحضور اولا')));
      return;
    }
    await pushAndSaveRoute(context, routeName, screen);
  }

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
          if (IconVisibilityService.isVisible(iconConfig, 'attendance'))
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'attendance',
                  AttendanceScreen(currentUser: user),
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
          if (IconVisibilityService.isVisible(iconConfig, 'attendance'))
            const SizedBox(height: 24),
          if (IconVisibilityService.isVisible(iconConfig, 'today_work_plan'))
            InkWell(
              onTap: () async {
                await _openAfterAttendanceCheck(
                  context: context,
                  routeName: 'today-work-plan',
                  screen: TodayWorkPlanScreen(user: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.today, size: 56, color: const Color(0xFF1B5E20)),
                    const SizedBox(height: 12),
                    const Text(
                      'خطة عمل اليوم',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عرض خطة اليوم حسب التاريخ لنفس مهندس الموقع (قراءة فقط)',
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
          if (IconVisibilityService.isVisible(iconConfig, 'today_work_plan'))
            const SizedBox(height: 24),
          if (IconVisibilityService.isVisible(iconConfig, 'tomorrow_work_plan'))
            InkWell(
              onTap: () async {
                await _openAfterAttendanceCheck(
                  context: context,
                  routeName: 'tomorrow-work-plan',
                  screen: TomorrowWorkPlanScreen(user: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 56,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'خطة عمل الغد',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تسجيل خطة التنفيذ (غداً أو لاحقاً) مع توزيع العمال — حفظ مباشر دون خطوة الماليات',
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
          if (IconVisibilityService.isVisible(iconConfig, 'tomorrow_work_plan'))
            const SizedBox(height: 24),
          if (IconVisibilityService.isVisible(
            iconConfig,
            'engineer_withdraw_materials',
          ))
            InkWell(
              onTap: () async {
                await _openAfterAttendanceCheck(
                  context: context,
                  routeName: 'engineer-withdraw-materials',
                  screen: EngineerWithdrawMaterialsScreen(user: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warehouse,
                      size: 56,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'المخزن (سحب الخامات)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عرض الخامات المتاحة للسحب لكل مكان فرعي وإتمام السحب مع أذن الصرف والتسليم',
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
          if (IconVisibilityService.isVisible(
            iconConfig,
            'engineer_withdraw_materials',
          ))
            const SizedBox(height: 24),
          if (IconVisibilityService.isVisible(iconConfig, 'engineer_finances'))
            InkWell(
              onTap: () async {
                await _openAfterAttendanceCheck(
                  context: context,
                  routeName: 'engineer-finances',
                  screen: SiteEngineerFinancesEntryScreen(user: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 56,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'الماليات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'مرتبطة بخطة عمل اليوم: اختيار التاريخ → عرض الخطة (قراءة فقط) → بنود الصرف وخصم الرصيد',
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
          if (IconVisibilityService.isVisible(iconConfig, 'engineer_finances'))
            const SizedBox(height: 24),
          if (IconVisibilityService.isVisible(iconConfig, 'operation_reports'))
            InkWell(
              onTap: () async {
                await _openAfterAttendanceCheck(
                  context: context,
                  routeName: 'operation-reports',
                  screen: OperationReportsScreen(user: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 56,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تقارير التشغيل',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'معاينة، إثبات حالة، تلفيات مع إرفاق الصور',
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
          if (IconVisibilityService.isVisible(iconConfig, 'operation_reports'))
            const SizedBox(height: 24),
          if (IconVisibilityService.isVisible(iconConfig, 'detailed_report'))
            InkWell(
              onTap: () async {
                await _openAfterAttendanceCheck(
                  context: context,
                  routeName: 'detailed-report',
                  screen: DetailedReportScreen(
                    user: user,
                    continueToFinancesOnNext: false,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.assessment_outlined,
                      size: 56,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'التقرير اليومي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تفاصيل العمل والمواقع ثم «حفظ التقرير» — الماليات من أيقونة «الماليات»',
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
          if (IconVisibilityService.isVisible(iconConfig, 'detailed_report'))
            const SizedBox(height: 24),
          if (IconVisibilityService.isVisible(iconConfig, 'engineer_projects'))
            InkWell(
              onTap: () async {
                await _openAfterAttendanceCheck(
                  context: context,
                  routeName: 'engineer-projects',
                  screen: EngineerProjectsScreen(user: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.business,
                      size: 56,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'المشروعات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عرض التشوينات والنماذج والقطعيات حسب المبنى',
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
          const SizedBox(height: 32),
          Text(
            'مهندس موقع',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
  final Map<String, bool>? iconConfig;

  const _AccountantHome({required this.user, required this.iconConfig});

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
          if (IconVisibilityService.isVisible(iconConfig, 'accountant_custody'))
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'accountant-custody',
                  AccountantCustodyScreen(currentUser: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
                      Icons.handshake,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'العهدة',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تقرير العهدة حسب المستخدم والمدة وتصدير PDF',
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
          if (IconVisibilityService.isVisible(iconConfig, 'accountant_custody'))
            const SizedBox(height: 20),
          if (IconVisibilityService.isVisible(iconConfig, 'accountant_finance'))
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'accountant-finance',
                  AccountantFinanceScreen(currentUser: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
                      Icons.account_balance_wallet,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'الماليات',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أرصدة المستخدمين، إضافة/سحب رصيد، وإنشاء تقرير',
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// واجهة الصفحة الرئيسية لمدير المهندسين ومسؤول التطبيق
class _ManagerHome extends StatelessWidget {
  final UserModel user;
  final Map<String, bool>? iconConfig;

  const _ManagerHome({required this.user, required this.iconConfig});

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
          if (IconVisibilityService.isVisible(iconConfig, 'attendance_reports'))
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'attendance-reports',
                  AttendanceReportsScreen(currentUser: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
          if (IconVisibilityService.isVisible(iconConfig, 'attendance_reports'))
            const SizedBox(height: 20),
          if (IconVisibilityService.isVisible(
            iconConfig,
            'work_plan_tracking_report',
          ))
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'work-plan-tracking-report',
                  WorkPlanTrackingReportScreen(currentUser: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
                      Icons.fact_check,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تقارير متابعة خطط اليوم/الغد',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'جدول مجمع: مهندس، مشروع، مكان العمل، تفاصيل الخطة، خامات مسحوبة، مقاول',
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
          if (IconVisibilityService.isVisible(
            iconConfig,
            'work_plan_tracking_report',
          ))
            const SizedBox(height: 20),
          if (IconVisibilityService.isVisible(iconConfig, 'new_icon'))
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
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
                      Icons.auto_graph,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'New icon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ملخص خطة اليوم + جاهزية خطة الغد لمدير المهندسين',
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
          if (IconVisibilityService.isVisible(iconConfig, 'new_icon'))
            const SizedBox(height: 20),
          if (IconVisibilityService.isVisible(
            iconConfig,
            'operation_reports_tracking',
          ))
            _AnimatedOperationTrackingCard(user: user),
          if (IconVisibilityService.isVisible(
            iconConfig,
            'operation_reports_tracking',
          ))
            const SizedBox(height: 20),
          if (user.canManageIconsControl)
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'icons-control',
                  IconsControlScreen(currentUser: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
                      Icons.toggle_on,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Icons Control',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'التحكم في إظهار وإخفاء أيقونات واجهات المستخدمين',
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
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            if (user.canViewActivityLogs)
              if (IconVisibilityService.isVisible(iconConfig, 'daily_movement'))
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
                      border: Border.all(
                        color: const Color(0xFF1B5E20).withOpacity(0.3),
                      ),
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
                          Icons.insights,
                          size: 64,
                          color: const Color(0xFF1B5E20),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'الحركة اليومية',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ملخص يومي لتنفيذ/تعديل/تأجيل الخطط',
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
            if (user.canViewActivityLogs &&
                IconVisibilityService.isVisible(iconConfig, 'daily_movement'))
              const SizedBox(height: 20),
            // بطاقة التقارير (التقارير اليومية) - لمسؤول التطبيق فقط
            if (IconVisibilityService.isVisible(iconConfig, 'reports'))
              InkWell(
                onTap: () async {
                  await pushAndSaveRoute(
                    context,
                    'reports',
                    ReportsScreen(currentUser: user),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1B5E20).withOpacity(0.3),
                    ),
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
          if (IconVisibilityService.isVisible(iconConfig, 'reports'))
            const SizedBox(height: 20),
          if (IconVisibilityService.isVisible(
            iconConfig,
            'aggregated_detailed_daily',
          ))
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
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
                      Icons.table_rows,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'التقرير اليومي المجمع',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'من التقارير المفصّلة: مشروع، مهندس، مقاول، عمال، موقع، سحب خامات بنفس اليوم',
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
          if (IconVisibilityService.isVisible(
            iconConfig,
            'aggregated_detailed_daily',
          ))
            const SizedBox(height: 20),
          if (IconVisibilityService.isVisible(iconConfig, 'contractor_report'))
            InkWell(
              onTap: () async {
                await pushAndSaveRoute(
                  context,
                  'contractor-report',
                  ContractorReportScreen(admin: user),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1B5E20).withOpacity(0.3),
                  ),
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
                      Icons.engineering,
                      size: 64,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تقارير المقاول',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تقرير حسب اسم المقاول والفترة مع المشاريع وعدد العمال',
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
          if (user.isAdmin) ...[
            if (IconVisibilityService.isVisible(
              iconConfig,
              'contractor_report',
            ))
              const SizedBox(height: 20),
            if (IconVisibilityService.isVisible(
              iconConfig,
              'admin_project_structure',
            ))
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminProjectStructureScreen(admin: user),
                  ),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF1B5E20).withOpacity(0.3),
                    ),
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
                        Icons.account_tree,
                        size: 64,
                        color: const Color(0xFF1B5E20),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'هيكلة المشروعات',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'هيكل مواقع المشروع: مواقع فرعية ومواقع عمل (للتقرير المفصل)',
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
          if (user.isAdmin) ...[
            if (IconVisibilityService.isVisible(
              iconConfig,
              'admin_project_structure',
            ))
              const SizedBox(height: 20),
            if (IconVisibilityService.isVisible(iconConfig, 'admin_dashboard'))
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
                      Icon(
                        Icons.admin_panel_settings,
                        size: 64,
                        color: Colors.white.withOpacity(0.95),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'لوح التحكم',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إدارة المستخدمين والمشروعات والمناطق والمباني والخامات',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (user.isAdmin) ...[
            if (IconVisibilityService.isVisible(iconConfig, 'admin_dashboard'))
              const SizedBox(height: 20),
            if (user.canViewActivityLogs)
              if (IconVisibilityService.isVisible(iconConfig, 'activity_logs'))
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
                      border: Border.all(
                        color: const Color(0xFF1B5E20).withOpacity(0.3),
                      ),
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
                          Icons.manage_search,
                          size: 64,
                          color: const Color(0xFF1B5E20),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'سجل الحركة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'رصد كل الحركات على النظام خلال مدة محددة',
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
            if (user.canViewActivityLogs &&
                IconVisibilityService.isVisible(iconConfig, 'activity_logs'))
              const SizedBox(height: 20),
            if (IconVisibilityService.isVisible(iconConfig, 'dashboard'))
              InkWell(
                onTap: () async {
                  await pushAndSaveRoute(
                    context,
                    'dashboard',
                    const DashboardScreen(),
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
                      Icon(
                        Icons.dashboard,
                        size: 64,
                        color: Colors.white.withOpacity(0.95),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Management Dashboard',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fast daily visibility: progress, issues, and missing reports.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
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
  State<_AnimatedOperationTrackingCard> createState() =>
      _AnimatedOperationTrackingCardState();
}

class _AnimatedOperationTrackingCardState
    extends State<_AnimatedOperationTrackingCard>
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
                    Icon(
                      Icons.fact_check,
                      size: 64,
                      color: Colors.white.withOpacity(0.95),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'متابعة تقارير التشغيل',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'متابعة كل أنواع التقارير وحالة كل تقرير في دورة المراجعة',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.92),
                      ),
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
