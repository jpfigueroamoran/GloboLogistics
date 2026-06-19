import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/domain/entities/viaje.dart';

void main() {
  Viaje viajeBase() => Viaje(
        id: 'v1',
        unidadId: 'u1',
        operadorId: 'op1',
        origenDescripcion: 'Bodega',
        destinoDescripcion: 'Cliente',
        estado: EstadoViaje.enCurso,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  group('SeguimientoViaje — frescura del reporte', () {
    test('es reciente cuando se actualizó hace menos de 5 minutos', () {
      final seg = SeguimientoViaje(
        zona: 'enTransito',
        actualizadoEn: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      expect(seg.esReciente, isTrue);
    });

    test('no es reciente si pasaron más de 5 minutos', () {
      final seg = SeguimientoViaje(
        zona: 'enTransito',
        actualizadoEn: DateTime.now().subtract(const Duration(minutes: 9)),
      );
      expect(seg.esReciente, isFalse);
    });

    test('sin timestamp no se considera reciente', () {
      const seg = SeguimientoViaje(zona: 'enTransito');
      expect(seg.esReciente, isFalse);
    });
  });

  group('Viaje.copyWith — seguimiento', () {
    test('adjunta el seguimiento sin perder el resto del viaje', () {
      final v = viajeBase().copyWith(
        seguimiento: const SeguimientoViaje(
          zona: 'cercaDestino',
          distanciaDestinoM: 1500,
          etaMin: 2,
        ),
      );
      expect(v.seguimiento, isNotNull);
      expect(v.seguimiento!.zona, 'cercaDestino');
      expect(v.seguimiento!.etaMin, 2);
      expect(v.destinoDescripcion, 'Cliente'); // se conserva
    });

    test('un copyWith posterior conserva el seguimiento previo', () {
      final v = viajeBase()
          .copyWith(seguimiento: const SeguimientoViaje(zona: 'enDestino'))
          .copyWith(estado: EstadoViaje.completado);
      expect(v.estado, EstadoViaje.completado);
      expect(v.seguimiento?.zona, 'enDestino');
    });
  });
}
