import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/widgets/shop_drawing_content_flags_panel.dart';

void main() {
  testWidgets('يعرض علامة صح للعناصر المحددة في وضع القراءة فقط', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ShopDrawingContentFlagsPanel(
            contentSd: true,
            contentQs: false,
            contentDashboard: true,
            readOnly: true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_box_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
    expect(find.text('SD'), findsOneWidget);
    expect(find.text('QS'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
