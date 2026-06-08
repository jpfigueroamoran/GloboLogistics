import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../injection_container.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';

final viajesActivosProvider =
    StreamProvider<List<Viaje>>((ref) {
  return sl<IViajeRepository>().watchViajesActivos();
});

final alertasActivasCountProvider = Provider<int>((ref) {
  return 0;
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
  final viajes = ref.watch(viajesActivosProvider).valueOrNull ?? [];

  return DashboardMetrics(
    viajesEnCurso:
        viajes.where((v) => v.estado == EstadoViaje.enCurso).length,
    viajesBanderaRoja: viajes.where((v) => v.tieneBanderaRoja).length,
    tcoPromedioDia: viajes.isEmpty
        ? 0
        : viajes.map((v) => v.tco.total).reduce((a, b) => a + b) /
            viajes.length,
  );
});
