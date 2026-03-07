import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'contractor_report_screen.dart';
import 'workers_report_screen.dart';
import 'user_custody_report_screen.dart';
import 'attendance_sub_report_screen.dart';
import 'home_screen.dart';

/// تقارير فرعية - من لوحة التحكم: 4 تقارير بنفس أسلوب التقرير اليومي + تصدير PDF
class SubReportsScreen extends StatelessWidget {
  final UserModel admin;

  const SubReportsScreen({super.key, required this.admin});

  @override
  Widget build(BuildContext context) {
    final items = [
      _SubItem(
        'تقرير المقاول',
        'تقرير باسم المقاول مع تحديد التاريخ - المشاريع وعدد العمال في كل تقرير',
        Icons.engineering,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContractorReportScreen(admin: admin))),
      ),
      _SubItem(
        'تقرير عدد العمال',
        'تحديد المدة من يوم ليوم - عدد العمال مع اسم المشروع والمقاول والمهندس',
        Icons.groups,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkersReportScreen(admin: admin))),
      ),
      _SubItem(
        'تقرير عهدة المستخدم',
        'اختيار المستخدم وتحديد المدة - كل الحركات على حساب العهدة',
        Icons.account_balance_wallet,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserCustodyReportScreen(admin: admin))),
      ),
      _SubItem(
        'تقرير حضور وانصراف',
        'تحديد المدة من يوم ليوم - كل حركات الحضور والانصراف',
        Icons.fingerprint,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceSubReportScreen(admin: admin))),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير فرعية'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen(currentUser: admin))),
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

class _SubItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  _SubItem(this.title, this.subtitle, this.icon, this.onTap);
}
