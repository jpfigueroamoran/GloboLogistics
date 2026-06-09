import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../models/poliza_seguro_model.dart';

class PolizaSeguroFirestoreDatasource {
  final fs.FirebaseFirestore _db;
  PolizaSeguroFirestoreDatasource(this._db);

  static const _col = 'polizas_seguro';

  Stream<List<PolizaSeguroModel>> watchPolizas() {
    return _db
        .collection(_col)
        .orderBy('vigencia_fin')
        .snapshots()
        .map((s) => s.docs.map(PolizaSeguroModel.fromFirestore).toList());
  }

  Future<String> crearPoliza(PolizaSeguroModel model) async {
    final ref = await _db.collection(_col).add(model.toFirestore());
    return ref.id;
  }

  Future<void> actualizarPoliza(String id, Map<String, dynamic> data) =>
      _db.collection(_col).doc(id).update(data);

  Future<void> eliminarPoliza(String id) =>
      _db.collection(_col).doc(id).delete();
}
