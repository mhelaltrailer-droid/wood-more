import 'package:flutter/material.dart';

import '../models/contractor_model.dart';
import '../models/detailed_report_model.dart';
import '../models/project_location_model.dart';
import '../models/user_model.dart';
import '../models/withdrawal_request_model.dart';

/// تباعد أسطر نص خلايا جدول متابعة الخطط (الشاشة).
const double kWorkPlanTableTextLineHeight = 1.58;

/// نمط موحّد لنص خلايا الجدول — يمنع تداخل الأسطر.
const TextStyle kWorkPlanTableCellTextStyle = TextStyle(
  fontSize: 13,
  height: kWorkPlanTableTextLineHeight,
);

/// تباعد أسطر نص خلايا PDF.
const double kWorkPlanPdfLineSpacing = 4.2;

/// حشوة عمودية/أفقية لخلايا الجدول على الشاشة.
const double kWorkPlanTableCellVerticalPadding = 14;
const double kWorkPlanTableCellHorizontalPadding = 6;

/// تباعد صفوف وأعمدة [DataTable] في متابعة الخطط.
const double kWorkPlanDataTableColumnSpacing = 18;
const double kWorkPlanDataTableHorizontalMargin = 16;
const double kWorkPlanDataTableHeadingRowHeight = 64;
const double kWorkPlanDataTableDataRowMinHeight = 68;

/// فراغ بين تاريخ التنفيذ ونص الملخص داخل الخلية.
const double kWorkPlanExecutedTodayInnerGap = 8;

/// حشوة خلايا PDF (رأس/جسم).
const double kWorkPlanPdfCellHdrVertical = 11;
const double kWorkPlanPdfCellHdrHorizontal = 7;
const double kWorkPlanPdfCellBodyVertical = 11;
const double kWorkPlanPdfCellBodyHorizontal = 6;
const double kWorkPlanPdfExecutedTodayInnerGap = 6;

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

/// اسم المقاول لسطر خطة: من الحقل المضمّن ثم جدول المقاولين المحمّل.
String contractorDisplayNameForLine(
  DetailedReportLineModel line,
  Map<int, ContractorModel> contractorById,
) {
  final embedded = line.contractorName?.trim();
  if (embedded != null && embedded.isNotEmpty) {
    return embedded;
  }
  if (line.contractorId == null) return '—';
  return contractorById[line.contractorId!]?.name ?? '—';
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

/// نص «ملخص ما تم تنفيذه اليوم» للعرض في التقرير (بدون تاريخ الحفظ).
String formatExecutedTodaySummaryForReport(String? raw) {
  final t = (raw ?? '').trim();
  return t.isEmpty ? '—' : t;
}

/// عند غياب الملخص في جدول متابعة الخطط.
const String kExecutedTodayTrackingEmptyLabel = 'لايوجد';

/// تاريخ حفظ الخطة بصيغة dd/MM/yyyy للعرض أعلى كل صف.
String formatPlanSavedDateLabel(DateTime? savedAt) {
  if (savedAt == null) return '—';
  final l = savedAt.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/'
      '${l.month.toString().padLeft(2, '0')}/'
      '${l.year}';
}

/// نص الملخص داخل الخلية (أو «لايوجد»).
String executedTodayBodyForTrackingReport(String? raw) {
  final t = (raw ?? '').trim();
  return t.isEmpty ? kExecutedTodayTrackingEmptyLabel : t;
}

/// محتوى خلية «ما تم تنفيذه اليوم» — تاريخ الحفظ + الملخص.
class ExecutedTodayCellContent {
  final String dateLabel;
  final String body;

  const ExecutedTodayCellContent({
    required this.dateLabel,
    required this.body,
  });

  String get pdfText => '$dateLabel\n$body';
}

ExecutedTodayCellContent executedTodayCellContent({
  required DateTime? planSavedAt,
  required String? executedTodaySummary,
}) {
  return ExecutedTodayCellContent(
    dateLabel: formatPlanSavedDateLabel(planSavedAt),
    body: executedTodayBodyForTrackingReport(executedTodaySummary),
  );
}

/// خلية جدول الشاشة: التاريخ في المنتصف أعلى النص.
Widget buildExecutedTodayTrackingTableCell(
  ExecutedTodayCellContent content, {
  required double width,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: kWorkPlanTableCellVerticalPadding,
      horizontal: kWorkPlanTableCellHorizontalPadding,
    ),
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            content.dateLabel,
            textAlign: TextAlign.center,
            style: kWorkPlanTableCellTextStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: kWorkPlanExecutedTodayInnerGap),
          Text(
            content.body,
            textAlign: TextAlign.center,
            softWrap: true,
            style: kWorkPlanTableCellTextStyle,
          ),
        ],
      ),
    ),
  );
}

