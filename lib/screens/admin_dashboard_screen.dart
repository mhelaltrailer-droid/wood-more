import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'admin_users_screen.dart';
import 'admin_projects_screen.dart';
import 'admin_zones_screen.dart';
import 'admin_buildings_screen.dart';
import 'admin_supervisors_screen.dart';
import 'admin_contractors_screen.dart';
import 'admin_materials_screen.dart';
import 'admin_project_stores_screen.dart';
import 'admin_units_screen.dart';
import 'admin_building_materials_screen.dart';
import 'admin_cutlists_screen.dart';
import 'salary_deduction_screen.dart';
import 'sub_reports_screen.dart';
import 'home_screen.dart';

/// لوح التحكم - يظهر لمسؤول التطبيق فقط
class AdminDashboardScreen extends StatelessWidget {
  final UserModel currentUser;

  const AdminDashboardScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item('إدارة المستخدمين', 'إضافة وتعديل وحذف المستخدمين والأدوار', Icons.people, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUsersScreen(admin: currentUser)))),
      _Item('إدارة المشاريع', 'إضافة وتعديل وحذف المشاريع', Icons.business, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProjectsScreen(admin: currentUser)))),
      _Item('إدارة المناطق (زون)', 'المناطق داخل كل مشروع', Icons.map, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminZonesScreen(admin: currentUser)))),
      _Item('إدارة المباني', 'المباني وتفاصيل النماذج', Icons.apartment, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBuildingsScreen(admin: currentUser)))),
      _Item('مخازن المشاريع (الأرصدة)', 'أرصدة الخامات في مخزن كل مشروع', Icons.warehouse, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProjectStoresScreen(admin: currentUser)))),
      _Item('إدارة الوحدات', 'وحدات كل مبنى (Th1-M01، Th2-M02) مع الصور', Icons.door_front_door, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUnitsScreen(admin: currentUser)))),
      _Item('إدارة التشوينات', 'الخامات والكميات الخاصة بكل مبنى', Icons.inventory, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBuildingMaterialsScreen(admin: currentUser)))),
      _Item('إدارة القطعيات', 'صور القطعيات لكل مبنى (للمهندس)', Icons.photo_library, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCutlistsScreen(admin: currentUser)))),
      _Item('إدارة المشرفين', 'أسماء المشرفين', Icons.badge, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSupervisorsScreen(admin: currentUser)))),
      _Item('إدارة المقاولين', 'أسماء المقاولين', Icons.engineering, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminContractorsScreen(admin: currentUser)))),
      _Item('إدارة الخامات', 'إضافة وتعديل وحذف الخامات', Icons.inventory_2, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminMaterialsScreen(admin: currentUser)))),
      _Item('تقارير فرعية', 'تقرير المقاول، عدد العمال، عهدة المستخدم، حضور وانصراف', Icons.assignment, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubReportsScreen(admin: currentUser)))),
      _Item('خصم من المرتب', 'نموذج خصم من المرتب | Salary Deduction Form', Icons.receipt_long, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SalaryDeductionScreen(admin: currentUser)))),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوح التحكم'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: currentUser))),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
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
