import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/route_persistence.dart';
import 'accountant_finance_screen.dart';
import 'detailed_report_finances_screen.dart';
import 'expense_statements_screen.dart';
import 'home_screen.dart';

/// محور العهد / تقارير المصروفات لمدير المشروعات: 3 خيارات.
class ManagerCustodyExpensesHubScreen extends StatelessWidget {
  final UserModel currentUser;

  const ManagerCustodyExpensesHubScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العهد/تقارير المصروفات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HomeScreen(currentUser: currentUser)),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HubCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'العهد',
            subtitle: 'أرصدة المستخدمين — إضافة وسحب رصيد',
            onTap: () => pushAndSaveRoute(
              context,
              'manager-custody-hub-balances',
              AccountantFinanceScreen(currentUser: currentUser),
            ),
          ),
          const SizedBox(height: 16),
          _HubCard(
            icon: Icons.receipt_long_outlined,
            title: 'تقارير المصروفات',
            subtitle: 'بيانات صرف مهندسي المواقع — اعتماد أو رفض',
            onTap: () => pushAndSaveRoute(
              context,
              'manager-custody-hub-reports',
              ExpenseStatementsScreen(
                currentUser: currentUser,
                appBarTitle: 'تقارير المصروفات',
                allowRespond: true,
                allowDelete: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HubCard(
            icon: Icons.add_circle_outline,
            title: '+ ادخال بيان صرف',
            subtitle: 'إدخال بيان معتمد مباشرة وخصم من رصيدك',
            onTap: () => pushAndSaveRoute(
              context,
              'manager-custody-hub-entry',
              DetailedReportFinancesScreen.managerDirectEntry(user: currentUser),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: const Color(0xFF1B5E20)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
