import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import '../errors/exceptions.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService(this._storage);

  Future<String> uploadDocumento(File file, String userId) async {
    try {
      final ext = p.extension(file.path);
      final filename = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final path = 'documentos/$userId/$filename';
      
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(file);
      
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw ServerException('Error al subir documento: $e');
    }
  }
}
