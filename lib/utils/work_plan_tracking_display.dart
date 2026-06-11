import 'package:flutter/material.dart';

import '../models/detailed_report_model.dart';
import '../models/project_location_model.dart';

/// تباعد أسطر نص خلايا جدول متابعة الخطط (الشاشة).
const double kWorkPlanTableTextLineHeight = 1.45;

/// نمط موحّد لنص خلايا الجدول — يمنع تداخل الأسطر.
const TextStyle kWorkPlanTableCellTextStyle = TextStyle(
  fontSize: 13,
  height: kWorkPlanTableTextLineHeight,
);

/// تباعد أسطر نص خلايا PDF.
const double kWorkPlanPdfLineSpacing = 2.8;

/// مكان العمل: الأب ثم الفرع بين أقواس (مثل التقرير المجمع).
String formatWorkPlanLocationHierarchy(
  ProjectLocationModel loc,
  Map<int, ProjectLocationModel> byId,
) {
  final parent = loc.parentId != null ? byId[loc.parentId!] : null;
  if (parent != null) {
    return '${parent.name} (${loc.name})';
  }
  return loc.name;
}

/// عمود «مكان العمل — المستوى الأول»: هيكلة المشروع أو النص اليدوي عند غياب الهيكلة.
String workplaceLevel1ForLine(
  DetailedReportLineModel line,
  Map<int, ProjectLocationModel> locationById,
) {
  if (line.locationId != null) {
    final loc = locationById[line.locationId!];
    if (loc != null) {
      return formatWorkPlanLocationHierarchy(loc, locationById);
    }
  }
  final manual = line.manualWorkLocation?.trim();
  if (manual != null && manual.isNotEmpty) {
    return manual;
  }
  return '—';
}

/// نص «ملخص ما تم تنفيذه اليوم» للعرض في التقرير.
String formatExecutedTodaySummaryForReport(String? raw) {
  final t = (raw ?? '').trim();
  return t.isEmpty ? '—' : t;
}

/// عدد أعمدة PDF يجب أن يطابق الرؤوس وخلايا البيانات.
int workPlanTrackingPdfColumnCount({
  required bool showMaterials,
  required bool showExecutedTodaySummary,
  required bool showExecution,
  required bool showTomorrowStatus,
}) {
  var n = 7; // مهندس، مشروع، تاريخ، مكان، مرحلة، تفاصيل، مقاول
  if (showExecutedTodaySummary) n++;
  if (showMaterials) n++;
  if (showExecution) n++;
  if (showTomorrowStatus) n++;
  return n;
}
