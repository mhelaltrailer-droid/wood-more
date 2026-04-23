import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'detailed_report_screen.dart';

/// شاشة خطة عمل الغد (نسخة مبدئية).
/// حاليا تعرض نفس خطوات "التقرير اليومي (التقرير المفصل)" حرفيا،
/// وسيتم تخصيصها لاحقا خطوة بخطوة.
class TomorrowWorkPlanScreen extends StatelessWidget {
  final UserModel user;

  const TomorrowWorkPlanScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DetailedReportScreen(
      user: user,
      appBarTitle: 'خطة عمل الغد',
      showSummaryField: true,
      summaryFieldLabel: 'تفاصيل خطة العمل',
      summaryMaxLines: 6,
      summaryRequired: true,
      showAttachmentsSection: false,
      showPlannedExecutionDate: true,
      showCraftsmanAndAssistantCounts: true,
    );
  }
}
