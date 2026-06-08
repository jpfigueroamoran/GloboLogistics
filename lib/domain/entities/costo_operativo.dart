import 'package:equatable/equatable.dart';

enum TipoCosto { diesel, mantenimiento, grua, peaje, otro }

class DatosOcr extends Equatable {
  final String? textoCompleto;
  final double? montoDetectado;
  final double? litrosDetectados;
  final String? foliDetectado;
  final double? confianza;

  const DatosOcr({
    this.textoCompleto,
    this.montoDetectado,
    this.litrosDetectados,
    this.foliDetectado,
    this.confianza,
  });

  @override
  List<Object?> get props =>
      [montoDetectado, litrosDetectados, foliDetectado, confianza];
}

class CostoOperativo extends Equatable {
  final String id;
  final String viajeId;
  final String unidadId;
  final TipoCosto tipo;
  final double monto;
  final String proveedor;
  final String folio;
  final DateTime fecha;
  final DatosOcr? datosOcr;
  final String? imagenUrl;
  final bool verificado;
  final bool sincronizado;

  const CostoOperativo({
    required this.id,
    required this.viajeId,
    required this.unidadId,
    required this.tipo,
    required this.monto,
    required this.proveedor,
    required this.folio,
    required this.fecha,
    this.datosOcr,
    this.imagenUrl,
    this.verificado = false,
    this.sincronizado = false,
  });

  bool get esDiesel => tipo == TipoCosto.diesel;

  @override
  List<Object?> get props => [id, viajeId, tipo, monto, verificado];
}
