import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import '../screens/attendance_screen.dart';
import '../screens/attendance_reports_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/engineer_projects_screen.dart';
import '../screens/engineer_withdraw_materials_screen.dart';
import '../screens/daily_report_step1_screen.dart';
import '../screens/detailed_report_screen.dart';
import '../screens/detailed_report_finances_screen.dart';
import '../screens/tomorrow_work_plan_screen.dart';
import '../screens/today_work_plan_screen.dart';
import '../screens/site_engineer_reports_screen.dart';
import '../screens/manager_custody_screen.dart';
import '../screens/accountant_custody_screen.dart';
import '../screens/site_engineer_expenses_report_screen.dart';
import '../screens/accountant_finance_screen.dart';
import '../screens/manager_custody_expenses_hub_screen.dart';
import '../screens/custody_expenses_view_screen.dart';
import '../screens/expense_statements_screen.dart';
import '../screens/operation_manager_balances_view_screen.dart';
import '../screens/operation_manager_custody_balances_hub_screen.dart';
import '../screens/activity_logs_screen.dart';
import '../screens/new_icon_screen.dart';
import '../screens/operation_reports_screen.dart';
import '../screens/postpone_fines_report_screen.dart';
import '../screens/work_plan_tracking_report_screen.dart';
import '../screens/weekly_report_screen.dart';
import '../screens/icons_control_screen.dart';
import '../screens/document_control_hub_screen.dart';
import '../screens/ir_mir_screen.dart';
import '../screens/ms_sd_screen.dart';
import '../screens/mos_itp_screen.dart';
import '../screens/module_placeholder_screen.dart';
import '../screens/warehouses_view_screen.dart';
import '../screens/withdrawal_files_reports_hub_screen.dart';
import '../screens/material_withdrawals_report_screen.dart';
import '../screens/uploaded_files_report_screen.dart';
import '../screens/reports_sys_hub_screen.dart';
import '../screens/projects_dashboard_screen.dart';
import '../screens/projects_dashboard_plus1_screen.dart';
import '../screens/meetings_screen.dart';
import '../screens/invoices_owner_hub_screen.dart';
import 'route_persistence.dart';

/// Build the screen for a given route name (for restore after refresh). Returns null if unknown.
Widget? getScreenForRoute(String name, UserModel user) {
  switch (name) {
    case 'attendance':
      return AttendanceScreen(currentUser: user);
    case 'daily-report':
      final report = DailyReportData(
        userName: user.name,
        userId: user.id,
        reportDate: DateTime.now(),
      );
      return DailyReportStep1Screen(user: user, report: report);
    case 'detailed-report':
      return DetailedReportScreen(user: user, continueToFinancesOnNext: false);
    case 'engineer-finances':
      return DetailedReportFinancesScreen.directEntry(user: user);
    case 'tomorrow-work-plan':
      return TomorrowWorkPlanScreen(user: user);
    case 'today-work-plan':
      return TodayWorkPlanScreen(user: user);
    case 'site-engineer-reports':
      return SiteEngineerReportsScreen(user: user);
    case 'engineer-projects':
      return EngineerProjectsScreen(user: user);
    case 'engineer-withdraw-materials':
      return EngineerWithdrawMaterialsScreen(user: user);
    case 'accountant-custody':
      return AccountantCustodyScreen(currentUser: user);
    case 'site-engineer-expenses-report':
      return SiteEngineerExpensesReportScreen(
        currentUser: user,
        canDeleteExpenses: user.canManageSiteEngineerExpensesReport,
        appBarTitle: 'بنود الصرف',
      );
    case 'accountant-finance':
      return AccountantFinanceScreen(currentUser: user);
    case 'manager-custody-expenses':
      return ManagerCustodyExpensesHubScreen(currentUser: user);
    case 'manager-custody-hub-balances':
      return AccountantFinanceScreen(currentUser: user);
    case 'manager-custody-hub-reports':
      return ExpenseStatementsScreen(
        currentUser: user,
        appBarTitle: 'تقارير المصروفات',
        allowRespond: true,
        allowDelete: false,
      );
    case 'manager-custody-hub-entry':
      return DetailedReportFinancesScreen.managerDirectEntry(user: user);
    case 'custody-expenses-view':
      return CustodyExpensesViewScreen(
        currentUser: user,
        appBarTitle: 'العهده/ المصروفات',
      );
    case 'operation-manager-custody-balances-expenses':
      return OperationManagerCustodyBalancesHubScreen(currentUser: user);
    case 'operation-manager-custody-expenses-view':
      return CustodyExpensesViewScreen(
        currentUser: user,
        appBarTitle: 'العهده/ المصروفات',
      );
    case 'operation-manager-balances-view':
      return OperationManagerBalancesViewScreen(currentUser: user);
    case 'attendance-reports':
      return AttendanceReportsScreen(currentUser: user);
    case 'reports':
      return ReportsScreen(currentUser: user);
    case 'finance':
      return FinanceScreen(currentUser: user);
    case 'manager-custody':
      return ManagerCustodyScreen(currentUser: user);
    case 'admin-dashboard':
      return AdminDashboardScreen(currentUser: user);
    case 'activity-logs':
      return ActivityLogsScreen(currentUser: user);
    case 'new-icon':
      return NewIconScreen(currentUser: user);
    case 'operation-reports':
      return OperationReportsScreen(user: user);
    case 'work-plan-tracking-report':
      return WorkPlanTrackingReportScreen(currentUser: user);
    case 'weekly-report':
      return WeeklyReportScreen(currentUser: user);
    case 'postpone-fines-report':
      return PostponeFinesReportScreen(currentUser: user);
    case 'icons-control':
      return IconsControlScreen(currentUser: user);
    case 'document-control':
      return DocumentControlHubScreen(currentUser: user);
    case 'ir-mir':
      return IrMirScreen(currentUser: user);
    case 'warehouses-view':
      return WarehousesViewScreen(currentUser: user);
    case 'withdrawal-files-reports':
      return WithdrawalFilesReportsHubScreen(currentUser: user);
    case 'material-withdrawals-report':
      return MaterialWithdrawalsReportScreen(currentUser: user);
    case 'uploaded-files-report':
      return UploadedFilesReportScreen(currentUser: user);
    case 'ms-sd':
      return MsSdScreen(currentUser: user);
    case 'qs-invs':
      return const ModulePlaceholderScreen(
        title: 'QS-INV(s)',
        description: 'Quantity Survey — Invoices\nحصر الكميات والفواتير',
        icon: Icons.receipt_long_outlined,
      );
    case 'mos-itp':
      return MosItpScreen(currentUser: user);
    case 'reports-sys':
      return ReportsSysHubScreen(currentUser: user);
    case 'projects-dashboard':
      return ProjectsDashboardScreen(currentUser: user);
    case 'projects-dashboard-plus1':
      return ProjectsDashboardPlus1Screen(currentUser: user);
    case 'meetings':
      return MeetingsScreen(currentUser: user);
    case 'invoices-owner':
      return InvoicesOwnerHubScreen(currentUser: user);
    default:
      return null;
  }
}

/// Push a route and save its name so we can restore on refresh.
Future<void> pushAndSaveRoute(
  BuildContext context,
  String routeName,
  Widget screen,
) async {
  await saveLastRoute(routeName);
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}
