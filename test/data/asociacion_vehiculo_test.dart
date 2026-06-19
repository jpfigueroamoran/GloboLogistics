import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/data/datasources/remote/firestore_datasource.dart';

/// Característica: el operador asocia su dispositivo a un vehículo escaneando
/// el QR (los operadores rotan de unidad). Verifica reclamo + liberación.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreDatasource ds;

  setUp(() {
    db = FakeFirebaseFirestore();
    ds = FirestoreDatasource(db);
  });

  Future<void> seed() async {
    await db.collection('unidades').doc('u1').set({
      'placas': 'AAA111',
      'estado': 'activa',
      'operador_asignado_id': 'op1', // unidad previa del operador
    });
    await db.collection('unidades').doc('u2').set({
      'placas': 'BBB222',
      'estado': 'activa',
      'operador_asignado_id': null, // unidad libre que va a reclamar
    });
    await db.collection('usuarios').doc('op1').set({
      'nombre': 'Operador 1',
      'rol': 'operador',
      'unidad_asignada_id': 'u1',
    });
  }

  test('reclama la unidad nueva, libera la previa y actualiza el perfil',
      () async {
    await seed();

    await ds.asociarVehiculoOperador(
      operadorUid: 'op1',
      unidadId: 'u2',
      unidadPrevia: 'u1',
    );

    final u1 = (await db.collection('unidades').doc('u1').get()).data()!;
    final u2 = (await db.collection('unidades').doc('u2').get()).data()!;
    final op = (await db.collection('usuarios').doc('op1').get()).data()!;

    expect(u1['operador_asignado_id'], isNull); // liberada
    expect(u2['operador_asignado_id'], 'op1'); // reclamada
    expect(op['unidad_asignada_id'], 'u2'); // perfil actualizado
  });

  test('sin unidad previa solo reclama y registra en el perfil', () async {
    await db.collection('unidades').doc('u2').set({
      'placas': 'BBB222',
      'estado': 'activa',
    });
    await db.collection('usuarios').doc('op1').set({
      'nombre': 'Operador 1',
      'rol': 'operador',
    });

    await ds.asociarVehiculoOperador(operadorUid: 'op1', unidadId: 'u2');

    final u2 = (await db.collection('unidades').doc('u2').get()).data()!;
    final op = (await db.collection('usuarios').doc('op1').get()).data()!;
    expect(u2['operador_asignado_id'], 'op1');
    expect(op['unidad_asignada_id'], 'u2');
  });

  test('reasociar al mismo vehículo no lo libera por error', () async {
    await seed();

    await ds.asociarVehiculoOperador(
      operadorUid: 'op1',
      unidadId: 'u1',
      unidadPrevia: 'u1',
    );

    final u1 = (await db.collection('unidades').doc('u1').get()).data()!;
    expect(u1['operador_asignado_id'], 'op1'); // sigue siendo suya
  });
}
