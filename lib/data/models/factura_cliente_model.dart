import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import '../../domain/entities/factura_cliente.dart';

class FacturaClienteModel extends FacturaCliente {
  const FacturaClienteModel({
    required super.id,
    required super.viajeId,
    required super.clienteId,
    required super.clienteNombre,
    required super.numeroFactura,
    required super.fechaEmision,
    required super.fechaVencimiento,
    required super.monto,
    super.montoCobrado,
    required super.estatus,
    super.fechaCobro,
    super.cartaPorteUuid,
  });

  factory FacturaClienteModel.fromFirestore(fs.DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FacturaClienteModel(
      id: doc.id,
      viajeId: d['viaje_id'] as String? ?? '',
      clienteId: d['cliente_id'] as String? ?? '',
      clienteNombre: d['cliente_nombre'] as String? ?? '',
      numeroFactura: d['numero_factura'] as String? ?? '',
      fechaEmision:
          (d['fecha_emision'] as fs.Timestamp).toDate(),
      fechaVencimiento:
          (d['fecha_vencimiento'] as fs.Timestamp).toDate(),
      monto: (d['monto'] as num? ?? 0).toDouble(),
      montoCobrado: (d['monto_cobrado'] as num?)?.toDouble(),
      estatus: EstatusFactura.values.firstWhere(
        (e) => e.name == d['estatus'],
        orElse: () => EstatusFactura.pendiente,
      ),
      fechaCobro: (d['fecha_cobro'] as fs.Timestamp?)?.toDate(),
      cartaPorteUuid: d['carta_porte_uuid'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'viaje_id': viajeId,
        'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'numero_factura': numeroFactura,
        'fecha_emision': fs.Timestamp.fromDate(fechaEmision),
        'fecha_vencimiento': fs.Timestamp.fromDate(fechaVencimiento),
        'monto': monto,
        'monto_cobrado': montoCobrado,
        'estatus': estatus.name,
        'fecha_cobro':
            fechaCobro != null ? fs.Timestamp.fromDate(fechaCobro!) : null,
        'carta_porte_uuid': cartaPorteUuid,
      };

  factory FacturaClienteModel.fromEntity(FacturaCliente e) =>
      FacturaClienteModel(
        id: e.id,
        viajeId: e.viajeId,
        clienteId: e.clienteId,
        clienteNombre: e.clienteNombre,
        numeroFactura: e.numeroFactura,
        fechaEmision: e.fechaEmision,
        fechaVencimiento: e.fechaVencimiento,
        monto: e.monto,
        montoCobrado: e.montoCobrado,
        estatus: e.estatus,
        fechaCobro: e.fechaCobro,
        cartaPorteUuid: e.cartaPorteUuid,
      );
}
