import 'dart:math';
import 'package:equatable/equatable.dart';
import 'cuenta_por_cobrar.dart'; // NivelRiesgo
import 'factura_cliente.dart'; // BucketAging
import 'factura_proveedor.dart';

class CuentaPorPagar extends Equatable {
  final String proveedorId;
  final String proveedorNombre;
  final TipoProveedor tipoProveedor;
  final List<FacturaProveedor> facturasPendientes;

  const CuentaPorPagar({
    required this.proveedorId,
    required this.proveedorNombre,
    required this.tipoProveedor,
    required this.facturasPendientes,
  });

  double get montoPendienteTotal =>
      facturasPendientes.fold(0.0, (s, f) => s + f.monto);

  double montoEnBucket(BucketAging bucket, DateTime ahora) =>
      facturasPendientes
          .where((f) => f.bucketAging(ahora) == bucket)
          .fold(0.0, (s, f) => s + f.monto);

  int diasMayorAncianidad(DateTime ahora) {
    if (facturasPendientes.isEmpty) return 0;
    return facturasPendientes
        .map((f) => max(0, -f.diasVencimiento(ahora)))
        .reduce(max);
  }

  NivelRiesgo nivelRiesgo(DateTime ahora) {
    final maxDias = diasMayorAncianidad(ahora);
    if (maxDias == 0) return NivelRiesgo.ok;
    if (maxDias <= 30) return NivelRiesgo.atencion;
    return NivelRiesgo.critico;
  }

  @override
  List<Object?> get props => [proveedorId, facturasPendientes];
}
