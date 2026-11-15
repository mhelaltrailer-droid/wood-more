import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/reports_sys_model.dart';
import 'pdf_share.dart';

const PdfColor _brandGreen = PdfColor.fromInt(0xFF1B5E20);
const PdfColor _brandGreenLight = PdfColor.fromInt(0xFFE8F5E9);
const PdfColor _brandGreenMid = PdfColor.fromInt(0xFF2E7D32);

typedef ReportsSysAttachmentLoader = Future<Map<String, String>> Function(
  int attachmentId,
);

/// بناء ومشاركة PDF لتقرير Reports-SYS مؤرشف (هوية خضراء + مسار + صور).
Future<void> shareReportsSysArchivePdf({
  required ReportsSysModel report,
  ReportsSysAttachmentLoader? loadAttachment,
}) async {
  final fontBase = await PdfGoogleFonts.tajawalRegular();
  final fontBold = await PdfGoogleFonts.tajawalBold();
  final fontBoldItalic = await PdfGoogleFonts.amiriBoldItalic();
  final theme = pw.ThemeData.withFont(
    base: fontBase,
    bold: fontBold,
    italic: fontBoldItalic,
    boldItalic: fontBoldItalic,
  );

  pw.ImageProvider? logoImage;
  try {
    final logoBytes = await rootBundle.load('assets/images/logo.png');
    logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  } catch (_) {}

  final fmt = DateFormat('dd/MM/yyyy HH:mm', 'ar');
  final archiveAction = _archiveAction(report);
  final archivedByName = archiveAction?.actorUserName.trim().isNotEmpty == true
      ? archiveAction!.actorUserName
      : '—';
  final archivedAt = archiveAction?.createdAt ?? report.archivedAt;
  final archivedAtLabel =
      archivedAt != null ? fmt.format(archivedAt) : '—';

  final imageBytes = await _loadImageAttachments(report, loadAttachment);

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      textDirection: pw.TextDirection.rtl,
      build: (ctx) => [
        if (logoImage != null)
          pw.Center(
            child: pw.Container(
              height: 52,
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ),
        pw.Center(
          child: pw.Text(
            'Reports-SYS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _brandGreen,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            report.reportName.trim().isEmpty ? 'تقرير مؤرشف' : report.reportName,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _brandGreenMid,
            ),
          ),
        ),
        if (report.reportType.trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(
              report.reportType,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
        ],
        pw.SizedBox(height: 14),
        _metaBlock(
          projectName: report.projectName,
          creatorName: report.createdByUserName,
          createdAtLabel: fmt.format(report.createdAt),
          archivedByLabel: '$archivedByName — $archivedAtLabel',
        ),
        pw.SizedBox(height: 16),
        _technicalReportSection(
          summary: report.summary,
          notes: report.notes,
        ),
        pw.SizedBox(height: 16),
        _pathSection(report.actions, fmt),
        if (imageBytes.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _imagesSection(imageBytes),
        ],
      ],
    ),
  );

  final bytes = await doc.save();
  final safeName = report.reportName
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(' ', '_');
  final fileName =
      'reports_sys_${report.id}_${safeName.isEmpty ? 'archived' : safeName}.pdf';
  await sharePdfBytes(Uint8List.fromList(bytes), fileName);
}

ReportsSysActionModel? _archiveAction(ReportsSysModel report) {
  for (var i = report.actions.length - 1; i >= 0; i--) {
    if (report.actions[i].action == 'archive') return report.actions[i];
  }
  return null;
}

Future<List<_PdfImage>> _loadImageAttachments(
  ReportsSysModel report,
  ReportsSysAttachmentLoader? loadAttachment,
) async {
  final out = <_PdfImage>[];
  for (final att in report.attachments) {
    if (!_isImageMime(att.mimeType, att.fileName)) continue;
    Uint8List? bytes;
    if (att.dataBase64 != null && att.dataBase64!.trim().isNotEmpty) {
      bytes = _decodeBase64(att.dataBase64!);
    } else if (loadAttachment != null) {
      try {
        final data = await loadAttachment(att.id);
        bytes = _decodeBase64(data['data_base64'] ?? '');
      } catch (_) {
        bytes = null;
      }
    }
    if (bytes == null || bytes.isEmpty) continue;
    out.add(_PdfImage(fileName: att.fileName, bytes: bytes));
  }
  return out;
}

bool _isImageMime(String mimeType, String fileName) {
  final mime = mimeType.trim().toLowerCase();
  if (mime.startsWith('image/')) return true;
  final ext = fileName.split('.').last.toLowerCase();
  return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext);
}

Uint8List? _decodeBase64(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final comma = s.indexOf(',');
  if (s.startsWith('data:') && comma >= 0) {
    s = s.substring(comma + 1);
  }
  try {
    return Uint8List.fromList(base64Decode(s));
  } catch (_) {
    return null;
  }
}

pw.Widget _metaBlock({
  required String projectName,
  required String creatorName,
  required String createdAtLabel,
  required String archivedByLabel,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: _brandGreenLight,
      border: pw.Border.all(color: _brandGreen, width: 0.9),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _metaRow('اسم المشروع', projectName.trim().isEmpty ? '—' : projectName),
        _metaRow('المنشئ', creatorName.trim().isEmpty ? '—' : creatorName),
        _metaRow('تاريخ الإنشاء', createdAtLabel),
        _metaRow('تم الحفظ/الأرشفة بواسطة', archivedByLabel),
      ],
    ),
  );
}

pw.Widget _metaRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.RichText(
      textAlign: pw.TextAlign.right,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _brandGreen,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _technicalReportSection({
  required String summary,
  required String? notes,
}) {
  final notesTrimmed = notes?.trim() ?? '';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        'التقرير الفني',
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _brandGreen,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _brandGreen, width: 0.7),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              summary.trim().isEmpty ? '—' : summary.trim(),
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
            ),
            if (notesTrimmed.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'ملاحظات',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandGreenMid,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                notesTrimmed,
                textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

pw.Widget _pathSection(List<ReportsSysActionModel> actions, DateFormat fmt) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        'مسار التقرير',
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _brandGreen,
        ),
      ),
      pw.SizedBox(height: 10),
      if (actions.isEmpty)
        pw.Text(
          'لا يوجد مسار بعد',
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        )
      else
        ...actions.map((a) {
          final phrase = a.displayPhraseAr;
          final comment = a.comment?.trim() ?? '';
          final showComment =
              comment.isNotEmpty && comment != phrase.trim();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 8,
                  height: 8,
                  margin: const pw.EdgeInsets.only(top: 3),
                  decoration: const pw.BoxDecoration(
                    color: _brandGreen,
                    shape: pw.BoxShape.circle,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(
                        phrase,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      if (showComment)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(
                            comment,
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 1),
                        child: pw.Text(
                          fmt.format(a.createdAt),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
    ],
  );
}

pw.Widget _imagesSection(List<_PdfImage> images) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text(
        'الصور',
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _brandGreen,
        ),
      ),
      pw.SizedBox(height: 10),
      ...images.map((img) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (img.fileName.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    img.fileName,
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(img.bytes),
                  fit: pw.BoxFit.contain,
                  height: 220,
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}

class _PdfImage {
  final String fileName;
  final Uint8List bytes;
  const _PdfImage({required this.fileName, required this.bytes});
}
