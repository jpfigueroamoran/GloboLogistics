import 'package:equatable/equatable.dart';

enum EstatusFactura { pendiente, cobrada, vencida, cancelada }

enum BucketAging { corriente, vencido30, vencido60, vencido90, vencido90mas }

class FacturaCliente extends Equatable {
  final String id;
  final String viajeId;
  final String clienteId;
  final String clienteNombre;
  final String numeroFactura;
  final DateTime fechaEmision;
  final DateTime fechaVencimiento;
  final double monto;
  final double? montoCobrado;
  final EstatusFactura estatus;
  final DateTime? fechaCobro;
  final String? cartaPorteUuid; // nullable — integrar en Fase 4 con Carta Porte SAT

  const FacturaCliente({
    required this.id,
    required this.viajeId,
    required this.clienteId,
    required this.clienteNombre,
    required this.numeroFactura,
    required this.fechaEmision,
    required this.fechaVencimiento,
    required this.monto,
    this.montoCobrado,
    required this.estatus,
    this.fechaCobro,
    this.cartaPorteUuid,
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
      estatus == EstatusFactura.pendiente || estatus == EstatusFactura.vencida;

  String get estatusLabel => switch (estatus) {
        EstatusFactura.pendiente => 'Pendiente',
        EstatusFactura.cobrada => 'Cobrada',
        EstatusFactura.vencida => 'Vencida',
        EstatusFactura.cancelada => 'Cancelada',
      };

  @override
  List<Object?> get props =>
      [id, viajeId, clienteId, numeroFactura, monto, estatus];
}
