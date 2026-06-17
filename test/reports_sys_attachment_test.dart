import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wood_and_more_app/widgets/reports_sys_attachments_panel.dart';
import 'package:wood_and_more_app/models/reports_sys_model.dart';

void main() {
  group('reports_sys_attachments_panel helpers', () {
    test('decodeReportsSysAttachmentBytes strips data URL prefix', () {
      final png1x1 = base64Encode(
        Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        ]),
      );
      final raw = decodeReportsSysAttachmentBytes(
        'data:image/png;base64,$png1x1',
      );
      expect(raw, isNotNull);
      expect(raw!.length, greaterThan(0));
    });

    test('reportsSysAttachmentIsImage detects by mime and extension', () {
      final byMime = ReportsSysAttachmentModel(
        id: 1,
        fileName: 'x.bin',
        mimeType: 'image/png',
        sizeBytes: 1,
        createdAt: DateTime(2026, 1, 1),
      );
      final byExt = ReportsSysAttachmentModel(
        id: 2,
        fileName: 'photo.jpg',
        mimeType: 'application/octet-stream',
        sizeBytes: 1,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(reportsSysAttachmentIsImage(byMime), isTrue);
      expect(reportsSysAttachmentIsImage(byExt), isTrue);
    });
  });
}
