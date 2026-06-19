import 'package:equatable/equatable.dart';

enum EstadoSolicitud { pendiente, asignada, enRuta, entregada, rechazada }

enum PrioridadSolicitud { baja, normal, alta, urgente }

extension EstadoSolicitudExt on EstadoSolicitud {
  String get label => switch (this) {
        EstadoSolicitud.pendiente => 'Pendiente',
        EstadoSolicitud.asignada  => 'Asignada',
        EstadoSolicitud.enRuta    => 'En ruta',
        EstadoSolicitud.entregada => 'Entregada',
        EstadoSolicitud.rechazada => 'Rechazada',
      };

  static EstadoSolicitud fromName(String? v) =>
      EstadoSolicitud.values.firstWhere((e) => e.name == v,
          orElse: () => EstadoSolicitud.pendiente);
}

extension PrioridadSolicitudExt on PrioridadSolicitud {
  String get label => switch (this) {
        PrioridadSolicitud.baja    => 'Baja',
        PrioridadSolicitud.normal  => 'Normal',
        PrioridadSolicitud.alta    => 'Alta',
        PrioridadSolicitud.urgente => 'Urgente',
      };

  /// Peso para ordenar la cola del despachador (urgente primero).
  int get peso => switch (this) {
        PrioridadSolicitud.urgente => 3,
        PrioridadSolicitud.alta    => 2,
        PrioridadSolicitud.normal  => 1,
        PrioridadSolicitud.baja    => 0,
      };

  static PrioridadSolicitud fromName(String? v) =>
      PrioridadSolicitud.values.firstWhere((e) => e.name == v,
          orElse: () => PrioridadSolicitud.normal);
}

/// Solicitud interna de transporte de material. El solicitante la crea, el
/// despachador la convierte en viaje, y el estado avanza solo conforme el
/// viaje progresa — así el solicitante ve siempre dónde va su material.
class SolicitudTransporte extends Equatable {
  final String id;
  final String solicitanteUid;
  final String solicitanteNombre;
  final String material;
  final String origen;
  final String destino;
  final PrioridadSolicitud prioridad;
  final String? notas;
  final EstadoSolicitud estado;
  final String? viajeId;
  final String? motivoRechazo;
  final DateTime createdAt;

  const SolicitudTransporte({
    required this.id,
    required this.solicitanteUid,
    required this.solicitanteNombre,
    required this.material,
    required this.origen,
    required this.destino,
    this.prioridad = PrioridadSolicitud.normal,
    this.notas,
    this.estado = EstadoSolicitud.pendiente,
    this.viajeId,
    this.motivoRechazo,
    required this.createdAt,
  });

  bool get esActiva =>
      estado != EstadoSolicitud.entregada &&
      estado != EstadoSolicitud.rechazada;

  @override
  List<Object?> get props => [id, estado, viajeId, prioridad];
}
