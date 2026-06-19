import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/core/services/automatizacion_service.dart';

/// Característica: motor de automatización client-side (reemplazo costo-cero
/// de las Cloud Functions). Se verifica contra un Firestore en memoria.
void main() {
  late FakeFirebaseFirestore db;
  late AutomatizacionService motor;

  setUp(() {
    db = FakeFirebaseFirestore();
    motor = AutomatizacionService(db);
  });

  Timestamp ayer() =>
      Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1)));

  group('Ciclo de vida — viaje enCurso', () {
    test('asigna fecha_inicio, marca unidad en ruta y registra actividad',
        () async {
      await db.collection('unidades').doc('u1').set({
        'placas': 'ABC123',
        'estado': 'activa',
      });
      await db.collection('viajes').doc('v1').set({
        'estado': 'enCurso',
        'unidad_id': 'u1',
        'operador_id': 'op1',
        'operador_nombre': 'Carlos',
        'updated_at': ayer(),
      });

      await motor.ejecutar();

      final viaje = (await db.collection('viajes').doc('v1').get()).data()!;
      expect(viaje['lc_iniciado'], isTrue);
      expect(viaje['fecha_inicio'], isNotNull);

      final unidad = (await db.collection('unidades').doc('u1').get()).data()!;
      expect(unidad['viaje_activo_id'], 'v1');

      final actividad = await db
          .collection('actividad_operativa')
          .where('tipo', isEqualTo: 'viaje_iniciado')
          .get();
      expect(actividad.size, 1);

      // Idempotencia: segunda corrida no duplica actividad
      await motor.ejecutar();
      final actividad2 = await db
          .collection('actividad_operativa')
          .where('tipo', isEqualTo: 'viaje_iniciado')
          .get();
      expect(actividad2.size, 1);
    });
  });

  group('Ciclo de vida — viaje completado', () {
    Future<void> seedViajeCompletado({double odometroFin = 1350}) async {
      await db.collection('unidades').doc('u1').set({
        'placas': 'ABC123',
        'estado': 'activa',
        'viaje_activo_id': 'v1',
        'proximo_mantenimiento_odometro': 2000,
      });
      await db.collection('viajes').doc('v1').set({
        'estado': 'completado',
        'unidad_id': 'u1',
        'operador_id': 'op1',
        'operador_nombre': 'Carlos',
        'cliente_id': 'c1',
        'cliente_nombre': 'Acme',
        'odometro_inicio': 1000,
        'odometro_fin': odometroFin,
        'updated_at': ayer(),
      });
      await db.collection('costos_operativos').add({
        'viaje_id': 'v1',
        'tipo': 'combustible',
        'monto': 1000,
        'litros': 100,
        'supervisado': true,
        'created_at': ayer(),
      });
      await db.collection('costos_operativos').add({
        'viaje_id': 'v1',
        'tipo': 'peaje',
        'monto': 300,
        'created_at': ayer(),
      });
      await db.collection('alertas_seguridad').doc('a1').set({
        'tipo': 'geocerca',
        'estado': 'activa',
        'viaje_id': 'v1',
        'operador_id': 'op1',
      });
    }

    test('calcula TCO, libera unidad, cierra alertas, score y factura',
        () async {
      await seedViajeCompletado();
      await motor.ejecutar();

      final viaje = (await db.collection('viajes').doc('v1').get()).data()!;
      expect(viaje['lc_completado'], isTrue);
      expect(viaje['tco']['total'], 1300);
      expect(viaje['costo_por_km'], closeTo(1300 / 350, 0.01));

      final unidad = (await db.collection('unidades').doc('u1').get()).data()!;
      expect(unidad['estado'], 'activa'); // 1350 < 2000 → no taller
      expect(unidad['viaje_activo_id'], isNull);
      expect(unidad['odometro'], 1350);

      final alerta =
          (await db.collection('alertas_seguridad').doc('a1').get()).data()!;
      expect(alerta['estado'], 'cerrada_automaticamente');

      final score =
          (await db.collection('scores_operadores').doc('op1').get()).data()!;
      expect(score['total_viajes'], 1);
      expect(score['score'], 100);

      final facturas = await db.collection('facturas_clientes').get();
      expect(facturas.size, 1);
      final f = facturas.docs.first.data();
      final anio = DateTime.now().year;
      expect(f['numero_factura'], 'GL-$anio-0001');
      // margen default 15 %, sin IVA configurado
      expect(f['monto'], closeTo(1300 * 1.15, 0.01));
      expect(f['estatus'], 'pendiente');
    });

    test('es idempotente: una segunda corrida no duplica factura ni score',
        () async {
      await seedViajeCompletado();
      await motor.ejecutar();
      await motor.ejecutar();

      expect((await db.collection('facturas_clientes').get()).size, 1);
      final score =
          (await db.collection('scores_operadores').doc('op1').get()).data()!;
      expect(score['total_viajes'], 1);
    });

    test('manda la unidad a taller si alcanzó el odómetro de servicio',
        () async {
      await seedViajeCompletado(odometroFin: 2100); // ≥ 2000
      await motor.ejecutar();

      final unidad = (await db.collection('unidades').doc('u1').get()).data()!;
      expect(unidad['estado'], 'mantenimiento');
    });

    test('usa los parámetros de facturación del wizard (config/pricing)',
        () async {
      await db.collection('config').doc('pricing').set({
        'serie_folio': 'ACME',
        'margen_pct': 0.20,
        'iva_pct': 0.16,
        'dias_credito': 15,
      });
      await seedViajeCompletado();
      await motor.ejecutar();

      final f =
          (await db.collection('facturas_clientes').get()).docs.first.data();
      final anio = DateTime.now().year;
      expect(f['numero_factura'], 'ACME-$anio-0001');
      expect(f['monto'], closeTo(1300 * 1.20 * 1.16, 0.01));
    });
  });

  group('Enlace solicitud ↔ viaje', () {
    Future<void> seedUnidad() => db.collection('unidades').doc('u1').set({
          'placas': 'AAA111',
          'estado': 'activa',
        });

    test('al iniciar el viaje, su solicitud pasa a "en ruta"', () async {
      await seedUnidad();
      await db.collection('solicitudes_transporte').doc('s1').set({
        'solicitante_uid': 'u1',
        'material': 'Refacciones',
        'estado': 'asignada',
      });
      await db.collection('viajes').doc('v1').set({
        'estado': 'enCurso',
        'unidad_id': 'u1',
        'operador_id': 'op1',
        'solicitud_id': 's1',
        'updated_at': ayer(),
      });

      await motor.ejecutar();

      final s =
          (await db.collection('solicitudes_transporte').doc('s1').get())
              .data()!;
      expect(s['estado'], 'enRuta');
    });

    test('al completar el viaje, su solicitud pasa a "entregada"', () async {
      await seedUnidad();
      await db.collection('solicitudes_transporte').doc('s2').set({
        'solicitante_uid': 'u1',
        'material': 'Tarimas',
        'estado': 'enRuta',
      });
      await db.collection('viajes').doc('v2').set({
        'estado': 'completado',
        'unidad_id': 'u1',
        'operador_id': 'op1',
        'solicitud_id': 's2',
        'odometro_inicio': 1000,
        'odometro_fin': 1100,
        'updated_at': ayer(),
      });

      await motor.ejecutar();

      final s =
          (await db.collection('solicitudes_transporte').doc('s2').get())
              .data()!;
      expect(s['estado'], 'entregada');
    });

    test('un viaje sin solicitud ligada no rompe el motor', () async {
      await seedUnidad();
      await db.collection('viajes').doc('v3').set({
        'estado': 'enCurso',
        'unidad_id': 'u1',
        'operador_id': 'op1',
        'updated_at': ayer(),
      });
      await motor.ejecutar();
      final v = (await db.collection('viajes').doc('v3').get()).data()!;
      expect(v['lc_iniciado'], isTrue);
    });
  });

  group('Supervisión de tickets de combustible', () {
    test('marca anomalía y crea alerta cuando excede 110 % de la carga',
        () async {
      await db.collection('viajes').doc('v1').set({
        'estado': 'enCurso',
        'lc_iniciado': true,
        'operador_id': 'op1',
        'unidad_id': 'u1',
        'litros_cargados': 100,
        'updated_at': ayer(),
      });
      final costo = await db.collection('costos_operativos').add({
        'viaje_id': 'v1',
        'tipo': 'combustible',
        'litros': 150, // 150 > 110
        'monto': 3500,
        'created_at': ayer(),
      });

      await motor.ejecutar();

      final c = (await costo.get()).data()!;
      expect(c['supervisado'], isTrue);
      expect(c['anomalia_detectada'], isTrue);
      expect(c['anomalia_motivo'], contains('110%'));

      final alertas = await db
          .collection('alertas_seguridad')
          .where('tipo', isEqualTo: 'ticketAnomalo')
          .get();
      expect(alertas.size, 1);
    });

    test('ticket normal queda supervisado sin alerta', () async {
      await db.collection('viajes').doc('v1').set({
        'estado': 'enCurso',
        'lc_iniciado': true,
        'litros_cargados': 100,
        'updated_at': ayer(),
      });
      final costo = await db.collection('costos_operativos').add({
        'viaje_id': 'v1',
        'tipo': 'combustible',
        'litros': 95,
        'monto': 2200,
        'created_at': ayer(),
      });

      await motor.ejecutar();

      final c = (await costo.get()).data()!;
      expect(c['supervisado'], isTrue);
      expect(c['anomalia_detectada'], isFalse);
      expect(
        (await db
                .collection('alertas_seguridad')
                .where('tipo', isEqualTo: 'ticketAnomalo')
                .get())
            .size,
        0,
      );
    });
  });

  group('Normalización de clientes', () {
    test('valida RFC correcto, normaliza a mayúsculas y agrega búsqueda',
        () async {
      final ref = await db.collection('clientes').add({
        'nombre': 'Acme Corp',
        'direccion': 'Av. Reforma 222',
        'rfc': 'acm123456789',
        'activo': true,
      });

      await motor.ejecutar();

      final c = (await ref.get()).data()!;
      expect(c['nombre_busqueda'], 'acme corp');
      expect(c['rfc'], 'ACM123456789');
      expect(c['rfc_valido'], isTrue);
      expect(c['rfc_duplicado'], isFalse);
    });

    test('marca RFC con formato inválido', () async {
      final ref = await db.collection('clientes').add({
        'nombre': 'Mal RFC SA',
        'rfc': 'XX12',
        'activo': true,
      });

      await motor.ejecutar();

      final c = (await ref.get()).data()!;
      expect(c['rfc_valido'], isFalse);
      expect(c['rfc_invalido_motivo'], isNotNull);
    });

    test('detecta RFC duplicado entre clientes activos', () async {
      await db.collection('clientes').add({
        'nombre': 'Original',
        'rfc': 'ACM123456789',
        'rfc_valido': true,
        'activo': true,
      });
      final dup = await db.collection('clientes').add({
        'nombre': 'Duplicado',
        'rfc': 'ACM123456789',
        'activo': true,
      });

      await motor.ejecutar();

      final c = (await dup.get()).data()!;
      expect(c['rfc_duplicado'], isTrue);
    });
  });

  group('Cuentas por pagar', () {
    test('marca vencidas solo las facturas pendientes con fecha pasada',
        () async {
      final vencida = await db.collection('facturas_proveedores').add({
        'estatus': 'pendiente',
        'fecha_vencimiento': ayer(),
      });
      final vigente = await db.collection('facturas_proveedores').add({
        'estatus': 'pendiente',
        'fecha_vencimiento': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 10))),
      });

      await motor.ejecutar();

      expect((await vencida.get()).data()!['estatus'], 'vencida');
      expect((await vigente.get()).data()!['estatus'], 'pendiente');
    });
  });

  group('Pólizas por vencer', () {
    test('crea alerta una sola vez por póliza', () async {
      await db.collection('polizas_seguro').doc('p1').set({
        'numero_poliza': 'POL-1',
        'unidad_id': 'u1',
        'vigencia_fin': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 10))),
      });

      await motor.ejecutar();
      await motor.ejecutar();

      final alertas = await db
          .collection('alertas_seguridad')
          .where('tipo', isEqualTo: 'polizaPorVencer')
          .get();
      expect(alertas.size, 1);
      expect(alertas.docs.first.data()['estado'], 'activa');
    });
  });

  group('Stock mínimo', () {
    test('alerta cuando el stock cae al mínimo, sin duplicar', () async {
      await db.collection('inventario').doc('i1').set({
        'nombre': 'Aceite 15W40',
        'stock_actual': 2,
        'stock_minimo': 5,
      });
      await db.collection('inventario').doc('i2').set({
        'nombre': 'Anticongelante',
        'stock_actual': 20,
        'stock_minimo': 5,
      });

      await motor.ejecutar();
      await motor.ejecutar();

      final alertas = await db
          .collection('alertas_seguridad')
          .where('tipo', isEqualTo: 'stockMinimo')
          .get();
      expect(alertas.size, 1);
      expect(alertas.docs.first.data()['item_id'], 'i1');
    });
  });

  group('Cierre mensual', () {
    test('genera el resumen del mes anterior una sola vez', () async {
      await db.collection('activos_fijos').add({
        'costo_adquisicion': 100000,
        'valor_residual': 10000,
        'vida_util_anios': 10,
        'fecha_adquisicion': Timestamp.fromDate(DateTime(2024, 1, 1)),
      });

      await motor.ejecutar();
      await motor.ejecutar();

      final resumenes = await db.collection('resumenes_financieros').get();
      expect(resumenes.size, 1);
      final r = resumenes.docs.first.data();
      expect(r['depreciacion_mensual_flota'], closeTo(750, 0.5));
      expect(r['total_activos'], 1);

      final ahora = DateTime.now();
      final prev = DateTime(ahora.year, ahora.month - 1, 1);
      expect(r['periodo_id'],
          '${prev.year}-${prev.month.toString().padLeft(2, '0')}');
    });
  });

  group('Recálculo semanal de varianzas', () {
    test('corrige una bandera roja que ya no se sostiene con los costos',
        () async {
      // 350 km / 3.5 km·L = 100 L esperados; tickets = 100 L → limpio
      await db.collection('viajes').doc('v1').set({
        'estado': 'completado',
        'lc_completado': true,
        'nivel_alerta': 'bandajaRoja',
        'odometro_inicio': 1000,
        'odometro_fin': 1350,
        'rendimiento_base': 3.5,
        'updated_at': ayer(),
      });
      await db.collection('costos_operativos').add({
        'viaje_id': 'v1',
        'tipo': 'combustible',
        'litros': 100,
        'supervisado': true,
        'datos_ocr': {'litros_detectados': 100},
        'created_at': ayer(),
      });

      await motor.ejecutar();

      final v = (await db.collection('viajes').doc('v1').get()).data()!;
      expect(v['nivel_alerta'], 'ninguna');

      final cfg =
          (await db.collection('config').doc('automatizacion').get()).data()!;
      expect(cfg['recalculo_varianzas_at'], isNotNull);
    });

    test('respeta la ventana de 7 días entre recálculos', () async {
      await db.collection('config').doc('automatizacion').set({
        'recalculo_varianzas_at': Timestamp.fromDate(
            DateTime.now().subtract(const Duration(days: 2))),
      });
      await db.collection('viajes').doc('v1').set({
        'estado': 'completado',
        'lc_completado': true,
        'nivel_alerta': 'bandajaRoja',
        'odometro_inicio': 1000,
        'odometro_fin': 1350,
        'rendimiento_base': 3.5,
        'updated_at': ayer(),
      });
      await db.collection('costos_operativos').add({
        'viaje_id': 'v1',
        'tipo': 'combustible',
        'litros': 100,
        'supervisado': true,
        'created_at': ayer(),
      });

      await motor.ejecutar();

      // Corrió hace 2 días → no debe recalcular todavía
      final v = (await db.collection('viajes').doc('v1').get()).data()!;
      expect(v['nivel_alerta'], 'bandajaRoja');
    });
  });
}
