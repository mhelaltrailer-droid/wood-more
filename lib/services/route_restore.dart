import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import '../screens/attendance_screen.dart';
import '../screens/attendance_reports_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/finance_screen.dart';
import '../screens/engineer_projects_screen.dart';
import '../screens/daily_report_step1_screen.dart';
import '../screens/manager_custody_screen.dart';
import '../screens/accountant_custody_screen.dart';
import '../screens/accountant_finance_screen.dart';
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
    case 'engineer-projects':
      return EngineerProjectsScreen(user: user);
    case 'accountant-custody':
      return AccountantCustodyScreen(currentUser: user);
    case 'accountant-finance':
      return AccountantFinanceScreen(currentUser: user);
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
    default:
      return null;
  }
}

/// Push a route and save its name so we can restore on refresh.
Future<void> pushAndSaveRoute(BuildContext context, String routeName, Widget screen) async {
  await saveLastRoute(routeName);
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => screen),
  );
}
