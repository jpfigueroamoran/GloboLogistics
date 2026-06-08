import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/mantenimiento.dart';
import '../../../../domain/entities/unidad.dart';
import 'unidades_provider.dart';

/// Genera registros de mantenimiento predictivo a partir de las unidades activas.
final mantenimientosProvider = Provider<List<MantenimientoPrevisto>>((ref) {
  final unidades = ref.watch(unidadesActivasProvider).valueOrNull ?? [];
  return unidades.map(_predecir).toList()
    ..sort((a, b) => a.kmRestantes.compareTo(b.kmRestantes));
});

final mantenimientosCriticosProvider = Provider<int>((ref) {
  return ref.watch(mantenimientosProvider).where((m) => m.esCritico).length;
});

MantenimientoPrevisto _predecir(Unidad u) {
  const intervalo = 20000;
  final odoInt = u.odometro.round();
  // Próximo múltiplo de intervalo usando aritmética entera
  final proximoServicio =
      ((odoInt + intervalo - 1) ~/ intervalo) * intervalo;

  TipoMantenimiento tipo;
  if (u.estado == EstadoUnidad.mantenimiento) {
    tipo = TipoMantenimiento.correctivo;
  } else if (proximoServicio - odoInt <= 2000) {
    tipo = TipoMantenimiento.preventivo;
  } else {
    tipo = TipoMantenimiento.inspeccion;
  }

  final estado = u.estado == EstadoUnidad.mantenimiento
      ? EstadoMantenimiento.enProceso
      : EstadoMantenimiento.pendiente;

  return MantenimientoPrevisto(
    id: 'mant-${u.id}',
    unidadId: u.id,
    placas: u.placas,
    modeloUnidad: u.modelo,
    tipo: tipo,
    estado: estado,
    descripcion: tipo == TipoMantenimiento.correctivo
        ? 'Mantenimiento correctivo en proceso'
        : 'Servicio preventivo (aceite, filtros, frenos)',
    odometroActual: odoInt,
    odometroProximoServicio: proximoServicio,
  );
}
