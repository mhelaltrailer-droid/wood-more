import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/accountant_custody_screen.dart';
import '../screens/accountant_finance_screen.dart';
import '../screens/activity_logs_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_project_structure_screen.dart';
import '../screens/aggregated_detailed_daily_report_screen.dart';
import '../screens/attendance_reports_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/contractor_report_screen.dart';
import '../screens/daily_movement_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/detailed_report_screen.dart';
import '../screens/engineer_projects_screen.dart';
import '../screens/engineer_withdraw_materials_screen.dart';
import '../screens/icons_control_screen.dart';
import '../screens/ir_mir_screen.dart';
import '../screens/new_icon_screen.dart';
import '../screens/operation_reports_screen.dart';
import '../screens/postpone_fines_report_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/site_engineer_finances_entry_screen.dart';
import '../screens/today_work_plan_screen.dart';
import '../screens/tomorrow_work_plan_screen.dart';
import '../screens/warehouses_view_screen.dart';
import '../screens/work_plan_tracking_report_screen.dart';
import '../services/home_icon_order_service.dart';
import '../services/route_restore.dart';
import '../services/storage_service.dart';
import 'animated_operation_tracking_card.dart';

class HomeIconBuilder {
  const HomeIconBuilder._();

  static Widget build({
    required BuildContext context,
    required UserModel user,
    required String iconId,
  }) {
    switch (iconId) {
      case 'attendance':
        return _gradientCard(
          icon: Icons.fingerprint,
          iconSize: 80,
          title: 'تسجيل الحضور والانصراف',
          subtitle: 'اضغط للتسجيل',
          padding: 32,
          onTap: () => pushAndSaveRoute(
            context,
            'attendance',
            AttendanceScreen(currentUser: user),
          ),
        );
      case 'today_work_plan':
        return _lightCard(
          icon: Icons.today,
          iconSize: 56,
          title: 'خطة عمل اليوم',
          subtitle: 'عرض خطة اليوم حسب التاريخ لنفس مهندس الموقع (قراءة فقط)',
          padding: 28,
          onTap: () => _openAfterAttendanceCheck(
            context: context,
            user: user,
            routeName: 'today-work-plan',
            screen: TodayWorkPlanScreen(user: user),
          ),
        );
      case 'tomorrow_work_plan':
        return _lightCard(
          icon: Icons.event_note,
          iconSize: 56,
          title: 'خطة عمل الغد',
          subtitle:
              'تسجيل خطة التنفيذ (غداً أو لاحقاً) مع توزيع العمال — حفظ مباشر دون خطوة الماليات',
          padding: 28,
          onTap: () => _openAfterAttendanceCheck(
            context: context,
            user: user,
            routeName: 'tomorrow-work-plan',
            screen: TomorrowWorkPlanScreen(user: user),
          ),
        );
      case 'engineer_withdraw_materials':
        return _lightCard(
          icon: Icons.warehouse,
          iconSize: 56,
          title: 'المخزن (سحب الخامات)',
          subtitle:
              'عرض الخامات المتاحة للسحب لكل مكان فرعي وإتمام السحب مع أذن الصرف والتسليم',
          padding: 28,
          onTap: () => _openAfterAttendanceCheck(
            context: context,
            user: user,
            routeName: 'engineer-withdraw-materials',
            screen: EngineerWithdrawMaterialsScreen(user: user),
          ),
        );
      case 'engineer_finances':
        return _lightCard(
          icon: Icons.payments_outlined,
          iconSize: 56,
          title: 'الماليات',
          subtitle:
              'مرتبطة بخطة عمل اليوم: اختيار التاريخ → عرض الخطة (قراءة فقط) → بنود الصرف وخصم الرصيد',
          padding: 28,
          onTap: () => _openAfterAttendanceCheck(
            context: context,
            user: user,
            routeName: 'engineer-finances',
            screen: SiteEngineerFinancesEntryScreen(user: user),
          ),
        );
      case 'operation_reports':
        return _lightCard(
          icon: Icons.fact_check_outlined,
          iconSize: 56,
          title: 'تقارير التشغيل',
          subtitle: 'معاينة، إثبات حالة، تلفيات مع إرفاق الصور',
          padding: 28,
          onTap: () => _openAfterAttendanceCheck(
            context: context,
            user: user,
            routeName: 'operation-reports',
            screen: OperationReportsScreen(user: user),
          ),
        );
      case 'detailed_report':
        return _lightCard(
          icon: Icons.assessment_outlined,
          iconSize: 56,
          title: 'التقرير اليومي',
          subtitle:
              'تفاصيل العمل والمواقع ثم «حفظ التقرير» — الماليات من أيقونة «الماليات»',
          padding: 28,
          onTap: () => _openAfterAttendanceCheck(
            context: context,
            user: user,
            routeName: 'detailed-report',
            screen: DetailedReportScreen(
              user: user,
              continueToFinancesOnNext: false,
            ),
          ),
        );
      case 'engineer_projects':
        return _lightCard(
          icon: Icons.business,
          iconSize: 56,
          title: 'المشروعات',
          subtitle: 'عرض التشوينات والنماذج والقطعيات حسب المبنى',
          padding: 28,
          onTap: () => _openAfterAttendanceCheck(
            context: context,
            user: user,
            routeName: 'engineer-projects',
            screen: EngineerProjectsScreen(user: user),
          ),
        );
      case 'accountant_custody':
        return _lightCard(
          icon: Icons.handshake,
          title: 'العهدة',
          subtitle: 'تقرير العهدة حسب المستخدم والمدة وتصدير PDF',
          onTap: () => pushAndSaveRoute(
            context,
            'accountant-custody',
            AccountantCustodyScreen(currentUser: user),
          ),
        );
      case 'accountant_finance':
        return _lightCard(
          icon: Icons.account_balance_wallet,
          title: 'الماليات',
          subtitle: 'أرصدة المستخدمين، إضافة/سحب رصيد، وإنشاء تقرير',
          onTap: () => pushAndSaveRoute(
            context,
            'accountant-finance',
            AccountantFinanceScreen(currentUser: user),
          ),
        );
      case 'attendance_reports':
        return _lightCard(
          icon: Icons.assignment_outlined,
          title: 'تقارير الحضور والانصراف',
          subtitle: 'عرض سجلات جميع المهندسين',
          onTap: () => pushAndSaveRoute(
            context,
            'attendance-reports',
            AttendanceReportsScreen(currentUser: user),
          ),
        );
      case 'work_plan_tracking_report':
        return _lightCard(
          icon: Icons.fact_check,
          title: 'تقارير متابعة خطط اليوم/الغد',
          subtitle:
              'جدول مجمع: مهندس، مشروع، مكان العمل، تفاصيل الخطة، خامات مسحوبة، مقاول',
          onTap: () => pushAndSaveRoute(
            context,
            'work-plan-tracking-report',
            WorkPlanTrackingReportScreen(currentUser: user),
          ),
        );
      case 'postpone_fines_reports':
        if (!user.canAccessPostponeFinesReports) {
          return const SizedBox.shrink();
        }
        return _lightCard(
          icon: Icons.gavel_outlined,
          iconSize: 56,
          title: 'تقارير التأجيل/الغرامات',
          subtitle:
              'فلترة بالمدة والمهندس والمشروع والمقاول وسبب التأجيل — مع قيمة الغرامة والطرف الموقع عليه',
          padding: 28,
          onTap: () => pushAndSaveRoute(
            context,
            'postpone-fines-report',
            PostponeFinesReportScreen(currentUser: user),
          ),
        );
      case 'new_icon':
        return _lightCard(
          icon: Icons.auto_graph,
          title: 'New icon',
          subtitle:
              'ملخص خطة اليوم + جاهزية خطة الغد ل${UserModel.siteEngineerManagerRoleLabel}',
          onTap: () => pushAndSaveRoute(
            context,
            'new-icon',
            NewIconScreen(currentUser: user),
          ),
        );
      case 'operation_reports_tracking':
        return AnimatedOperationTrackingCard(user: user);
      case homeIconIdIconsControl:
        return _lightCard(
          icon: Icons.toggle_on,
          title: 'Icons Control',
          subtitle: 'التحكم في إظهار وإخفاء أيقونات واجهات المستخدمين',
          onTap: () => pushAndSaveRoute(
            context,
            'icons-control',
            IconsControlScreen(currentUser: user),
          ),
        );
      case 'daily_movement':
        return _lightCard(
          icon: Icons.insights,
          title: 'الحركة اليومية',
          subtitle: 'ملخص يومي لتنفيذ/تعديل/تأجيل الخطط',
          onTap: () => pushAndSaveRoute(
            context,
            'daily-movement',
            DailyMovementScreen(currentUser: user),
          ),
        );
      case 'reports':
        return _lightCard(
          icon: Icons.summarize,
          title: 'التقارير',
          subtitle: 'تقارير يومية حسب المهندس والتاريخ والمشروع',
          onTap: () => pushAndSaveRoute(
            context,
            'reports',
            ReportsScreen(currentUser: user),
          ),
        );
      case 'aggregated_detailed_daily':
        return _lightCard(
          icon: Icons.table_rows,
          title: 'التقرير اليومي المجمع',
          subtitle:
              'من التقارير المفصّلة: مشروع، مهندس، مقاول، عمال، موقع، سحب خامات بنفس اليوم',
          onTap: () => pushAndSaveRoute(
            context,
            'aggregated-detailed-daily',
            AggregatedDetailedDailyReportScreen(currentUser: user),
          ),
        );
      case 'contractor_report':
        return _lightCard(
          icon: Icons.engineering,
          title: 'تقارير المقاول',
          subtitle: 'تقرير حسب اسم المقاول والفترة مع المشاريع وعدد العمال',
          onTap: () => pushAndSaveRoute(
            context,
            'contractor-report',
            ContractorReportScreen(admin: user),
          ),
        );
      case 'ir_mir':
        return _lightCard(
          icon: user.isSiteEngineer ? Icons.folder_special : Icons.folder_shared,
          iconSize: user.isSiteEngineer ? 56 : 64,
          title: 'IR-MIR',
          subtitle: user.isSiteEngineer
              ? 'رفع مستندات MIR أو IR حسب هيكلة المشروع'
              : 'عرض مرفقات MIR و IR من مهندسي المواقع',
          padding: user.isSiteEngineer ? 28 : 32,
          onTap: () => user.isSiteEngineer
              ? _openAfterAttendanceCheck(
                  context: context,
                  user: user,
                  routeName: 'ir-mir',
                  screen: IrMirScreen(currentUser: user),
                )
              : pushAndSaveRoute(
                  context,
                  'ir-mir',
                  IrMirScreen(currentUser: user),
                ),
        );
      case 'warehouses_view':
        return _lightCard(
          icon: Icons.warehouse,
          title: 'المخازن',
          subtitle: 'عرض الخامات وأذون الصرف والتسليم بعد السحب (قراءة فقط)',
          onTap: () => pushAndSaveRoute(
            context,
            'warehouses-view',
            WarehousesViewScreen(currentUser: user),
          ),
        );
      case 'admin_project_structure':
        return _lightCard(
          icon: Icons.account_tree,
          title: 'هيكلة المشروعات',
          subtitle:
              'هيكل مواقع المشروع: مواقع فرعية ومواقع عمل (للتقرير المفصل)',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminProjectStructureScreen(admin: user),
            ),
          ),
        );
      case 'admin_dashboard':
        return _gradientCard(
          icon: Icons.admin_panel_settings,
          title: 'لوح التحكم',
          subtitle: 'إدارة المستخدمين والمشروعات والمناطق والمباني والخامات',
          onTap: () => pushAndSaveRoute(
            context,
            'admin-dashboard',
            AdminDashboardScreen(currentUser: user),
          ),
        );
      case 'activity_logs':
        return _lightCard(
          icon: Icons.manage_search,
          title: 'سجل الحركة',
          subtitle: 'رصد كل الحركات على النظام خلال مدة محددة',
          onTap: () => pushAndSaveRoute(
            context,
            'activity-logs',
            ActivityLogsScreen(currentUser: user),
          ),
        );
      case 'dashboard':
        return _gradientCard(
          icon: Icons.dashboard,
          title: 'Management Dashboard',
          subtitle:
              'Fast daily visibility: progress, issues, and missing reports.',
          onTap: () => pushAndSaveRoute(
            context,
            'dashboard',
            const DashboardScreen(),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  static Future<void> _openAfterAttendanceCheck({
    required BuildContext context,
    required UserModel user,
    required String routeName,
    required Widget screen,
  }) async {
    final db = getStorage();
    final today = DateTime.now();
    final attendance = await db.getAttendanceForUserOnDate(user.id, today);
    if (!context.mounted) return;
    if (attendance.checkIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الحضور اولا')),
      );
      return;
    }
    await pushAndSaveRoute(context, routeName, screen);
  }

  static Widget _lightCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
    double iconSize = 64,
    double padding = 32,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(padding),
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
            Icon(icon, size: iconSize, color: const Color(0xFF1B5E20)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF1B5E20).withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _gradientCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
    double iconSize = 64,
    double padding = 32,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(padding),
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
            Icon(icon, size: iconSize, color: Colors.white.withOpacity(0.95)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
