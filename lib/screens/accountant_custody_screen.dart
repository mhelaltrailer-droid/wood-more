import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'site_engineer_expenses_report_screen.dart';

/// شاشة العهدة للمحاسب: عرض بنود صرف مهندسي المواقع حسب المستخدم والمدة.
class AccountantCustodyScreen extends StatelessWidget {
  final UserModel currentUser;

  const AccountantCustodyScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return SiteEngineerExpensesReportScreen(
      currentUser: currentUser,
      appBarTitle: 'تقرير العهدة',
    );
  }
}
