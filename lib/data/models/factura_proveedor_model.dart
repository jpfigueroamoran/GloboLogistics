import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/factura_proveedor.dart';

class FacturaProveedorModel extends FacturaProveedor {
  const FacturaProveedorModel({
    required super.id,
    required super.proveedorId,
    required super.proveedorNombre,
    required super.tipoProveedor,
    required super.numeroFactura,
    required super.fechaEmision,
    required super.fechaVencimiento,
    required super.monto,
    super.montoPagado,
    required super.estatus,
    super.fechaPago,
    super.viajeId,
    super.unidadId,
  });

  factory FacturaProveedorModel.fromFirestore(
      fs.DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return FacturaProveedorModel(
      id:              doc.id,
      proveedorId:     d['proveedor_id']     as String,
      proveedorNombre: d['proveedor_nombre'] as String,
      tipoProveedor:   TipoProveedor.values.firstWhere(
        (e) => e.name == (d['tipo_proveedor'] as String),
        orElse: () => TipoProveedor.otro,
      ),
      numeroFactura:   d['numero_factura']   as String,
      fechaEmision:    (d['fecha_emision']   as fs.Timestamp).toDate(),
      fechaVencimiento:(d['fecha_vencimiento'] as fs.Timestamp).toDate(),
      monto:           (d['monto'] as num).toDouble(),
      montoPagado:     d['monto_pagado'] != null
          ? (d['monto_pagado'] as num).toDouble()
          : null,
      estatus: EstatusFacturaProveedor.values.firstWhere(
        (e) => e.name == (d['estatus'] as String),
        orElse: () => EstatusFacturaProveedor.pendiente,
      ),
      fechaPago: d['fecha_pago'] != null
          ? (d['fecha_pago'] as fs.Timestamp).toDate()
          : null,
      viajeId:  d['viaje_id']  as String?,
      unidadId: d['unidad_id'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'proveedor_id':     proveedorId,
    'proveedor_nombre': proveedorNombre,
    'tipo_proveedor':   tipoProveedor.name,
    'numero_factura':   numeroFactura,
    'fecha_emision':    fs.Timestamp.fromDate(fechaEmision),
    'fecha_vencimiento':fs.Timestamp.fromDate(fechaVencimiento),
    'monto':            monto,
    'monto_pagado':     montoPagado,
    'estatus':          estatus.name,
    'fecha_pago':       fechaPago != null
        ? fs.Timestamp.fromDate(fechaPago!)
        : null,
    'viaje_id':         viajeId,
    'unidad_id':        unidadId,
    'created_at':       fs.FieldValue.serverTimestamp(),
  };

  factory FacturaProveedorModel.fromEntity(FacturaProveedor e) =>
      FacturaProveedorModel(
        id: e.id,
        proveedorId: e.proveedorId,
        proveedorNombre: e.proveedorNombre,
        tipoProveedor: e.tipoProveedor,
        numeroFactura: e.numeroFactura,
        fechaEmision: e.fechaEmision,
        fechaVencimiento: e.fechaVencimiento,
        monto: e.monto,
        montoPagado: e.montoPagado,
        estatus: e.estatus,
        fechaPago: e.fechaPago,
        viajeId: e.viajeId,
        unidadId: e.unidadId,
      );
}
