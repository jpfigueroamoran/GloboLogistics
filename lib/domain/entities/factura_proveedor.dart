import 'package:equatable/equatable.dart';
import 'factura_cliente.dart'; // BucketAging

enum TipoProveedor {
  combustible,
  llantas,
  mantenimiento,
  refacciones,
  seguro,
  otro
}

extension TipoProveedorLabel on TipoProveedor {
  String get label => switch (this) {
        TipoProveedor.combustible  => 'Combustible',
        TipoProveedor.llantas      => 'Llantas',
        TipoProveedor.mantenimiento => 'Mantenimiento',
        TipoProveedor.refacciones  => 'Refacciones',
        TipoProveedor.seguro       => 'Seguro',
        TipoProveedor.otro         => 'Otro',
      };
}

enum EstatusFacturaProveedor { pendiente, pagada, vencida, cancelada }

class FacturaProveedor extends Equatable {
  final String id;
  final String proveedorId;
  final String proveedorNombre;
  final TipoProveedor tipoProveedor;
  final String numeroFactura;
  final DateTime fechaEmision;
  final DateTime fechaVencimiento;
  final double monto;
  final double? montoPagado;
  final EstatusFacturaProveedor estatus;
  final DateTime? fechaPago;
  final String? viajeId;
  final String? unidadId;

  const FacturaProveedor({
    required this.id,
    required this.proveedorId,
    required this.proveedorNombre,
    required this.tipoProveedor,
    required this.numeroFactura,
    required this.fechaEmision,
    required this.fechaVencimiento,
    required this.monto,
    this.montoPagado,
    required this.estatus,
    this.fechaPago,
    this.viajeId,
    this.unidadId,
  });

  int diasVencimiento(DateTime ahora) =>
      fechaVencimiento.difference(ahora).inDays;

  BucketAging bucketAging(DateTime ahora) {
    final dias = diasVencimiento(ahora);
    if (dias >= 0) return BucketAging.corriente;
    final vencidos = -dias;
    if (vencidos <= 30) return BucketAging.vencido30;
    if (vencidos <= 60) return BucketAging.vencido60;
    if (vencidos <= 90) return BucketAging.vencido90;
    return BucketAging.vencido90mas;
  }

  bool get esPendienteOVencida =>
      estatus == EstatusFacturaProveedor.pendiente ||
      estatus == EstatusFacturaProveedor.vencida;

  @override
  List<Object?> get props =>
      [id, proveedorId, numeroFactura, monto, estatus];
}
