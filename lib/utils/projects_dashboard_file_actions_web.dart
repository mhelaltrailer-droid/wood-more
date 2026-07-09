// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadProjectsDashboardFile(String url, String fileName) {
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
}

void openProjectsDashboardInExcel(String officeUri) {
  html.window.location.href = officeUri;
}
