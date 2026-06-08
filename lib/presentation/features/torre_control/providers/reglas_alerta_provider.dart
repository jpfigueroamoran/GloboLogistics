import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/regla_alerta.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../domain/entities/unidad.dart';
import 'dashboard_provider.dart';
import 'unidades_provider.dart';

// ── Estado editable de reglas ─────────────────────────────────────────────────

class ReglasAlertaNotifier extends StateNotifier<List<ReglaAlerta>> {
  ReglasAlertaNotifier() : super(_defaultRules);

  void toggleActiva(String id) {
    state = state
        .map((r) => r.id == id ? r.copyWith(activa: !r.activa) : r)
        .toList();
  }

  void agregarRegla(ReglaAlerta regla) {
    state = [...state, regla];
  }

  void eliminarRegla(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void actualizarRegla(ReglaAlerta regla) {
    state = state.map((r) => r.id == regla.id ? regla : r).toList();
  }
}

final reglasAlertaProvider =
    StateNotifierProvider<ReglasAlertaNotifier, List<ReglaAlerta>>(
  (_) => ReglasAlertaNotifier(),
);

// ── Evaluador — viajes que disparan alguna regla activa ───────────────────────

final viajesEnAlertaProvider = Provider<List<_ViajeConRegla>>((ref) {
  final viajes = ref.watch(viajesActivosProvider).valueOrNull ?? [];
  final reglas = ref.watch(reglasAlertaProvider).where((r) => r.activa);
  final unidades = ref.watch(unidadesActivasProvider).valueOrNull ?? [];

  final resultado = <_ViajeConRegla>[];
  for (final v in viajes) {
    for (final r in reglas) {
      if (_evaluar(v, r, unidades)) {
        resultado.add(_ViajeConRegla(viaje: v, regla: r));
      }
    }
  }
  return resultado;
});

bool _evaluar(Viaje v, ReglaAlerta r, List<Unidad> unidades) {
  switch (r.condicion) {
    case CondicionAlerta.varianzaCombustible:
      final varianza = v.varianzaCombustible ?? 0;
      if (varianza > r.umbral) {
        // Atenuante mecánico: Si la unidad requiere servicio, la culpa no es del operador,
        // no se dispara la regla de varianza contra el operador.
        final unidad = unidades.where((u) => u.id == v.unidadId).firstOrNull;
        if (unidad != null && unidad.requiereServicio) {
          return false; 
        }
        return true;
      }
      return false;
    case CondicionAlerta.banderasRojas:
      return v.tieneBanderaRoja;
    case CondicionAlerta.sosActivados:
    case CondicionAlerta.tiempoSinActividad:
    case CondicionAlerta.odometroAlto:
      return false; // requiere datos de sesión/odómetro en tiempo real
  }
}

class _ViajeConRegla {
  final Viaje viaje;
  final ReglaAlerta regla;
  const _ViajeConRegla({required this.viaje, required this.regla});
}

// ── Reglas por defecto del sistema ────────────────────────────────────────────

const _defaultRules = [
  ReglaAlerta(
    id: 'r001',
    nombre: 'Varianza crítica',
    condicion: CondicionAlerta.varianzaCombustible,
    umbral: 0.08,
    acciones: [AccionAlerta.notificarSupervisor, AccionAlerta.generarAuditoria],
    activa: true,
  ),
  ReglaAlerta(
    id: 'r002',
    nombre: 'Varianza alta',
    condicion: CondicionAlerta.varianzaCombustible,
    umbral: 0.05,
    acciones: [AccionAlerta.notificarSupervisor],
    activa: true,
  ),
  ReglaAlerta(
    id: 'r003',
    nombre: 'Bandera roja activa',
    condicion: CondicionAlerta.banderasRojas,
    umbral: 1,
    acciones: [AccionAlerta.notificarSupervisor],
    activa: true,
  ),
  ReglaAlerta(
    id: 'r004',
    nombre: 'SOS recurrente',
    condicion: CondicionAlerta.sosActivados,
    umbral: 2,
    acciones: [AccionAlerta.bloquearAsignacion, AccionAlerta.generarAuditoria],
    activa: false,
  ),
];
