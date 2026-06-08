import 'package:equatable/equatable.dart';
import 'viaje.dart';

enum TipoAlerta { sos, geocerca, varianzaCombustible, detencionProlongada }

enum EstadoAlerta { activa, atendida, falsaAlarma }

class AlertaSeguridad extends Equatable {
  final String id;
  final String viajeId;
  final String operadorId;
  final String unidadId;
  final TipoAlerta tipo;
  final DateTime timestamp;
  final GeoPoint posicion;
  final EstadoAlerta estado;
  final String? atendidaPor;
  final String? notas;
  final Map<String, dynamic> metadata;

  const AlertaSeguridad({
    required this.id,
    required this.viajeId,
    required this.operadorId,
    required this.unidadId,
    required this.tipo,
    required this.timestamp,
    required this.posicion,
    this.estado = EstadoAlerta.activa,
    this.atendidaPor,
    this.notas,
    this.metadata = const {},
  });

  bool get requiereAtencionInmediata =>
      tipo == TipoAlerta.sos && estado == EstadoAlerta.activa;

  @override
  List<Object?> get props => [id, tipo, estado, timestamp];
}
