import 'package:equatable/equatable.dart';

enum TipoMantenimiento {
  preventivo,
  correctivo,
  inspeccion,
}

enum EstadoMantenimiento {
  pendiente,
  programado,
  enProceso,
  completado,
}

class MantenimientoPrevisto extends Equatable {
  final String id;
  final String unidadId;
  final String placas;
  final String modeloUnidad;
  final TipoMantenimiento tipo;
  final EstadoMantenimiento estado;
  final String descripcion;
  final int odometroActual;
  final int odometroProximoServicio;
  final DateTime? fechaProgramada;
  final DateTime? fechaCompletado;

  const MantenimientoPrevisto({
    required this.id,
    required this.unidadId,
    required this.placas,
    required this.modeloUnidad,
    required this.tipo,
    required this.estado,
    required this.descripcion,
    required this.odometroActual,
    required this.odometroProximoServicio,
    this.fechaProgramada,
    this.fechaCompletado,
  });

  /// km restantes antes del próximo servicio; negativo = vencido
  int get kmRestantes => odometroProximoServicio - odometroActual;

  /// Urgencia de 0 (ok) a 1 (crítico)
  double get nivelUrgencia {
    if (kmRestantes <= 0)       return 1.0;
    if (kmRestantes <= 2000)    return 0.8;
    if (kmRestantes <= 5000)    return 0.5;
    if (kmRestantes <= 10000)   return 0.2;
    return 0.0;
  }

  bool get esCritico => nivelUrgencia >= 0.8;

  @override
  List<Object?> get props => [id, odometroActual, odometroProximoServicio];
}
