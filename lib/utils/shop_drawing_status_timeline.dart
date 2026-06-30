import 'package:intl/intl.dart';

import '../models/shop_drawing_model.dart';

/// سطر في ملخص مسار طلب Shop-Drawing / PO.
class ShopDrawingStatusLine {
  final String text;
  final bool isPending;

  const ShopDrawingStatusLine(this.text, {this.isPending = false});
}

List<ShopDrawingStatusLine> buildShopDrawingStatusTimeline(
  ShopDrawingModel drawing, {
  DateFormat? formatter,
}) {
  final fmt = formatter ?? DateFormat('dd/MM/yyyy HH:mm', 'ar');
  final lines = <ShopDrawingStatusLine>[];
  final actions = [...drawing.actions]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  if (actions.isEmpty) {
    lines.add(
      ShopDrawingStatusLine(
        'تم الإنشاء من ${drawing.createdByUserName} — ${fmt.format(drawing.createdAt)}',
      ),
    );
  } else {
    for (final action in actions) {
      switch (action.action) {
        case 'created':
          lines.add(
            ShopDrawingStatusLine(
              'تم الإنشاء من ${action.actorUserName} — ${fmt.format(action.createdAt)}',
            ),
          );
          break;
        case 'resubmit':
          lines.add(
            ShopDrawingStatusLine(
              'تم إعادة الإرسال من ${action.actorUserName} — ${fmt.format(action.createdAt)}',
            ),
          );
          break;
        case 'pm_approve':
          lines.add(
            ShopDrawingStatusLine(
              'تم الاعتماد من مدير المشروعات — ${fmt.format(action.createdAt)}',
            ),
          );
          break;
        case 'pm_return':
          lines.add(
            ShopDrawingStatusLine(
              'أُعيد للمكتب الفني من مدير المشروعات — ${fmt.format(action.createdAt)}',
            ),
          );
          break;
        case 'om_approve':
          lines.add(
            ShopDrawingStatusLine(
              'تم الاعتماد من مدير العمليات — ${fmt.format(action.createdAt)}',
            ),
          );
          break;
      }
    }
  }

  switch (drawing.status) {
    case ShopDrawingModel.statusPendingPm:
      lines.add(
        const ShopDrawingStatusLine(
          'في انتظار إجراء / اعتماد من مدير المشروعات',
          isPending: true,
        ),
      );
      break;
    case ShopDrawingModel.statusReturnedToTo:
      lines.add(
        const ShopDrawingStatusLine(
          'في انتظار تعديل وإعادة إرسال من المكتب الفني',
          isPending: true,
        ),
      );
      break;
    case ShopDrawingModel.statusPendingOm:
      lines.add(
        const ShopDrawingStatusLine(
          'في انتظار اعتماد مدير العمليات',
          isPending: true,
        ),
      );
      break;
  }

  return lines;
}
