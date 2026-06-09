import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../models/factura_proveedor_model.dart';

class FacturaProveedorFirestoreDatasource {
  final fs.FirebaseFirestore _db;
  FacturaProveedorFirestoreDatasource(this._db);

  static const _col = 'facturas_proveedores';

  Stream<List<FacturaProveedorModel>> watchFacturas() {
    return _db
        .collection(_col)
        .orderBy('fecha_emision', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FacturaProveedorModel.fromFirestore).toList());
  }

  Future<String> crearFactura(FacturaProveedorModel model) async {
    final ref = await _db.collection(_col).add(model.toFirestore());
    return ref.id;
  }

  Future<void> registrarPago(
      String id, double monto, DateTime fecha) async {
    await _db.collection(_col).doc(id).update({
      'estatus':       'pagada',
      'monto_pagado':  monto,
      'fecha_pago':    fs.Timestamp.fromDate(fecha),
    });
  }

  Future<void> cancelarFactura(String id) async {
    await _db.collection(_col).doc(id).update({'estatus': 'cancelada'});
  }
}
