import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/route_persistence.dart';
import '../services/route_restore.dart';
import 'custody_expenses_view_screen.dart';
import 'home_screen.dart';
import 'operation_manager_balances_view_screen.dart';

class OperationManagerCustodyBalancesHubScreen extends StatelessWidget {
  final UserModel currentUser;

  const OperationManagerCustodyBalancesHubScreen({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العهد/الارصدة/المصروفات'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await saveLastRoute('home');
            if (!context.mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(currentUser: currentUser),
              ),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HubCard(
            icon: Icons.receipt_long_outlined,
            title: 'العهد / المصروفات',
            subtitle: 'عرض بيانات الصرف وسجل الحركات كما هو متاح حالياً',
            onTap: () => pushAndSaveRoute(
              context,
              'operation-manager-custody-expenses-view',
              CustodyExpensesViewScreen(
                currentUser: currentUser,
                appBarTitle: 'العهده/ المصروفات',
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HubCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'الأرصدة',
            subtitle: 'الاطلاع فقط على أرصدة كل المستخدمين',
            onTap: () => pushAndSaveRoute(
              context,
              'operation-manager-balances-view',
              OperationManagerBalancesViewScreen(currentUser: currentUser),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
