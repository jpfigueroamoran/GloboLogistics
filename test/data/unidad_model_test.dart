import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/data/models/unidad_model.dart';
import 'package:globo_logistics/domain/entities/unidad.dart';

/// Característica: serialización de Unidad ↔ Firestore (alta/edición de flota).
void main() {
  test('fromMap parsea todos los campos de gestión de flota', () {
    final u = UnidadModel.fromMap({
      'placas': 'XYZ987',
      'modelo': 'Freightliner',
      'anio': 2021,
      'estado': 'mantenimiento',
      'operador_asignado_id': 'op42',
      'viaje_activo_id': 'v7',
      'odometro': 220000,
      'capacidad_tanque': 450,
      'proximo_mantenimiento_odometro': 225000,
      'ultima_posicion': {'lat': 19.43, 'lng': -99.13},
    }, 'unidad1');

    expect(u.id, 'unidad1');
    expect(u.placas, 'XYZ987');
    expect(u.estado, EstadoUnidad.mantenimiento);
    expect(u.operadorAsignadoId, 'op42');
    expect(u.viajeActivoId, 'v7');
    expect(u.enRuta, isTrue);
    expect(u.odometro, 220000);
    expect(u.capacidadTanqueLitros, 450);
    expect(u.proximoMantenimientoOdometro, 225000);
    expect(u.ultimaPosicion?.lat, closeTo(19.43, 0.001));
  });

  test('estado inválido cae a "activa" por defecto', () {
    final u = UnidadModel.fromMap({
      'placas': 'AAA111',
      'estado': 'estado_inexistente',
    }, 'u2');
    expect(u.estado, EstadoUnidad.activa);
  });

  test('toFirestore conserva las claves clave para round-trip', () {
    final u = UnidadModel.fromMap({
      'placas': 'BBB222',
      'modelo': 'Volvo',
      'anio': 2023,
      'estado': 'activa',
      'odometro': 5000,
      'capacidad_tanque': 380,
    }, 'u3');

    final map = u.toFirestore();
    expect(map['placas'], 'BBB222');
    expect(map['modelo'], 'Volvo');
    expect(map['anio'], 2023);
    expect(map['estado'], 'activa');
    expect(map['odometro'], 5000);
    expect(map['capacidad_tanque'], 380);
  });
}
