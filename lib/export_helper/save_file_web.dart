// lib/export_helper/save_file_web.dart

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void saveFileWeb(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor =
      html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
  html.Url.revokeObjectUrl(url);
}
