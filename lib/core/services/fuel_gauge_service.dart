// Portado directamente de LitroExacto — lógica validada en producción.
// Compara el cambio de medidor del tanque (antes/después de carga)
// contra los litros registrados en el ticket OCR.

enum FuelGaugeStatus { reliable, unreliable }

class FuelGaugeBand {
  const FuelGaugeBand({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.minPercent,
    required this.maxPercent,
    required this.representativePercent,
  });

  final String id;
  final String label;
  final String shortLabel;
  final double minPercent;
  final double maxPercent;
  final double representativePercent;

  bool get isFull => maxPercent >= 100;

  static const List<FuelGaugeBand> standardBands = [
    FuelGaugeBand(id: 'empty',          label: 'Vacío',         shortLabel: 'Vacío', minPercent: 0,  maxPercent: 6,   representativePercent: 3),
    FuelGaugeBand(id: 'eighth',         label: '1/8 de tanque', shortLabel: '1/8',   minPercent: 7,  maxPercent: 18,  representativePercent: 12.5),
    FuelGaugeBand(id: 'quarter',        label: '1/4 de tanque', shortLabel: '1/4',   minPercent: 19, maxPercent: 31,  representativePercent: 25),
    FuelGaugeBand(id: 'three_eighths',  label: '3/8 de tanque', shortLabel: '3/8',   minPercent: 32, maxPercent: 43,  representativePercent: 37.5),
    FuelGaugeBand(id: 'half',           label: '1/2 tanque',    shortLabel: '1/2',   minPercent: 44, maxPercent: 56,  representativePercent: 50),
    FuelGaugeBand(id: 'five_eighths',   label: '5/8 de tanque', shortLabel: '5/8',   minPercent: 57, maxPercent: 68,  representativePercent: 62.5),
    FuelGaugeBand(id: 'three_quarters', label: '3/4 de tanque', shortLabel: '3/4',   minPercent: 69, maxPercent: 81,  representativePercent: 75),
    FuelGaugeBand(id: 'seven_eighths',  label: '7/8 de tanque', shortLabel: '7/8',   minPercent: 82, maxPercent: 93,  representativePercent: 87.5),
    FuelGaugeBand(id: 'full',           label: 'Lleno',         shortLabel: 'Lleno', minPercent: 94, maxPercent: 100, representativePercent: 97),
  ];

  static FuelGaugeBand? fromId(String? id) {
    if (id == null) return null;
    return standardBands.where((b) => b.id == id).firstOrNull;
  }

  static FuelGaugeBand nearestFromPercent(double? percent) {
    final p = (percent ?? 0).clamp(0.0, 100.0);
    return standardBands.reduce((cur, cand) {
      final cd = (p - cur.representativePercent).abs();
      final kd = (p - cand.representativePercent).abs();
      return kd < cd ? cand : cur;
    });
  }
}

class FuelGaugeComparison {
  const FuelGaugeComparison({
    required this.status,
    required this.beforeBand,
    required this.afterBand,
    required this.canCompare,
    required this.usedRange,
    required this.representativeDeltaLiters,
    required this.minDeltaLiters,
    required this.maxDeltaLiters,
    required this.volumetricCoherence,
    required this.note,
  });

  final FuelGaugeStatus status;
  final FuelGaugeBand? beforeBand;
  final FuelGaugeBand? afterBand;
  final bool canCompare;
  final bool usedRange;
  final double representativeDeltaLiters;
  final double minDeltaLiters;
  final double maxDeltaLiters;

  /// Score 0–100: qué tan coherente es el ticket vs el medidor.
  final double volumetricCoherence;
  final String note;
}

class FuelGaugeService {
  static FuelGaugeComparison compareRefill({
    required FuelGaugeStatus status,
    required FuelGaugeBand? beforeBand,
    required FuelGaugeBand? afterBand,
    required double tankCapacity,
    required double ticketLiters,
  }) {
    if (status == FuelGaugeStatus.unreliable) {
      return const FuelGaugeComparison(
        status: FuelGaugeStatus.unreliable,
        beforeBand: null,
        afterBand: null,
        canCompare: false,
        usedRange: false,
        representativeDeltaLiters: 0,
        minDeltaLiters: 0,
        maxDeltaLiters: 0,
        volumetricCoherence: 55,
        note: 'Medidor marcado como no confiable. Coherencia volumétrica en modo reducido.',
      );
    }

    if (beforeBand == null || afterBand == null || tankCapacity <= 0 || ticketLiters <= 0) {
      return FuelGaugeComparison(
        status: status,
        beforeBand: beforeBand,
        afterBand: afterBand,
        canCompare: false,
        usedRange: false,
        representativeDeltaLiters: 0,
        minDeltaLiters: 0,
        maxDeltaLiters: 0,
        volumetricCoherence: 45,
        note: 'Datos insuficientes para contrastar ticket contra medidor de tablero.',
      );
    }

    final minDeltaPct = (afterBand.minPercent - beforeBand.maxPercent).clamp(0.0, 100.0);
    final maxDeltaPct = (afterBand.maxPercent - beforeBand.minPercent).clamp(0.0, 100.0);
    final repDeltaPct = (afterBand.representativePercent - beforeBand.representativePercent)
        .clamp(0.0, 100.0);

    final minDeltaL = (minDeltaPct / 100) * tankCapacity;
    final maxDeltaL = (maxDeltaPct / 100) * tankCapacity;
    final repDeltaL = (repDeltaPct / 100) * tankCapacity;

    // Tolerancia: ampliada si medidor termina en "lleno"
    final tolerance = afterBand.isFull ? 2.5 : 1.0;
    final inside = ticketLiters >= (minDeltaL - tolerance) &&
        ticketLiters <= (maxDeltaL + tolerance);
    final nearest = ticketLiters < minDeltaL
        ? minDeltaL
        : ticketLiters > maxDeltaL
            ? maxDeltaL
            : ticketLiters;
    final dist = (ticketLiters - nearest).abs();

    double coherence;
    if (inside)          coherence = afterBand.isFull ? 92 : 100;
    else if (dist <= 2)  coherence = 78;
    else if (dist <= 4)  coherence = 60;
    else                 coherence = 35;

    return FuelGaugeComparison(
      status: status,
      beforeBand: beforeBand,
      afterBand: afterBand,
      canCompare: true,
      usedRange: true,
      representativeDeltaLiters: repDeltaL,
      minDeltaLiters: minDeltaL,
      maxDeltaLiters: maxDeltaL,
      volumetricCoherence: coherence,
      note: afterBand.isFull
          ? 'Medidor termina en lleno. Rango ampliado para evitar falsos positivos.'
          : 'Comparación usa bandas estandarizadas del medidor para reducir sesgo manual.',
    );
  }
}
