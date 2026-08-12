import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../screens/accountant_custody_screen.dart';
import '../screens/site_engineer_expenses_report_screen.dart';
import '../screens/accountant_finance_screen.dart';
import '../screens/activity_logs_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_project_structure_screen.dart';
import '../screens/attendance_reports_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/contractor_report_screen.dart';
import '../screens/detailed_report_screen.dart';
import '../screens/engineer_projects_screen.dart';
import '../screens/engineer_withdraw_materials_screen.dart';
import '../screens/icons_control_screen.dart';
import '../screens/document_control_hub_screen.dart';
import '../screens/new_icon_screen.dart';
import '../screens/operation_reports_screen.dart';
import '../screens/operation_manager_custody_balances_hub_screen.dart';
import '../screens/postpone_fines_report_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/reports_sys_hub_screen.dart';
import '../core/shop_drawing_constants.dart';
import '../screens/shop_drawing_type_gate_screen.dart';
import '../screens/detailed_report_finances_screen.dart';
import '../screens/manager_custody_expenses_hub_screen.dart';
import '../screens/custody_expenses_view_screen.dart';
import '../screens/today_work_plan_screen.dart';
import '../screens/tomorrow_work_plan_screen.dart';
import '../screens/warehouses_view_screen.dart';
import '../screens/withdrawal_files_reports_hub_screen.dart';
import '../screens/work_plan_tracking_report_screen.dart';
import '../screens/weekly_report_screen.dart';
import '../screens/projects_dashboard_screen.dart';
import '../screens/projects_dashboard_plus1_screen.dart';
import '../screens/meetings_screen.dart';
import '../services/home_icon_order_service.dart';
import '../services/route_restore.dart';
import '../services/storage_service.dart';

class HomeIconBuilder {
  const HomeIconBuilder._();

