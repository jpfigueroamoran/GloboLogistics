import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/item_inventario.dart';

class ItemInventarioModel extends ItemInventario {
  const ItemInventarioModel({
    required super.id,
    required super.nombre,
    required super.categoria,
    required super.unidadMedida,
    required super.stockActual,
    required super.stockMinimo,
    required super.precioUnitario,
    super.unidadId,
    required super.ultimaActualizacion,
  });

  factory ItemInventarioModel.fromFirestore(
      fs.DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ItemInventarioModel(
      id:       doc.id,
      nombre:   d['nombre']    as String,
      categoria: CategoriaInventario.values.firstWhere(
        (e) => e.name == (d['categoria'] as String),
        orElse: () => CategoriaInventario.otro,
      ),
      unidadMedida: UnidadMedida.values.firstWhere(
        (e) => e.name == (d['unidad_medida'] as String),
        orElse: () => UnidadMedida.piezas,
      ),
      stockActual:    (d['stock_actual']    as num).toDouble(),
      stockMinimo:    (d['stock_minimo']    as num).toDouble(),
      precioUnitario: (d['precio_unitario'] as num).toDouble(),
      unidadId:       d['unidad_id']        as String?,
      ultimaActualizacion: d['ultima_actualizacion'] != null
          ? (d['ultima_actualizacion'] as fs.Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nombre':           nombre,
    'categoria':        categoria.name,
    'unidad_medida':    unidadMedida.name,
    'stock_actual':     stockActual,
    'stock_minimo':     stockMinimo,
    'precio_unitario':  precioUnitario,
    'unidad_id':        unidadId,
    'ultima_actualizacion': fs.FieldValue.serverTimestamp(),
  };

  factory ItemInventarioModel.fromEntity(ItemInventario e) =>
      ItemInventarioModel(
        id: e.id,
        nombre: e.nombre,
        categoria: e.categoria,
        unidadMedida: e.unidadMedida,
        stockActual: e.stockActual,
        stockMinimo: e.stockMinimo,
        precioUnitario: e.precioUnitario,
        unidadId: e.unidadId,
        ultimaActualizacion: e.ultimaActualizacion,
      );
}
