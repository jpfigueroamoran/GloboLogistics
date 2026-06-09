import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../models/factura_cliente_model.dart';

class FacturaClienteFirestoreDatasource {
  final fs.FirebaseFirestore _db;
  FacturaClienteFirestoreDatasource(this._db);

  static const _col = 'facturas_clientes';

  Stream<List<FacturaClienteModel>> watchFacturas() {
    return _db
        .collection(_col)
        .orderBy('fecha_emision', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FacturaClienteModel.fromFirestore).toList());
  }

  Future<String> crearFactura(FacturaClienteModel model) async {
    final ref = await _db.collection(_col).add(model.toFirestore());
    return ref.id;
  }

  Future<void> registrarCobro(
      String id, double monto, DateTime fecha) async {
    await _db.collection(_col).doc(id).update({
      'estatus': 'cobrada',
      'monto_cobrado': monto,
      'fecha_cobro': fs.Timestamp.fromDate(fecha),
    });
  }

  Future<void> cancelarFactura(String id) async {
    await _db.collection(_col).doc(id).update({'estatus': 'cancelada'});
  }

  Future<void> registrarCartaPorte(String id, String uuid) async {
    await _db.collection(_col).doc(id).update({'carta_porte_uuid': uuid});
  }
}