  static Widget build({
    required BuildContext context,
    required UserModel user,
    required String iconId,
    int pendingReportsSysCount = 0,
    int pendingShopDrawingCount = 0,
    Future<void> Function()? onReportsSysReturn,
    Future<void> Function()? onShopDrawingReturn,
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
          title: 'العهدة/المصروفات',
          padding: 28,
          onTap: () => pushAndSaveRoute(
            context,
            'engineer-finances',
            DetailedReportFinancesScreen.directEntry(user: user),
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
          subtitle: 'بنود صرف العهدة/المصروفات حسب المستخدم والمدة وتصدير PDF',
          onTap: () => pushAndSaveRoute(
            context,
            'accountant-custody',
            AccountantCustodyScreen(currentUser: user),
          ),
        );
      case 'site_engineer_expenses_report':
        return _lightCard(
          icon: Icons.receipt_long_outlined,
          title: 'بنود الصرف',
          subtitle: 'عرض وحذف بنود صرف مهندسي المواقع حسب المستخدم والمدة',
          onTap: () => pushAndSaveRoute(
            context,
            'site-engineer-expenses-report',
            SiteEngineerExpensesReportScreen(
              currentUser: user,
              canDeleteExpenses: true,
              appBarTitle: 'بنود الصرف',
            ),
          ),
        );
      case 'accountant_finance':
        return _lightCard(
          icon: Icons.account_balance_wallet,
          title: 'الأرصدة / المصروفات',
          subtitle: 'أرصدة المستخدمين، إضافة/سحب رصيد، وإنشاء تقرير',
          onTap: () => pushAndSaveRoute(
            context,
            'accountant-finance',
            AccountantFinanceScreen(currentUser: user),
          ),
        );
      case 'manager_custody_expenses':
        return _lightCard(
          icon: Icons.account_balance_wallet,
          title: 'العهد/تقارير المصروفات',
          subtitle: 'العهد، تقارير المصروفات، وإدخال بيان صرف',
          onTap: () => pushAndSaveRoute(
            context,
            'manager-custody-expenses',
            ManagerCustodyExpensesHubScreen(currentUser: user),
          ),
        );
      case 'custody_expenses_view':
        if (user.role == 'operation_manager') {
          // For operation manager this legacy direct icon is replaced by the new hub.
          return const SizedBox.shrink();
        }
        return _lightCard(
          icon: Icons.receipt_long_outlined,
          title: 'العهده/ المصروفات',
          subtitle: 'الاطلاع على بيانات الصرف المعتمدة والمرفوضة',
          onTap: () => pushAndSaveRoute(
            context,
            'custody-expenses-view',
            CustodyExpensesViewScreen(
              currentUser: user,
              appBarTitle: 'العهده/ المصروفات',
            ),
          ),
        );
      case 'operation_manager_custody_balances_expenses':
        return _lightCard(
          icon: Icons.account_balance_wallet,
          title: 'العهد/الارصدة/المصروفات',
          subtitle: 'العهد/المصروفات + الأرصدة (اطلاع فقط)',
          onTap: () => pushAndSaveRoute(
            context,
            'operation-manager-custody-balances-expenses',
            OperationManagerCustodyBalancesHubScreen(currentUser: user),
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
      case 'weekly_report':
        return _lightCard(
          icon: Icons.calendar_view_week,
          title: 'التقرير الاسبوعي',
          subtitle:
              'حضور وانصراف وخطط اليوم/الغد لكل مهندس ضمن مدة سبت–خميس',
          onTap: () => pushAndSaveRoute(
            context,
            'weekly-report',
            WeeklyReportScreen(currentUser: user),
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
          title: 'Control',
          subtitle:
              'ملخص خطة اليوم + جاهزية خطة الغد ل${UserModel.siteEngineerManagerRoleLabel}',
          onTap: () => pushAndSaveRoute(
            context,
            'new-icon',
            NewIconScreen(currentUser: user),
          ),
        );
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
      case 'withdrawal_files_reports':
        return _lightCard(
          icon: Icons.inventory_2_outlined,
          iconSize: 56,
          title: 'تقارير السحب والمرفقات',
          subtitle:
              'سحب الخامات حسب المشروع وموقع العمل · الملفات المرفوعة (IR / MIR / ...)',
          padding: 28,
          onTap: () => pushAndSaveRoute(
            context,
            'withdrawal-files-reports',
            WithdrawalFilesReportsHubScreen(currentUser: user),
          ),
        );
      case 'document_control':
        return _lightCard(
          icon: Icons.folder_shared_outlined,
          iconSize: 56,
          title: 'Document Control',
          subtitle: 'IR-MIR · MS-SD · QS-INV(s) · MoS-ITP',
          padding: 28,
          onTap: () => pushAndSaveRoute(
            context,
            'document-control',
            DocumentControlHubScreen(currentUser: user),
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
      case 'projects_dashboard':
        if (!user.canAccessProjectsDashboard) {
          return const SizedBox.shrink();
        }
        return _lightCard(
          icon: Icons.dashboard_customize_outlined,
          iconSize: 56,
          title: 'Projects Dashboard',
          subtitle:
              'WebDAV — فتح Excel على ويندوز والحفظ مباشرة على السيرفر',
          padding: 28,
          onTap: () => pushAndSaveRoute(
            context,
            'projects-dashboard',
            ProjectsDashboardScreen(currentUser: user),
          ),
        );
      case 'projects_dashboard_plus1':
        if (!user.canAccessProjectsDashboard) {
          return const SizedBox.shrink();
        }
        return _lightCard(
          icon: Icons.add_chart_outlined,
          iconSize: 56,
          title: 'Projects Dashboard +1',
          subtitle:
              'تحميل → Excel → رفع — تجربة مؤقتة (ملف وملاحظات منفصلة)',
          padding: 28,
          onTap: () => pushAndSaveRoute(
            context,
            'projects-dashboard-plus1',
            ProjectsDashboardPlus1Screen(currentUser: user),
          ),
        );
      case 'shop_drawing':
        return _gradientCard(
          icon: Icons.architecture_outlined,
          title: shopDrawingHomeIconLabel,
          subtitle: 'رفع واعتماد Shop-Drawing و PO',
          badgeCount: pendingShopDrawingCount,
          onTap: () async {
            await pushAndSaveRoute(
              context,
              'shop-drawing',
              ShopDrawingTypeGateScreen(currentUser: user),
            );
            await onShopDrawingReturn?.call();
          },
        );
      case 'meetings':
        if (!user.canAccessMeetings) {
          return const SizedBox.shrink();
        }
        return _lightCard(
          icon: Icons.groups_outlined,
          iconSize: 56,
          title: 'Meetings',
          subtitle: 'الاجتماعات',
          padding: 28,
          onTap: () => pushAndSaveRoute(
            context,
            'meetings',
            const MeetingsScreen(),
          ),
        );
      case 'reports_sys':
        return _gradientCard(
          icon: Icons.hub_outlined,
          title: 'Reports -SYS',
          subtitle: 'تداول التقارير: معاينة، إثبات حالة، تلفيات',
          badgeCount: pendingReportsSysCount,
          onTap: () async {
            await pushAndSaveRoute(
              context,
              'reports-sys',
              ReportsSysHubScreen(currentUser: user),
            );
            await onReportsSysReturn?.call();
          },
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
    String? subtitle,
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
            if (subtitle != null && subtitle.isNotEmpty) ...[
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
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
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
          if (badgeCount > 0)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 22),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
