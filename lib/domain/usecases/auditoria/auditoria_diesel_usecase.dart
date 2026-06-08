// Adaptado de AuditNotifier.performFullAudit() de LitroExacto.
// Ejecuta toda la lógica LOCALMENTE (costo $0).
// Solo el AuditoriaResultado final se sube a Firestore.
//
// Contexto Globo Logistics:
//   - litrosTickets  → suma de litros capturados por OCR en costos_operativos del viaje
//   - litrosTelemetria → calculado desde odómetro y rendimiento base de la unidad
//   - Umbral bandera roja: 1.5 % (configurable en AppConstants)

import 'package:dartz/dartz.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/services/fuel_gauge_service.dart';
import '../../entities/auditoria_resultado.dart';
import '../../repositories/i_viaje_repository.dart';

class AuditoriaDieselParams {
  final String viajeId;

  /// Odómetro al inicio y fin del viaje (km)
  final double odometroInicio;
  final double odometroFin;

  /// Capacidad del tanque de la unidad (L)
  final double capacidadTanque;

  /// Rendimiento base registrado en la unidad (km/L)
  final double rendimientoBaseKmL;

  /// Litros acumulados de todos los tickets OCR del viaje
  final double litrosTickets;

  /// Score promedio de credibilidad OCR de los tickets (0–100)
  final double credibilidadOcrPromedio;

  /// Estado del medidor antes y después de la última carga
  final FuelGaugeBand? medidorAntes;
  final FuelGaugeBand? medidorDespues;
  final FuelGaugeStatus estadoMedidor;

  const AuditoriaDieselParams({
    required this.viajeId,
    required this.odometroInicio,
    required this.odometroFin,
    required this.capacidadTanque,
    required this.rendimientoBaseKmL,
    required this.litrosTickets,
    required this.credibilidadOcrPromedio,
    this.medidorAntes,
    this.medidorDespues,
    this.estadoMedidor = FuelGaugeStatus.reliable,
  });
}

class AuditoriaDieselUsecase {
  final IViajeRepository _viajeRepository;

  const AuditoriaDieselUsecase(this._viajeRepository);

