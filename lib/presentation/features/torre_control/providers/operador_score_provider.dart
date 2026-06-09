import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/alerta_seguridad.dart';
import '../../../../domain/entities/operador_score.dart';
import '../../../../domain/entities/viaje.dart';
import 'dashboard_provider.dart';

final operadorScoresProvider = Provider<List<OperadorScore>>((ref) {
  final activos    = ref.watch(viajesActivosProvider).valueOrNull ?? [];
  final completados = ref.watch(viajesCompletadosProvider).valueOrNull ?? [];
  final alertas    = ref.watch(alertasActivasStreamProvider).valueOrNull ?? [];

  final todos = [...activos, ...completados];
  return _calcularScores(todos, alertas);
});

List<OperadorScore> _calcularScores(
    List<Viaje> viajes, List<AlertaSeguridad> alertas) {
  final map = <String, _Acum>{};

  for (final v in viajes) {
    final acum = map.putIfAbsent(
      v.operadorId,
      () => _Acum(v.operadorId, v.operadorNombre ?? v.operadorId),
    );
    acum.add(v);
  }

  for (final a in alertas) {
    if (a.tipo == TipoAlerta.sos) {
      map[a.operadorId]?.addSos();
    }
  }

  return map.values
      .map((a) => a.toScore())
      .toList()
    ..sort((a, b) => b.scoreTotal.compareTo(a.scoreTotal));
}

class _Acum {
  final String operadorId;
  final String nombre;
  int total = 0;
  int completados = 0;
  int banderasRojas = 0;
  int alertasSOS = 0;
  double sumVarianza = 0;

  _Acum(this.operadorId, this.nombre);

  void add(Viaje v) {
    total++;
    if (v.estado == EstadoViaje.completado) completados++;
    if (v.tieneBanderaRoja) banderasRojas++;
    if (v.varianzaCombustible != null) sumVarianza += v.varianzaCombustible!;
  }

  void addSos() => alertasSOS++;

  OperadorScore toScore() => OperadorScore(
        operadorId: operadorId,
        nombreOperador: nombre,
        totalViajes: total,
        promedioVarianza: total > 0 ? sumVarianza / total : 0,
        viajesBanderaRoja: banderasRojas,
        alertasSOS: alertasSOS,
        tasaCompletitud: total > 0 ? completados / total : 1.0,
      );
}
