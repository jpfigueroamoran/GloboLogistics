import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/data/datasources/remote/firestore_datasource.dart';
import 'package:globo_logistics/domain/entities/solicitud_transporte.dart';

/// Característica: intake de solicitudes de transporte (rol Solicitante →
/// rol Despachador). Verifica creación, filtrado por solicitante y avance.
void main() {
  late FakeFirebaseFirestore db;
  late FirestoreDatasource ds;

  setUp(() {
    db = FakeFirebaseFirestore();
    ds = FirestoreDatasource(db);
  });

  Future<String> crear(String uid, {String material = 'Refacciones'}) {
    return ds.crearSolicitudTransporte({
      'solicitante_uid': uid,
      'solicitante_nombre': 'Solicitante $uid',
      'material': material,
      'origen': 'Almacén',
      'destino': 'Planta',
      'prioridad': 'alta',
    });
  }

  test('crear deja la solicitud en estado pendiente', () async {
    await crear('u1');
    final lista = await ds.watchSolicitudesPorSolicitante('u1').first;
    expect(lista.length, 1);
    expect(lista.first.estado, EstadoSolicitud.pendiente);
    expect(lista.first.material, 'Refacciones');
    expect(lista.first.prioridad, PrioridadSolicitud.alta);
  });

  test('cada solicitante solo ve las suyas', () async {
    await crear('u1');
    await crear('u2');
    expect((await ds.watchSolicitudesPorSolicitante('u1').first).length, 1);
    expect((await ds.watchSolicitudesPorSolicitante('u2').first).length, 1);
    expect((await ds.watchSolicitudes().first).length, 2);
  });

  test('el despachador avanza el estado y enlaza el viaje', () async {
    final id = await crear('u1');
    await ds.actualizarEstadoSolicitud(
      id,
      EstadoSolicitud.asignada,
      viajeId: 'v123',
    );
    final s =
        (await ds.watchSolicitudesPorSolicitante('u1').first).first;
    expect(s.estado, EstadoSolicitud.asignada);
    expect(s.viajeId, 'v123');
    expect(s.esActiva, isTrue);
  });

  test('rechazar guarda el motivo y cierra la solicitud', () async {
    final id = await crear('u1');
    await ds.actualizarEstadoSolicitud(
      id,
      EstadoSolicitud.rechazada,
      motivoRechazo: 'Sin unidades disponibles',
    );
    final s = (await ds.watchSolicitudes().first).first;
    expect(s.estado, EstadoSolicitud.rechazada);
    expect(s.motivoRechazo, 'Sin unidades disponibles');
    expect(s.esActiva, isFalse);
  });

  test('prioridad ordena la cola (urgente pesa más que baja)', () {
    expect(PrioridadSolicitud.urgente.peso,
        greaterThan(PrioridadSolicitud.baja.peso));
    expect(PrioridadSolicitud.alta.peso,
        greaterThan(PrioridadSolicitud.normal.peso));
  });
}
