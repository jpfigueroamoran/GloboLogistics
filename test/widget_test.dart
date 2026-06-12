import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/domain/entities/viaje.dart';

/// Característica: entidad Viaje (TCO, banderas, ciclo de estado).
void main() {
  Viaje viaje({
    EstadoViaje estado = EstadoViaje.programado,
    NivelAlertaViaje nivel = NivelAlertaViaje.ninguna,
    TcoViaje tco = const TcoViaje(),
  }) =>
      Viaje(
        id: 'v1',
        unidadId: 'u1',
        operadorId: 'op1',
        origenDescripcion: 'CDMX',
        destinoDescripcion: 'Querétaro',
        estado: estado,
        nivelAlerta: nivel,
        tco: tco,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('TCO total suma todos los componentes', () {
    const tco = TcoViaje(
        combustible: 1000, mantenimiento: 500, peajes: 300, otros: 200);
    expect(tco.total, 2000);
  });

  test('tieneBanderaRoja refleja el nivel de alerta', () {
    expect(viaje(nivel: NivelAlertaViaje.bandajaRoja).tieneBanderaRoja, isTrue);
    expect(viaje(nivel: NivelAlertaViaje.ninguna).tieneBanderaRoja, isFalse);
  });

  test('estaEnCurso solo cuando el estado es enCurso', () {
    expect(viaje(estado: EstadoViaje.enCurso).estaEnCurso, isTrue);
    expect(viaje(estado: EstadoViaje.programado).estaEnCurso, isFalse);
  });

  test('copyWith cambia estado y preserva identidad', () {
    final original = viaje(estado: EstadoViaje.programado);
    final actualizado = original.copyWith(estado: EstadoViaje.completado);
    expect(actualizado.id, original.id);
    expect(actualizado.estado, EstadoViaje.completado);
    expect(original.estado, EstadoViaje.programado); // inmutable
  });
}
