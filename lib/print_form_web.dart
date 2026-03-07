// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

/// طباعة صورة النموذج (ويب فقط) - يفتح نافذة بالصورة بمقاس A4 ويستدعي نافذة الطباعة
void printFormAsImage(List<int> pngBytes) {
  final base64 = base64Encode(pngBytes);
  final dataUrl = 'data:image/png;base64,$base64';
  final htmlContent = '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>نموذج خصم من المرتب</title>
<style>
  @page { size: A4; margin: 0; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 210mm; height: 297mm; margin: 0; background: #fff; overflow: hidden; }
  .page { width: 210mm; height: 297mm; display: block; }
  .page img { width: 210mm; height: 297mm; display: block; object-fit: fill; }
  @media print {
    html, body { width: 210mm; height: 297mm; margin: 0; padding: 0; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    .page, .page img { width: 210mm; height: 297mm; object-fit: fill; }
  }
</style></head>
<body><div class="page"><img src="$dataUrl" alt="نموذج خصم من المرتب" /></div>
<script>window.onload=function(){window.print();}</script>
</body></html>''';
  final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}
