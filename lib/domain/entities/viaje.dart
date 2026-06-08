import 'package:equatable/equatable.dart';

enum EstadoViaje { programado, enCurso, completado, cancelado }

enum NivelAlertaViaje { ninguna, advertencia, bandajaRoja }

enum EstadoDestino { pendiente, enCamino, completado }

class Destino extends Equatable {
  final String clienteId;
  final String descripcion;
  final GeoPoint? geo;
  final EstadoDestino estado;
  final int orden;

  const Destino({
    required this.clienteId,
    required this.descripcion,
    this.geo,
    this.estado = EstadoDestino.pendiente,
    required this.orden,
  });

  Destino copyWith({EstadoDestino? estado}) => Destino(
        clienteId: clienteId,
        descripcion: descripcion,
        geo: geo,
        estado: estado ?? this.estado,
        orden: orden,
      );

  @override
  List<Object?> get props => [clienteId, orden];
}

class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint({required this.lat, required this.lng});
}

class TcoViaje extends Equatable {
  final double combustible;
  final double mantenimiento;
  final double peajes;
  final double otros;

  const TcoViaje({
    this.combustible = 0,
    this.mantenimiento = 0,
    this.peajes = 0,
    this.otros = 0,
  });

  double get total => combustible + mantenimiento + peajes + otros;

  @override
  List<Object?> get props => [combustible, mantenimiento, peajes, otros];
}

class Viaje extends Equatable {
  final String id;
  final String unidadId;
  final String operadorId;
  final String origenDescripcion;
  final String destinoDescripcion;
  final GeoPoint? origenGeo;
  final GeoPoint? destinoGeo;
  final EstadoViaje estado;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final double litrosCargados;
  final double litrosConsumiidosTelemetria;
  final double litrosConsumiidosTickets;
  final double? varianzaCombustible;
  final NivelAlertaViaje nivelAlerta;
  final TcoViaje tco;
  final List<Destino> destinos;
  final String? observaciones;
  final String? justificacionVarianza;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Viaje({
    required this.id,
    required this.unidadId,
    required this.operadorId,
    required this.origenDescripcion,
    required this.destinoDescripcion,
    this.origenGeo,
    this.destinoGeo,
    this.destinos = const [],
    required this.estado,
    this.fechaInicio,
    this.fechaFin,
    this.litrosCargados = 0,
    this.litrosConsumiidosTelemetria = 0,
    this.litrosConsumiidosTickets = 0,
    this.varianzaCombustible,
    this.nivelAlerta = NivelAlertaViaje.ninguna,
    this.tco = const TcoViaje(),
    this.observaciones,
    this.justificacionVarianza,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get tieneBanderaRoja => nivelAlerta == NivelAlertaViaje.bandajaRoja;
  bool get estaEnCurso => estado == EstadoViaje.enCurso;

  Viaje copyWith({
    EstadoViaje? estado,
    List<Destino>? destinos,
    double? litrosCargados,
    double? litrosConsumiidosTelemetria,
    double? litrosConsumiidosTickets,
    double? varianzaCombustible,
    NivelAlertaViaje? nivelAlerta,
    TcoViaje? tco,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? observaciones,
    String? justificacionVarianza,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Viaje(
      id: id ?? this.id,
      unidadId: unidadId ?? this.unidadId,
      operadorId: operadorId ?? this.operadorId,
      origenDescripcion: origenDescripcion ?? this.origenDescripcion,
      destinoDescripcion: destinoDescripcion ?? this.destinoDescripcion,
      origenGeo: origenGeo ?? this.origenGeo,
      destinoGeo: destinoGeo ?? this.destinoGeo,
      destinos: destinos ?? this.destinos,
      estado: estado ?? this.estado,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      litrosCargados: litrosCargados ?? this.litrosCargados,
      litrosConsumiidosTelemetria:
          litrosConsumiidosTelemetria ?? this.litrosConsumiidosTelemetria,
      litrosConsumiidosTickets:
          litrosConsumiidosTickets ?? this.litrosConsumiidosTickets,
      varianzaCombustible: varianzaCombustible ?? this.varianzaCombustible,
      nivelAlerta: nivelAlerta ?? this.nivelAlerta,
      tco: tco ?? this.tco,
      observaciones: observaciones ?? this.observaciones,
      justificacionVarianza: justificacionVarianza ?? this.justificacionVarianza,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id, unidadId, operadorId, estado, nivelAlerta,
        litrosCargados, varianzaCombustible, tco,
      ];
}
