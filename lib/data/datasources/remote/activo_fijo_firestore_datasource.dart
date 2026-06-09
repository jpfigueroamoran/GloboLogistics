import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../models/activo_fijo_model.dart';

class ActivoFijoFirestoreDatasource {
  final fs.FirebaseFirestore _db;
  ActivoFijoFirestoreDatasource(this._db);

  static const _col = 'activos_fijos';

  Stream<List<ActivoFijoModel>> watchActivosFijos() {
    return _db
        .collection(_col)
        .orderBy('descripcion')
        .snapshots()
        .map((s) => s.docs.map(ActivoFijoModel.fromFirestore).toList());
  }

  Future<String> crearActivo(ActivoFijoModel model) async {
    final ref = await _db.collection(_col).add(model.toFirestore());
    return ref.id;
  }

  Future<void> actualizarActivo(String id, Map<String, dynamic> data) =>
      _db.collection(_col).doc(id).update(data);

  Future<void> eliminarActivo(String id) =>
      _db.collection(_col).doc(id).delete();
}
