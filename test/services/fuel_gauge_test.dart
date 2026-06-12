import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/core/services/fuel_gauge_service.dart';

/// Característica: auditoría volumétrica del medidor de tanque (Litro Exacto).
/// Contrasta el cambio de banda del medidor contra los litros del ticket.
void main() {
  FuelGaugeBand band(String id) => FuelGaugeBand.fromId(id)!;

  group('FuelGauge — bandas', () {
    test('mapea porcentaje a la banda más cercana', () {
      expect(FuelGaugeBand.nearestFromPercent(50).id, 'half');
      expect(FuelGaugeBand.nearestFromPercent(0).id, 'empty');
      expect(FuelGaugeBand.nearestFromPercent(100).id, 'full');
    });

    test('clampa porcentajes fuera de rango', () {
      expect(FuelGaugeBand.nearestFromPercent(-20).id, 'empty');
      expect(FuelGaugeBand.nearestFromPercent(200).id, 'full');
    });
  });

  group('FuelGauge — comparación', () {
    test('medidor no confiable degrada coherencia y no compara', () {
      final r = FuelGaugeService.compareRefill(
        status: FuelGaugeStatus.unreliable,
        beforeBand: band('quarter'),
        afterBand: band('full'),
        tankCapacity: 400,
        ticketLiters: 300,
      );
      expect(r.canCompare, isFalse);
      expect(r.volumetricCoherence, 55);
    });

    test('datos insuficientes → no compara', () {
      final r = FuelGaugeService.compareRefill(
        status: FuelGaugeStatus.reliable,
        beforeBand: null,
        afterBand: band('full'),
        tankCapacity: 400,
        ticketLiters: 300,
      );
      expect(r.canCompare, isFalse);
    });

    test('ticket coherente con el cambio de medidor → coherencia alta', () {
      // 1/4 (25%) → 3/4 (75%) en tanque de 400 L ≈ 200 L representativos
      final r = FuelGaugeService.compareRefill(
        status: FuelGaugeStatus.reliable,
        beforeBand: band('quarter'),
        afterBand: band('three_quarters'),
        tankCapacity: 400,
        ticketLiters: 200,
      );
      expect(r.canCompare, isTrue);
      expect(r.volumetricCoherence, 100);
      expect(r.representativeDeltaLiters, closeTo(200, 1));
    });

    test('ticket muy por encima del cambio físico → coherencia baja', () {
      // 1/2 → 5/8 es un cambio pequeño; 350 L es imposible → sospechoso
      final r = FuelGaugeService.compareRefill(
        status: FuelGaugeStatus.reliable,
        beforeBand: band('half'),
        afterBand: band('five_eighths'),
        tankCapacity: 400,
        ticketLiters: 350,
      );
      expect(r.canCompare, isTrue);
      expect(r.volumetricCoherence, lessThan(60));
    });

    test('tanque que termina lleno amplía la tolerancia', () {
      final r = FuelGaugeService.compareRefill(
        status: FuelGaugeStatus.reliable,
        beforeBand: band('empty'),
        afterBand: band('full'),
        tankCapacity: 400,
        ticketLiters: 390,
      );
      expect(r.canCompare, isTrue);
      expect(r.note, contains('lleno'));
    });
  });
}
