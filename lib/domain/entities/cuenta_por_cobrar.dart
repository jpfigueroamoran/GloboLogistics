import 'dart:math';
import 'package:equatable/equatable.dart';
import 'factura_cliente.dart';

enum NivelRiesgo { ok, atencion, critico }

class CuentaPorCobrar extends Equatable {
  final String clienteId;
  final String clienteNombre;
  final List<FacturaCliente> facturasPendientes;

  const CuentaPorCobrar({
    required this.clienteId,
    required this.clienteNombre,
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
  List<Object?> get props => [clienteId, facturasPendientes];
}
