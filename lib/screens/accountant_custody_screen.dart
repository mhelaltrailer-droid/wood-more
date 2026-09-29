import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'expense_statements_screen.dart';

/// شاشة العهدة للمحاسب: بيانات الصرف من مسار الاعتماد فقط.
class AccountantCustodyScreen extends StatelessWidget {
  final UserModel currentUser;

  const AccountantCustodyScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return ExpenseStatementsScreen(
      currentUser: currentUser,
      appBarTitle: 'بيانات الصرف',
      allowRespond: false,
      allowDelete: false,
    );
  }
}
