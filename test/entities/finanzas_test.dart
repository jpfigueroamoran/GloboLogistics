import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/domain/entities/activo_fijo.dart';
import 'package:globo_logistics/domain/entities/documento_vencimiento.dart';
import 'package:globo_logistics/domain/entities/factura_cliente.dart';
import 'package:globo_logistics/domain/entities/poliza_seguro.dart';

void main() {
  final ahora = DateTime(2026, 6, 12);

  FacturaCliente factura(DateTime vence) => FacturaCliente(
        id: 'f',
        viajeId: 'v',
        clienteId: 'c',
        clienteNombre: 'X',
        numeroFactura: 'GL-2026-0001',
        fechaEmision: ahora.subtract(const Duration(days: 30)),
        fechaVencimiento: vence,
        monto: 1000,
        estatus: EstatusFactura.pendiente,
      );

  group('Facturación — aging de CxC', () {
    test('no vencida → corriente', () {
      expect(factura(ahora.add(const Duration(days: 5))).bucketAging(ahora),
          BucketAging.corriente);
    });
    test('vencida ≤30 días', () {
      expect(factura(ahora.subtract(const Duration(days: 10))).bucketAging(ahora),
          BucketAging.vencido30);
    });
    test('vencida 31-60 días', () {
      expect(factura(ahora.subtract(const Duration(days: 45))).bucketAging(ahora),
          BucketAging.vencido60);
    });
    test('vencida 61-90 días', () {
      expect(factura(ahora.subtract(const Duration(days: 75))).bucketAging(ahora),
          BucketAging.vencido90);
    });
    test('vencida >90 días', () {
      expect(factura(ahora.subtract(const Duration(days: 120))).bucketAging(ahora),
          BucketAging.vencido90mas);
    });
    test('pendiente cuenta como por cobrar', () {
      expect(factura(ahora).esPendienteOVencida, isTrue);
    });
  });

  group('Pólizas — semáforo de vigencia', () {
    PolizaSeguro poliza(DateTime fin) => PolizaSeguro(
          id: 'p',
          tipo: TipoPoliza.responsabilidadCivil,
          aseguradora: 'GNP',
          numeroPoliza: 'POL-1',
          vigenciaInicio: ahora.subtract(const Duration(days: 300)),
          vigenciaFin: fin,
          primaMensual: 1500,
          coberturaMaxima: 1000000,
          deducible: 5000,
        );

    test('vigente cuando faltan >30 días', () {
      expect(poliza(ahora.add(const Duration(days: 90))).semaforo(ahora),
          SemaforoDocumento.vigente);
    });
    test('próximo a vencer dentro de 30 días', () {
      expect(poliza(ahora.add(const Duration(days: 15))).semaforo(ahora),
          SemaforoDocumento.proximoVencer);
    });
    test('vencida cuando la fecha ya pasó', () {
      expect(poliza(ahora.subtract(const Duration(days: 1))).semaforo(ahora),
          SemaforoDocumento.vencido);
    });
  });

  group('Activos fijos — depreciación lineal', () {
    final activo = ActivoFijo(
      id: 'a',
      unidadId: 'u',
      descripcion: 'Tractocamión',
      fechaAdquisicion: DateTime(2026, 6, 12),
      costoAdquisicion: 100000,
      valorResidual: 10000,
      vidaUtilAnios: 10,
    );

    test('depreciación anual y mensual', () {
      expect(activo.depreciacionAnual, 9000);
      expect(activo.depreciacionMensual, 750);
    });
    test('valor en libros recién adquirido = costo', () {
      expect(activo.valorLibros(DateTime(2026, 6, 12)), 100000);
    });
    test('valor en libros tras 1 año', () {
      expect(activo.valorLibros(DateTime(2027, 6, 12)), closeTo(91000, 1));
    });
    test('valor en libros nunca baja del residual', () {
      expect(activo.valorLibros(DateTime(2050, 1, 1)), 10000);
    });
    test('porcentaje depreciado al final de la vida útil = 100 %', () {
      expect(activo.porcentajeDepreciado(DateTime(2050, 1, 1)), 1.0);
    });
  });

  group('Documentos — semáforo de vencimiento', () {
    DocumentoVencimiento doc(DateTime vence) => DocumentoVencimiento(
          id: 'd',
          entidadId: 'op1',
          nombreEntidad: 'Carlos',
          tipo: TipoDocumento.licenciaConducir,
          fechaVencimiento: vence,
        );

    test('vigente >30 días', () {
      expect(doc(ahora.add(const Duration(days: 60))).semaforo(ahora),
          SemaforoDocumento.vigente);
    });
    test('próximo a vencer ≤30 días', () {
      expect(doc(ahora.add(const Duration(days: 10))).semaforo(ahora),
          SemaforoDocumento.proximoVencer);
    });
    test('vencido', () {
      expect(doc(ahora.subtract(const Duration(days: 5))).semaforo(ahora),
          SemaforoDocumento.vencido);
    });
  });
}
