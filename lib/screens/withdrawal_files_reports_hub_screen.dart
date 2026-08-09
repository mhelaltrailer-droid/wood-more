import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/route_restore.dart';
import 'material_withdrawals_report_screen.dart';
import 'uploaded_files_report_screen.dart';

/// محور تقريرَي السحب والمرفقات.
class WithdrawalFilesReportsHubScreen extends StatelessWidget {
  final UserModel currentUser;

  const WithdrawalFilesReportsHubScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final items = <_HubItem>[
      _HubItem(
        icon: Icons.warehouse_outlined,
        title: 'تقرير سحب الخامات',
        subtitle:
            'المشاريع ومواقع العمل التي تم سحب خامتها — طلب سحب فقط أم تم إكمال السحب مع أذون الصرف والتسليم',
        routeName: 'material-withdrawals-report',
        screen: MaterialWithdrawalsReportScreen(currentUser: currentUser),
      ),
      _HubItem(
        icon: Icons.folder_open_outlined,
        title: 'تقرير الملفات المرفوعة',
        subtitle:
            'IR · MIR · MS · SD · MoS · ITP · Shop-Drawing · أذون السحب — اسم المشروع وتاريخ الرفع والمستخدم الرافع ونوع المرفق',
        routeName: 'uploaded-files-report',
        screen: UploadedFilesReportScreen(currentUser: currentUser),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير السحب والمرفقات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
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
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  pushAndSaveRoute(context, item.routeName, item.screen),
            ),
          );
        },
      ),
    );
  }
}

class _HubItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String routeName;
  final Widget screen;

  const _HubItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.routeName,
    required this.screen,
  });
}
