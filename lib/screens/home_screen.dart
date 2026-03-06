import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/daily_report_model.dart';
import 'attendance_screen.dart';
import 'attendance_reports_screen.dart';
import 'reports_screen.dart';
import 'admin_dashboard_screen.dart';
import 'finance_screen.dart';
import 'engineer_projects_screen.dart';
import 'daily_report_step1_screen.dart';
import 'manager_custody_screen.dart';
import 'login_screen.dart';

/// الصفحة الرئيسية - تختلف حسب دور المستخدم
class HomeScreen extends StatelessWidget {
  final UserModel currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: currentUser.isSiteEngineer ? _EngineerHome(user: currentUser) : _ManagerHome(user: currentUser),
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
          // أيقونة تسجيل الحضور والانصراف
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AttendanceScreen(currentUser: user),
                ),
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
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              final report = DailyReportData(
                userName: user.name,
                userId: user.id,
                reportDate: DateTime.now(),
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DailyReportStep1Screen(user: user, report: report),
                ),
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
                  Icon(Icons.description, size: 56, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 12),
                  const Text(
                    'التقرير اليومي',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'إعداد تقرير يومي',
                    style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EngineerProjectsScreen(user: user),
                ),
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AttendanceReportsScreen(),
                ),
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
          // بطاقة التقارير (التقارير اليومية)
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReportsScreen(currentUser: user),
                ),
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
          const SizedBox(height: 20),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FinanceScreen(currentUser: user),
                ),
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
                  Icon(Icons.account_balance_wallet, size: 64, color: const Color(0xFF1B5E20)),
                  const SizedBox(height: 16),
                  const Text('الماليات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('أرصدة المهندسين، عهدة، وتقارير مصروفات', style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          if (user.role == 'site_engineer_manager') ...[
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManagerCustodyScreen(currentUser: user),
                  ),
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
                    Icon(Icons.handshake, size: 64, color: const Color(0xFF1B5E20)),
                    const SizedBox(height: 16),
                    const Text('العهدة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text('إدخال عهدة وتقرير العهدة', style: TextStyle(fontSize: 14, color: const Color(0xFF1B5E20).withOpacity(0.9)), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],
          if (user.isAdmin) ...[
            const SizedBox(height: 20),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AdminDashboardScreen(currentUser: user),
                  ),
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
                    Icon(Icons.dashboard, size: 64, color: Colors.white.withOpacity(0.95)),
                    const SizedBox(height: 16),
                    const Text(
                      'لوح التحكم',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'إدارة المستخدمين والمشاريع والمناطق والمباني والخامات',
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
