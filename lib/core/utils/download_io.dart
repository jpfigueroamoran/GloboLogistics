import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

void descargar(List<int> bytes, String filename) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getDownloadsDirectory();
    }
    
    if (dir != null) {
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (kDebugMode) print('Archivo guardado en: ${file.path}');
    }
  } catch (e) {
    if (kDebugMode) print('Error al guardar archivo: $e');
  }
}
