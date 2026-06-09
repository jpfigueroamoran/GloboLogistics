import 'package:equatable/equatable.dart';
import 'documento_vencimiento.dart';

enum TipoPoliza {
  responsabilidadCivil,
  danosTerceros,
  cargoTransportado,
  todoRiesgo,
}

enum ModoPagoSeguro { mensual, semestral, anual }

class PolizaSeguro extends Equatable {
  final String id;
  final String? unidadId;
  final String? unidadPlacas;
  final TipoPoliza tipo;
  final String aseguradora;
  final String numeroPoliza;
  final DateTime vigenciaInicio;
  final DateTime vigenciaFin;
  final double primaMensual;
  final ModoPagoSeguro modoPago;
  final double coberturaMaxima;
  final double deducible;

  const PolizaSeguro({
    required this.id,
    this.unidadId,
    this.unidadPlacas,
    required this.tipo,
    required this.aseguradora,
    required this.numeroPoliza,
    required this.vigenciaInicio,
    required this.vigenciaFin,
    required this.primaMensual,
    this.modoPago = ModoPagoSeguro.mensual,
    required this.coberturaMaxima,
    required this.deducible,
  });

  SemaforoDocumento semaforo(DateTime ahora) {
    final dias = vigenciaFin.difference(ahora).inDays;
    if (dias < 0) return SemaforoDocumento.vencido;
    if (dias <= 30) return SemaforoDocumento.proximoVencer;
    return SemaforoDocumento.vigente;
  }

  int diasRestantes(DateTime ahora) => vigenciaFin.difference(ahora).inDays;

  String get tipoLabel => switch (tipo) {
        TipoPoliza.responsabilidadCivil => 'Resp. Civil',
        TipoPoliza.danosTerceros => 'Daños a Terceros',
        TipoPoliza.cargoTransportado => 'Cargo Transportado',
        TipoPoliza.todoRiesgo => 'Todo Riesgo',
      };

  String get unidadLabel => unidadPlacas ?? 'Flotilla Completa';

  @override
  List<Object?> get props =>
      [id, unidadId, tipo, aseguradora, numeroPoliza, vigenciaFin];
}
