import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/home_icon_order_service.dart';
import '../services/route_restore.dart';
import '../services/storage_service.dart';
import '../widgets/animated_operation_tracking_card.dart';
import 'activity_logs_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_project_structure_screen.dart';
import 'aggregated_detailed_daily_report_screen.dart';
import 'attendance_reports_screen.dart';
import 'contractor_report_screen.dart';
import 'daily_movement_screen.dart';
import 'dashboard_screen.dart';
import 'icons_control_screen.dart';
import 'ir_mir_screen.dart';
import 'new_icon_screen.dart';
import 'reports_screen.dart';
import 'warehouses_view_screen.dart';
import 'work_plan_tracking_report_screen.dart';

class AppAdminHomeScreen extends StatefulWidget {
  final UserModel user;
  final Map<String, bool>? iconConfig;

  const AppAdminHomeScreen({
    super.key,
    required this.user,
    required this.iconConfig,
  });

  @override
  State<AppAdminHomeScreen> createState() => _AppAdminHomeScreenState();
}

class _AppAdminHomeScreenState extends State<AppAdminHomeScreen> {
  List<String> _orderedIconIds = const [];
  bool _loadingOrder = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void didUpdateWidget(covariant AppAdminHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.iconConfig != widget.iconConfig ||
        oldWidget.user.id != widget.user.id) {
      _loadOrder();
    }
  }

  Future<void> _loadOrder() async {
    setState(() => _loadingOrder = true);
    try {
      final saved = await getStorage().getUserHomeIconOrder(widget.user.id);
      if (!mounted) return;
      setState(() {
        _orderedIconIds = resolveAppAdminHomeIconOrder(
          user: widget.user,
          iconConfig: widget.iconConfig,
          savedOrder: saved,
        );
        _loadingOrder = false;
      });
    } catch (_) {
      if (!mounted) return;
      _applyResolvedOrder();
    }
  }

  void _applyResolvedOrder({List<String>? savedOrder}) {
    setState(() {
      _orderedIconIds = resolveAppAdminHomeIconOrder(
        user: widget.user,
        iconConfig: widget.iconConfig,
        savedOrder: savedOrder ?? _orderedIconIds,
      );
      _loadingOrder = false;
    });
  }

  Future<void> _persistOrder() async {
    try {
      await getStorage().setUserHomeIconOrder(
        userId: widget.user.id,
        iconOrder: _orderedIconIds,
      );
    } catch (_) {}
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      var targetIndex = newIndex;
      if (targetIndex > oldIndex) targetIndex--;
      final moved = _orderedIconIds.removeAt(oldIndex);
      _orderedIconIds.insert(targetIndex, moved);
    });
    _persistOrder();
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
            'مرحباً، ${widget.user.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'اضغط مطولاً على الأيقونة ثم اسحبها لأعلى أو لأسفل لإعادة ترتيبها.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_loadingOrder)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_orderedIconIds.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('لا توجد أيقونات ظاهرة في الواجهة الرئيسية.'),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _orderedIconIds.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final iconId = _orderedIconIds[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(iconId),
                  index: index,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _orderedIconIds.length - 1 ? 0 : 20,
                    ),
                    child: _buildIcon(iconId),
                  ),
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildIcon(String iconId) {
    switch (iconId) {
      case 'attendance_reports':
        return _lightCard(
          icon: Icons.assignment_outlined,
          title: 'تقارير الحضور والانصراف',
          subtitle: 'عرض سجلات جميع المهندسين',
          onTap: () => pushAndSaveRoute(
            context,
            'attendance-reports',
            AttendanceReportsScreen(currentUser: widget.user),
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
            WorkPlanTrackingReportScreen(currentUser: widget.user),
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
            NewIconScreen(currentUser: widget.user),
          ),
        );
      case 'operation_reports_tracking':
        return AnimatedOperationTrackingCard(user: widget.user);
      case homeIconIdIconsControl:
        return _lightCard(
          icon: Icons.toggle_on,
          title: 'Icons Control',
          subtitle: 'التحكم في إظهار وإخفاء أيقونات واجهات المستخدمين',
          onTap: () => pushAndSaveRoute(
            context,
            'icons-control',
            IconsControlScreen(currentUser: widget.user),
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
            DailyMovementScreen(currentUser: widget.user),
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
            ReportsScreen(currentUser: widget.user),
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
            AggregatedDetailedDailyReportScreen(currentUser: widget.user),
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
            ContractorReportScreen(admin: widget.user),
          ),
        );
      case 'ir_mir':
        return _lightCard(
          icon: Icons.folder_shared,
          title: 'IR-MIR',
          subtitle: 'عرض مرفقات MIR و IR من مهندسي المواقع',
          onTap: () => pushAndSaveRoute(
            context,
            'ir-mir',
            IrMirScreen(currentUser: widget.user),
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
            WarehousesViewScreen(currentUser: widget.user),
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
              builder: (_) => AdminProjectStructureScreen(admin: widget.user),
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
            AdminDashboardScreen(currentUser: widget.user),
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
            ActivityLogsScreen(currentUser: widget.user),
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

  Widget _lightCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
            Icon(icon, size: 64, color: const Color(0xFF1B5E20)),
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

  Widget _gradientCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
            Icon(icon, size: 64, color: Colors.white.withOpacity(0.95)),
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
