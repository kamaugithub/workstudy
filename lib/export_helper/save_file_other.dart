// lib/export_helper/save_file_other.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> saveFileOther(Uint8List bytes, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = "${directory.path}/$fileName";

  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);

  return path;
}
