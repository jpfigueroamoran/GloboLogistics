import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/operador_score.dart';
import '../../../../domain/entities/viaje.dart';
import 'dashboard_provider.dart';

/// Calcula scores de operadores a partir de los viajes activos en Firestore.
final operadorScoresProvider = Provider<List<OperadorScore>>((ref) {
  final viajes = ref.watch(viajesActivosProvider).valueOrNull ?? [];
  return _calcularScores(viajes);
});

List<OperadorScore> _calcularScores(List<Viaje> viajes) {
  final map = <String, _Acum>{};

  for (final v in viajes) {
    final acum = map.putIfAbsent(
      v.operadorId,
      () => _Acum(v.operadorId, v.operadorId),
    );
    acum.add(v);
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
