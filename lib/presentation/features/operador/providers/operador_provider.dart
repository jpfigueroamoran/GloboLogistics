import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/actividad_operativa.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../injection_container.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';

// ── Estado del operador ───────────────────────────────────────────────────────

class OperadorState {
  final EstadoOperador estadoActual;
  final Viaje? viajeActivo;
  final bool sincronizando;
  final int pendientesSincronizacion;

  const OperadorState({
    this.estadoActual = EstadoOperador.offline,
    this.viajeActivo,
    this.sincronizando = false,
    this.pendientesSincronizacion = 0,
  });

  OperadorState copyWith({
    EstadoOperador? estadoActual,
    Viaje? viajeActivo,
    bool? sincronizando,
    int? pendientesSincronizacion,
  }) {
    return OperadorState(
      estadoActual: estadoActual ?? this.estadoActual,
      viajeActivo: viajeActivo ?? this.viajeActivo,
      sincronizando: sincronizando ?? this.sincronizando,
      pendientesSincronizacion:
          pendientesSincronizacion ?? this.pendientesSincronizacion,
    );
  }
}

class OperadorNotifier extends StateNotifier<OperadorState> {
  final IViajeRepository _viajeRepo;

  OperadorNotifier(this._viajeRepo) : super(const OperadorState());

  Future<void> cambiarEstado(
      EstadoOperador nuevoEstado, String? viajeId) async {
    state = state.copyWith(estadoActual: nuevoEstado);

    if (viajeId == null) return;

    final estadoViaje = switch (nuevoEstado) {
      EstadoOperador.carga => EstadoViaje.enCurso,
      EstadoOperador.transito => EstadoViaje.enCurso,
      EstadoOperador.descarga => EstadoViaje.enCurso,
      EstadoOperador.offline => null,
    };
    if (estadoViaje != null) {
      await _viajeRepo.actualizarEstado(viajeId, estadoViaje);
    }
  }

  void setViajeActivo(Viaje viaje) {
    state = state.copyWith(viajeActivo: viaje);
  }

  Future<void> comenzarViajeAsignado(String viajeId) async {
    await _viajeRepo.actualizarEstado(viajeId, EstadoViaje.enCurso);
    state = state.copyWith(estadoActual: EstadoOperador.carga);
  }

  void incrementarPendientes() {
    state = state.copyWith(
        pendientesSincronizacion:
            state.pendientesSincronizacion + 1);
  }
}

final operadorProvider =
    StateNotifierProvider<OperadorNotifier, OperadorState>((ref) {
  return OperadorNotifier(sl<IViajeRepository>());
});

final viajeActivoStreamProvider =
    StreamProvider.family<List<Viaje>, String>((ref, operadorId) {
  return sl<IViajeRepository>().watchViajesPorOperador(operadorId);
});
