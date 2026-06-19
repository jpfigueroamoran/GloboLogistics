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

/// Seguimiento en vivo que el dispositivo del operador publica al viaje para
/// que Torre de Control vea progreso y ETA sin abrir el teléfono del operador.
class SeguimientoViaje extends Equatable {
  /// Zona del geofence: cercaOrigen, enBodegaCarga, enTransito, cercaDestino,
  /// enDestino, fueraDeRuta (coincide con GeofenceZone.name).
  final String zona;
  final double? distanciaDestinoM;
  final int? etaMin;
  final DateTime? actualizadoEn;

  const SeguimientoViaje({
    required this.zona,
    this.distanciaDestinoM,
    this.etaMin,
    this.actualizadoEn,
  });

  /// true si el último reporte tiene menos de 5 minutos (posición fresca).
  bool get esReciente =>
      actualizadoEn != null &&
      DateTime.now().difference(actualizadoEn!).inMinutes < 5;

  @override
  List<Object?> get props => [zona, distanciaDestinoM, etaMin, actualizadoEn];
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
  final String? operadorNombre;
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
  final SeguimientoViaje? seguimiento;

  /// Solicitud de transporte que originó este viaje (si nació del intake del
  /// solicitante). El motor propaga el estado del viaje a esa solicitud.
  final String? solicitudId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Viaje({
    required this.id,
    required this.unidadId,
    required this.operadorId,
    this.operadorNombre,
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
    this.seguimiento,
    this.solicitudId,
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
    SeguimientoViaje? seguimiento,
    String? solicitudId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Viaje(
      id: id,
      unidadId: unidadId,
      operadorId: operadorId,
      operadorNombre: operadorNombre,
      origenDescripcion: origenDescripcion,
      destinoDescripcion: destinoDescripcion,
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
      seguimiento: seguimiento ?? this.seguimiento,
      solicitudId: solicitudId ?? this.solicitudId,
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
