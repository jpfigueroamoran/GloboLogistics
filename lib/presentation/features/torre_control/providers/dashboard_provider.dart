import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/alerta_seguridad.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../domain/repositories/i_seguridad_repository.dart';
import '../../../../injection_container.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';

/// Punto de inyección del repositorio de viajes — sobreescrito en modo demo.
final viajeRepositoryProvider = Provider<IViajeRepository>((ref) => sl());

final viajesActivosProvider =
    StreamProvider<List<Viaje>>((ref) {
  return ref.watch(viajeRepositoryProvider).watchViajesActivos();
});

final alertasActivasStreamProvider = StreamProvider<List<AlertaSeguridad>>((ref) {
  return sl<ISeguridadRepository>().watchAlertasActivas();
});

final viajesCompletadosProvider = StreamProvider<List<Viaje>>((ref) {
  return sl<IViajeRepository>().watchViajesCompletados();
});

class DashboardMetrics {
  final int viajesEnCurso;
  final int alertasActivas;
  final int unidadesActivas;
  final double tcoPromedioDia;
  final int viajesBanderaRoja;

  const DashboardMetrics({
    this.viajesEnCurso = 0,
    this.alertasActivas = 0,
    this.unidadesActivas = 0,
    this.tcoPromedioDia = 0,
    this.viajesBanderaRoja = 0,
  });
}

final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final viajes  = ref.watch(viajesActivosProvider).valueOrNull ?? [];
  final alertas = ref.watch(alertasActivasStreamProvider).valueOrNull ?? [];

  return DashboardMetrics(
    viajesEnCurso:     viajes.where((v) => v.estado == EstadoViaje.enCurso).length,
    viajesBanderaRoja: viajes.where((v) => v.tieneBanderaRoja).length,
    alertasActivas:    alertas.where((a) => a.estado == EstadoAlerta.activa).length,
    unidadesActivas:   viajes.map((v) => v.unidadId).toSet().length,
    tcoPromedioDia:    viajes.isEmpty
        ? 0
        : viajes.map((v) => v.tco.total).reduce((a, b) => a + b) / viajes.length,
  );
});