/// عدد أعمدة PDF يجب أن يطابق الرؤوس وخلايا البيانات.
int workPlanTrackingPdfColumnCount({
  required bool showMaterials,
  required bool showExecutedTodaySummary,
  required bool showExecution,
}) {
  var n = 7; // مهندس، مشروع، تاريخ، مكان، مرحلة، تفاصيل، مقاول
  if (showExecutedTodaySummary) n++;
  if (showMaterials) n++;
  if (showExecution) n++;
  return n;
}

const String kWithdrawalTrackingEmptyLabel = '-';

/// اسم مكان السحب للعرض في عمود سحب الخامات (ورقة الموقع إن وُجدت).
String withdrawalLocationDisplayLabel(
  WithdrawalRequestModel r,
  Map<int, ProjectLocationModel> locationById,
) {
  final loc = locationById[r.locationId];
  final name = loc?.name.trim() ?? '';
  if (name.isNotEmpty) return name;
  final path = r.locationPathLabel.trim();
  if (path.isEmpty) return 'موقع #${r.locationId}';
  final parts = path.split(' / ');
  final leaf = parts.isEmpty ? path : parts.last.trim();
  return leaf.isEmpty ? path : leaf;
}

/// جملة حالة طلب سحب واحد وفق أمثلة تقرير متابعة خطة اليوم.
String formatWithdrawalRequestStatusLine(
  WithdrawalRequestModel r, {
  required String projectName,
  required String locationLabel,
}) {
  final loc = locationLabel.trim().isEmpty ? '—' : locationLabel.trim();
  final proj = projectName.trim().isEmpty ? '—' : projectName.trim();
  final base = 'تم طلب السحب لخامات "$loc" مشروع "$proj"';
  const sem = UserModel.siteEngineerManagerRoleLabel;
  const om = 'مدير العمليات';

  if (r.fulfilledAt != null) {
    return '$base و تم اكتمال عملية السحب.';
  }
  if (r.isRejectedOverall) {
    final who = r.semStatus == WithdrawalRequestModel.statusRejected ? sem : om;
    final reasonRaw = r.semStatus == WithdrawalRequestModel.statusRejected
        ? r.semReason
        : r.omReason;
    final reason = (reasonRaw ?? '').trim();
    if (reason.isNotEmpty) {
      return '$base تم رفض الطلب من "$who" بسبب: $reason';
    }
    return '$base تم رفض الطلب من "$who"';
  }
  if (r.isApprovedOverall) {
    return '$base تمت موافقة $sem و$om وبانتظار إكمال السحب من مهندس الموقع.';
  }
  if (r.semStatus == WithdrawalRequestModel.statusApproved &&
      r.omStatus == WithdrawalRequestModel.statusPending) {
    return '$base تم الموافقة من "$sem" في انتظار موافقة "$om" لإكمال عملية السحب';
  }
  if (r.omStatus == WithdrawalRequestModel.statusApproved &&
      r.semStatus == WithdrawalRequestModel.statusPending) {
    return '$base تم الموافقة من "$om" في انتظار موافقة "$sem" لإكمال عملية السحب';
  }
  return '$base في انتظار موافقة ($om + $sem) لإكمال عملية السحب';
}

/// نص خلية «سحب الخامات» لطلبات المهندس في يوم الخطة (سطر لكل طلب).
String formatWithdrawalRequestsForTrackingCell({
  required List<WithdrawalRequestModel> requests,
  required int engineerUserId,
  required DateTime planDate,
  required String Function(DateTime) dayKey,
  required Map<int, ProjectLocationModel> locationById,
  required Map<int, String> projectNameById,
}) {
  final dk = dayKey(planDate);
  final relevant = requests
      .where(
        (r) =>
            r.engineerUserId == engineerUserId && dayKey(r.createdAt) == dk,
      )
      .toList();
  if (relevant.isEmpty) return kWithdrawalTrackingEmptyLabel;
  return relevant
      .map(
        (r) => formatWithdrawalRequestStatusLine(
          r,
          projectName: (r.projectName?.trim().isNotEmpty == true)
              ? r.projectName!.trim()
              : (projectNameById[r.projectId] ?? '—'),
          locationLabel: withdrawalLocationDisplayLabel(r, locationById),
        ),
      )
      .join('\n');
}