  Future<Either<Failure, AuditoriaResultado>> call(
      AuditoriaDieselParams p) async {
    try {
      // ── 1. Calcular litros por telemetría ─────────────────────────────
      final distanciaKm = (p.odometroFin - p.odometroInicio)
          .clamp(0.0, double.infinity);

      // Si no hay rendimiento base, usamos el estándar de camión diésel mexicano
      final rendimiento =
          p.rendimientoBaseKmL > 0 ? p.rendimientoBaseKmL : 3.5;

      final litrosTelemetria = distanciaKm > 0
          ? distanciaKm / rendimiento
          : p.litrosTickets; // fallback: confiar en tickets si no hay km

      // ── 2. Comparación con medidor de tablero ─────────────────────────
      final gaugeResult = FuelGaugeService.compareRefill(
        status: p.estadoMedidor,
        beforeBand: p.medidorAntes,
        afterBand: p.medidorDespues,
        tankCapacity: p.capacidadTanque,
        ticketLiters: p.litrosTickets,
      );

      // Usar telemetría del medidor si es confiable, si no usar km/rendimiento
      final litrosReferencia = gaugeResult.canCompare
          ? gaugeResult.representativeDeltaLiters
          : litrosTelemetria;

      // ── 3. Cálculo de varianza ─────────────────────────────────────────
      final delta = litrosReferencia - p.litrosTickets;
      final varianzaPct = litrosReferencia > 0
          ? (delta.abs() / litrosReferencia) * 100
          : 0.0;

      // ── 4. Tolerancia dinámica (portada de LitroExacto) ───────────────
      // max(0.3L, 2% de los litros esperados)
      final tolerancia = [0.3, litrosReferencia * 0.02].reduce(
          (a, b) => a > b ? a : b);

      // ── 5. Clasificación del nivel de varianza ────────────────────────
      final nivel = _clasificarNivel(
        deltaAbs: delta.abs(),
        tolerancia: tolerancia,
        varianzaPct: varianzaPct,
      );

      // ── 6. Score compuesto ────────────────────────────────────────────
      // coherenciaVolumetrica × 0.40 + credibilidadOcr × 0.35 + consistencia × 0.25
      final consistencia = _consistencyScore(varianzaPct);
      final scoreCompuesto = gaugeResult.volumetricCoherence * 0.40 +
          p.credibilidadOcrPromedio * 0.35 +
          consistencia * 100 * 0.25;

      // ── 7. Resumen legible ────────────────────────────────────────────
      final resumen = _generarResumen(
        litrosTickets: p.litrosTickets,
        litrosReferencia: litrosReferencia,
        delta: delta,
        varianzaPct: varianzaPct,
        nivel: nivel,
        distanciaKm: distanciaKm,
        gaugeNote: gaugeResult.note,
      );

      final resultado = AuditoriaResultado(
        litrosTickets: p.litrosTickets,
        litrosTelemetria: litrosReferencia,
        deltaLitros: delta,
        varianzaPct: varianzaPct,
        toleranciaDinamica: tolerancia,
        nivel: nivel,
        coherenciaVolumetrica: gaugeResult.volumetricCoherence,
        credibilidadOcr: p.credibilidadOcrPromedio,
        scoreCompuesto: scoreCompuesto.clamp(0, 100),
        medidorNoConfiable: p.estadoMedidor == FuelGaugeStatus.unreliable,
        notaVolumetrica: gaugeResult.note,
        resumen: resumen,
        timestamp: DateTime.now(),
      );

      // ── 8. Persistir en Firestore si hay bandera roja ─────────────────
      if (resultado.tieneBanderaRoja) {
        await _viajeRepository.marcarBanderaRoja(p.viajeId, varianzaPct / 100);
      }

      return Right(resultado);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  NivelVarianza _clasificarNivel({
    required double deltaAbs,
    required double tolerancia,
    required double varianzaPct,
  }) {
    if (deltaAbs <= tolerancia) return NivelVarianza.limpio;
    // Umbrales equivalentes a LitroExacto pero ajustados a flota (1.5 % mínimo)
    if (varianzaPct <= AppConstants.varianzaCombustibleUmbral * 100) {
      return NivelVarianza.limpio;
    }
    if (varianzaPct <= 5.0) return NivelVarianza.advertencia;
    if (varianzaPct <= 15.0) return NivelVarianza.sospechoso;
    return NivelVarianza.fraudeProbable;
  }

  /// Score de consistencia de datos (de 0 a 1) — portado de calculateDataConsistency().
  double _consistencyScore(double varianzaPct) {
    final v = varianzaPct.abs();
    if (v <= 1)  return 1.0;
    if (v <= 3)  return 0.9;
    if (v <= 5)  return 0.8;
    if (v <= 10) return 0.6;
    if (v <= 20) return 0.4;
    return 0.2;
  }

  String _generarResumen({
    required double litrosTickets,
    required double litrosReferencia,
    required double delta,
    required double varianzaPct,
    required NivelVarianza nivel,
    required double distanciaKm,
    required String gaugeNote,
  }) {
    final buf = StringBuffer();
    buf.writeln(nivel == NivelVarianza.limpio
        ? 'CARGA CONCILIADA'
        : 'ALERTA DE VARIANZA — ${nivel.label.toUpperCase()}');
    buf.writeln('─────────────────────────────');
    buf.writeln('Distancia del viaje: ${distanciaKm.toStringAsFixed(0)} km');
    buf.writeln('Litros (tickets OCR): ${litrosTickets.toStringAsFixed(2)} L');
    buf.writeln('Litros (telemetría): ${litrosReferencia.toStringAsFixed(2)} L');
    buf.writeln('Delta: ${delta.toStringAsFixed(2)} L');
    buf.writeln('Varianza: ${varianzaPct.toStringAsFixed(2)} %');
    buf.writeln('');
    buf.writeln(gaugeNote);
    return buf.toString();
  }
}
