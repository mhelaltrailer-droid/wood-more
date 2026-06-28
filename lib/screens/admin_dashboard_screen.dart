import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/route_persistence.dart';
import '../services/storage_service.dart';
import 'admin_users_screen.dart';
import 'admin_projects_screen.dart';
import 'admin_zones_screen.dart';
import 'admin_buildings_screen.dart';
import 'admin_supervisors_screen.dart';
import 'admin_contractors_screen.dart';
import 'admin_materials_screen.dart';
import 'admin_project_stores_screen.dart';
import 'admin_warehouse_structure_screen.dart';
import 'admin_warehouse_withdraw_screen.dart';
import 'admin_units_screen.dart';
import 'admin_building_materials_screen.dart';
import 'admin_cutlists_screen.dart';
import 'worker_hours_report_screen.dart';
import 'home_screen.dart';

/// لوح التحكم - يظهر لمسؤول التطبيق فقط
class AdminDashboardScreen extends StatefulWidget {
  final UserModel currentUser;

  const AdminDashboardScreen({super.key, required this.currentUser});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _db = getStorage();
  bool _systemLocked = false;
  bool _systemLockLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSystemLocked();
  }

  Future<void> _loadSystemLocked() async {
    if (!widget.currentUser.canManageWarehouseWithdrawalReset) return;
    try {
      final locked = await _db.isSystemLocked();
      if (!mounted) return;
      setState(() => _systemLocked = locked);
    } catch (_) {}
  }

  Future<void> _toggleSystemLocked(bool value) async {
    setState(() => _systemLockLoading = true);
    try {
      await _db.setSystemLocked(
        value,
        requesterEmail: widget.currentUser.email,
      );
      if (!mounted) return;
      setState(() => _systemLocked = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'تم تفعيل وضع الصيانة؛ سيتم إنهاء جلسات المستخدمين الآخرين تلقائياً'
                : 'تم إلغاء قفل النظام',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث حالة النظام: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _systemLockLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <_Item>[
      _Item('إدارة المستخدمين', 'إضافة وتعديل وحذف المستخدمين والأدوار', Icons.people, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUsersScreen(admin: widget.currentUser)))),
      _Item('إدارة المشاريع', 'إضافة وتعديل وحذف المشاريع', Icons.business, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProjectsScreen(admin: widget.currentUser)))),
      _Item('إدارة المناطق (زون)', 'المناطق داخل كل مشروع', Icons.map, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminZonesScreen(admin: widget.currentUser)))),
      _Item('إدارة المباني', 'المباني وتفاصيل النماذج', Icons.apartment, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBuildingsScreen(admin: widget.currentUser)))),
      _Item('إدارة الوحدات', 'وحدات كل مبنى (Th1-M01، Th2-M02) مع الصور', Icons.door_front_door, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUnitsScreen(admin: widget.currentUser)))),
      _Item('إدارة التشوينات', 'الخامات والكميات الخاصة بكل مبنى', Icons.inventory, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBuildingMaterialsScreen(admin: widget.currentUser)))),
      _Item('إدارة القطعيات', 'صور القطعيات لكل مبنى (للمهندس)', Icons.photo_library, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCutlistsScreen(admin: widget.currentUser)))),
      _Item('إدارة المشرفين', 'أسماء المشرفين', Icons.badge, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSupervisorsScreen(admin: widget.currentUser)))),
      _Item('إدارة المقاولين', 'أسماء المقاولين', Icons.engineering, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminContractorsScreen(admin: widget.currentUser)))),
      _Item('ساعات العمال', 'تقرير ساعات العمل من الحضور والانصراف (مهندس موقع / مشرف عام)', Icons.access_time, () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkerHoursReportScreen(admin: widget.currentUser)))),
      _Item('الخامات', 'إضافة وتعديل وحذف أسماء الخامات على مستوى التطبيق', Icons.inventory_2, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminMaterialsScreen(admin: widget.currentUser)))),
      _Item('ارصدة مخازن المشاريع', 'إضافة وتعديل وعرض أرصدة الخامات لكل مشروع (اسم المخزن = اسم المشروع)', Icons.warehouse, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProjectStoresScreen(admin: widget.currentUser)))),
      _Item('هيكلة المخازن', 'أماكن فرعية داخل كل مشروع مع خامات وكمياتها للسحب من قبل مهندس الموقع', Icons.account_tree, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminWarehouseStructureScreen(admin: widget.currentUser)))),
    ];
    if (widget.currentUser.canManageWarehouseWithdrawalReset) {
      items.add(_Item(
        'المخزن (سحب الخامات)',
        'إلغاء السحب واسترجاع المخزن لإعادة السحب أو بعد إضافة كميات تكميلية في هيكلة المخزن',
        Icons.warehouse,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminWarehouseWithdrawScreen(admin: widget.currentUser))),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوح التحكم'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
          await saveLastRoute('home');
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: widget.currentUser)));
        },
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (widget.currentUser.canManageWarehouseWithdrawalReset ? 1 : 0),
        itemBuilder: (context, i) {
          if (widget.currentUser.canManageWarehouseWithdrawalReset && i == 0) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: SwitchListTile(
                secondary: Icon(
                  _systemLocked ? Icons.build_circle : Icons.lock_open,
                  color: const Color(0xFF1B5E20),
                ),
                title: const Text('System Lock (Maintenance)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_systemLocked ? 'النظام مقفول حالياً لجميع المستخدمين' : 'النظام متاح لتسجيل الدخول'),
                value: _systemLocked,
                onChanged: _systemLockLoading ? null : _toggleSystemLocked,
              ),
            );
          }
          final dataIndex = i - (widget.currentUser.canManageWarehouseWithdrawalReset ? 1 : 0);
          final item = items[dataIndex];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(item.icon, color: const Color(0xFF1B5E20)),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.onTap,
            ),
          );
        },
      ),
    );
  }
}

class _Item {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  _Item(this.title, this.subtitle, this.icon, this.onTap);
}
