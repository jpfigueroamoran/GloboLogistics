import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/domain/entities/operador_score.dart';

/// Característica: Score de Operadores (score_operadores_page).
void main() {
  OperadorScore score({
    int total = 10,
    double varianza = 0.01,
    int sos = 0,
    double completitud = 1.0,
  }) =>
      OperadorScore(
        operadorId: 'op',
        nombreOperador: 'Test',
        totalViajes: total,
        promedioVarianza: varianza,
        viajesBanderaRoja: 0,
        alertasSOS: sos,
        tasaCompletitud: completitud,
      );

  test('operador impecable → nivel excelente', () {
    final s = score(varianza: 0.01, sos: 0, completitud: 1.0);
    expect(s.scoreTotal, 100);
    expect(s.nivel, NivelScore.excelente);
  });

  test('operador con varianza alta, SOS frecuentes y baja completitud → crítico',
      () {
    final s = score(varianza: 0.20, sos: 5, completitud: 0.30);
    // 20*0.4 + 30*0.3 + 30*0.3 = 26
    expect(s.scoreTotal, closeTo(26, 0.5));
    expect(s.nivel, NivelScore.critico);
  });

  test('sin viajes → scoreSOS neutral (100)', () {
    final s = score(total: 0, sos: 0);
    expect(s.scoreSOS, 100);
  });

  test('nivel "bueno" en rango medio-alto', () {
    // varianza 0.05 (60) + sin SOS (100) + completitud 0.70 (70)
    //   = 60*0.4 + 100*0.3 + 70*0.3 = 24 + 30 + 21 = 75 → bueno [65,85)
    final bueno = score(varianza: 0.05, sos: 0, completitud: 0.70);
    expect(bueno.scoreTotal, closeTo(75, 0.5));
    expect(bueno.nivel, NivelScore.bueno);
  });

  test('nivel "regular" en rango medio-bajo', () {
    // varianza 0.05 (60) + sin SOS (100) + completitud 0.10 (10)
    //   = 24 + 30 + 3 = 57 → regular [45,65)
    final regular = score(varianza: 0.05, sos: 0, completitud: 0.10);
    expect(regular.scoreTotal, closeTo(57, 0.5));
    expect(regular.nivel, NivelScore.regular);
  });

  test('scoreVarianza escalonado', () {
    expect(score(varianza: 0.015).scoreVarianza, 100);
    expect(score(varianza: 0.03).scoreVarianza, 80);
    expect(score(varianza: 0.05).scoreVarianza, 60);
    expect(score(varianza: 0.10).scoreVarianza, 40);
    expect(score(varianza: 0.20).scoreVarianza, 20);
  });
}
