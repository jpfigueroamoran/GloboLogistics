import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../models/item_inventario_model.dart';
import '../../../domain/entities/movimiento_inventario.dart';

class InventarioFirestoreDatasource {
  final fs.FirebaseFirestore _db;
  InventarioFirestoreDatasource(this._db);

  static const _colItems      = 'inventario';
  static const _colMovimientos = 'movimientos_inventario';

  Stream<List<ItemInventarioModel>> watchItems() {
    return _db
        .collection(_colItems)
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs.map(ItemInventarioModel.fromFirestore).toList());
  }

  Future<void> actualizarStock(String itemId, double nuevoStock) async {
    await _db.collection(_colItems).doc(itemId).update({
      'stock_actual':          nuevoStock,
      'ultima_actualizacion':  fs.FieldValue.serverTimestamp(),
    });
  }

  Future<String> registrarMovimiento(MovimientoInventario mov) async {
    final batch = _db.batch();

    // 1. Crear movimiento
    final movRef = _db.collection(_colMovimientos).doc();
    batch.set(movRef, {
      'item_id':         mov.itemId,
      'tipo':            mov.tipo.name,
      'cantidad':        mov.cantidad,
      'precio_unitario': mov.precioUnitario,
      'fecha':           fs.Timestamp.fromDate(mov.fecha),
      'viaje_id':        mov.viajeId,
      'unidad_id':       mov.unidadId,
      'motivo':          mov.motivo,
    });

    // 2. Actualizar stock del item
    final itemRef = _db.collection(_colItems).doc(mov.itemId);
    final delta = mov.tipo == TipoMovimiento.entrada
        ? mov.cantidad
        : -mov.cantidad;
    batch.update(itemRef, {
      'stock_actual':         fs.FieldValue.increment(delta),
      'ultima_actualizacion': fs.FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return movRef.id;
  }
}
