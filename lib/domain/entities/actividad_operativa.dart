import 'package:equatable/equatable.dart';
import 'viaje.dart';

enum TipoActividad {
  estadoCambio,
  posicion,
  sos,
  documentoCapturado,
  nota,
  sincronizacion,
}

enum EstadoOperador { offline, carga, transito, descarga }

extension EstadoOperadorExtension on EstadoOperador {
  String get label {
    switch (this) {
      case EstadoOperador.offline:
        return 'OFFLINE';
      case EstadoOperador.carga:
        return 'CARGA';
      case EstadoOperador.transito:
        return 'TRÁNSITO';
      case EstadoOperador.descarga:
        return 'DESCARGA';
    }
  }
}

class ActividadOperativa extends Equatable {
  final String id;
  final String viajeId;
  final String operadorId;
  final TipoActividad tipo;
  final DateTime timestamp;
  final GeoPoint? posicion;
  final Map<String, dynamic> datos;
  final bool sincronizado;
  final EstadoOperador? nuevoEstado;

  const ActividadOperativa({
    required this.id,
    required this.viajeId,
    required this.operadorId,
    required this.tipo,
    required this.timestamp,
    this.posicion,
    this.datos = const {},
    this.sincronizado = false,
    this.nuevoEstado,
  });

  bool get esSOS => tipo == TipoActividad.sos;
  bool get pendienteSincronizacion => !sincronizado;

  ActividadOperativa markSynchronized() => ActividadOperativa(
        id: id,
        viajeId: viajeId,
        operadorId: operadorId,
        tipo: tipo,
        timestamp: timestamp,
        posicion: posicion,
        datos: datos,
        sincronizado: true,
        nuevoEstado: nuevoEstado,
      );

  @override
  List<Object?> get props => [id, viajeId, tipo, timestamp, sincronizado];
}
