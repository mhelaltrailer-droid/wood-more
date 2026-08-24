import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'detailed_report_screen.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _todayOnly() {
  final t = _dateOnly(DateTime.now());
  return t;
}

DateTime _tomorrowOnly() {
  return _todayOnly().add(const Duration(days: 1));
}

DateTime _yesterdayOnly() {
  return _todayOnly().subtract(const Duration(days: 1));
}

/// شاشة خطة عمل الغد: تاريخ التنفيذ الافتراضي غداً، مع تقييد التواريخ
/// (أمس كحد أقصى للماضي، أو اليوم، أو أي يوم قادم)،
/// وحفظ مباشر دون خطوة الماليات.
class TomorrowWorkPlanScreen extends StatelessWidget {
  final UserModel user;

  const TomorrowWorkPlanScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final tomorrow = _tomorrowOnly();
    final yesterday = _yesterdayOnly();
    return DetailedReportScreen(
      user: user,
      appBarTitle: 'خطة عمل الغد',
      allowManualWorkLocationWhenNoStructure: true,
      showExecutedTodaySummaryField: true,
      executedTodaySummaryRequired: true,
      showSummaryField: true,
      summaryFieldLabel: 'تفاصيل خطة عمل الغد',
      summaryMaxLines: 6,
      summaryRequired: true,
      enableNoWorkPlanOption: true,
      showAttachmentsSection: false,
      showPlannedExecutionDate: true,
      showCraftsmanAndAssistantCounts: true,
      plannedExecutionDefaultDate: tomorrow,
      plannedExecutionMinSelectableDate: yesterday,
      continueToFinancesOnNext: false,
      primaryWorkActionLabel: 'حفظ الخطة',
      workSavedSuccessMessage: 'تم حفظ الخطة',
    );
  }
}
