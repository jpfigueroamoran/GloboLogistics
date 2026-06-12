import 'package:equatable/equatable.dart';
import 'viaje.dart';

enum EstadoUnidad { activa, mantenimiento, baja }

class Unidad extends Equatable {
  final String id;
  final String placas;
  final String modelo;
  final int anio;
  final EstadoUnidad estado;
  final String? operadorAsignadoId;
  final GeoPoint? ultimaPosicion;
  final DateTime? ultimaActualizacionPosicion;
  final double odometro;
  final double capacidadTanqueLitros;
  final double? proximoMantenimientoOdometro;

  /// ID del viaje en curso asignado a esta unidad (lo escribe la
  /// automatización del ciclo de vida); null cuando está libre.
  final String? viajeActivoId;

  const Unidad({
    required this.id,
    required this.placas,
    required this.modelo,
    required this.anio,
    required this.estado,
    this.operadorAsignadoId,
    this.ultimaPosicion,
    this.ultimaActualizacionPosicion,
    required this.odometro,
    required this.capacidadTanqueLitros,
    this.proximoMantenimientoOdometro,
    this.viajeActivoId,
  });

  bool get tieneOperadorAsignado => operadorAsignadoId != null;
  bool get estaActiva => estado == EstadoUnidad.activa;
  bool get enRuta => viajeActivoId != null && viajeActivoId!.isNotEmpty;

  bool get requiereServicio => proximoMantenimientoOdometro != null &&
      (proximoMantenimientoOdometro! - odometro) < 500;

  @override
  List<Object?> get props =>
      [id, placas, estado, operadorAsignadoId, viajeActivoId, odometro];
}
