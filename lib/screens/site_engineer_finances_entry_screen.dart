import 'package:flutter/material.dart';

import '../models/user_model.dart';
import 'detailed_report_finances_screen.dart';

/// مسار العهدة/المصروفات لمهندس الموقع — بيان صرف فقط (بدون ربط بخطة عمل).
class SiteEngineerFinancesEntryScreen extends StatelessWidget {
  final UserModel user;

  const SiteEngineerFinancesEntryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DetailedReportFinancesScreen.directEntry(user: user);
  }
}
