// Adaptado de AuditResult de LitroExacto para el contexto de flota logística.
// Representa el resultado de la auditoría "Litro Exacto" de un viaje.
// El cálculo se ejecuta en el cliente (costo $0); solo este objeto sube a Firestore.

import 'package:equatable/equatable.dart';

enum NivelVarianza {
  limpio,      // < 1.5 %
  advertencia, // 1.5 % – 5 %
  sospechoso,  // 5 % – 15 %
  fraudeProbable, // > 15 %
}

extension NivelVarianzaExt on NivelVarianza {
  String get label => switch (this) {
        NivelVarianza.limpio           => 'Conciliado',
        NivelVarianza.advertencia      => 'Advertencia',
        NivelVarianza.sospechoso       => 'Sospechoso',
        NivelVarianza.fraudeProbable   => 'Probable Fraude',
      };

  bool get requiereBanderaRoja =>
      this == NivelVarianza.sospechoso || this == NivelVarianza.fraudeProbable;
}

class AuditoriaResultado extends Equatable {
  /// Litros reportados en tickets OCR
  final double litrosTickets;

  /// Litros calculados por telemetría (km recorridos / rendimiento base)
  final double litrosTelemetria;

  /// Diferencia absoluta: litrosTelemetria - litrosTickets
  final double deltaLitros;

  /// Varianza porcentual: |deltaLitros| / litrosTelemetria
  final double varianzaPct;

  /// Tolerancia dinámica aplicada: max(0.3, litrosTelemetria × 0.02)
  final double toleranciaDinamica;

  /// Nivel resultante de la auditoría
  final NivelVarianza nivel;

  /// Coherencia volumétrica del FuelGaugeService (0–100)
  final double coherenciaVolumetrica;

  /// Score de credibilidad del ticket OCR (0–100)
  final double credibilidadOcr;

  /// Score compuesto: coherencia × 0.4 + credibilidadOcr × 0.35 + consistencia × 0.25
  final double scoreCompuesto;

  /// Si el medidor del tanque fue marcado como no confiable
  final bool medidorNoConfiable;

  /// Nota técnica del FuelGaugeService
  final String notaVolumetrica;

  /// Resumen legible para el operador / supervisor
  final String resumen;

  final DateTime timestamp;

  const AuditoriaResultado({
    required this.litrosTickets,
    required this.litrosTelemetria,
    required this.deltaLitros,
    required this.varianzaPct,
    required this.toleranciaDinamica,
    required this.nivel,
    required this.coherenciaVolumetrica,
    required this.credibilidadOcr,
    required this.scoreCompuesto,
    this.medidorNoConfiable = false,
    required this.notaVolumetrica,
    required this.resumen,
    required this.timestamp,
  });

  bool get tieneBanderaRoja => nivel.requiereBanderaRoja;
  bool get estaDentroTolerancia => deltaLitros.abs() <= toleranciaDinamica;

  Map<String, dynamic> toFirestore() => {
        'litros_tickets': litrosTickets,
        'litros_telemetria': litrosTelemetria,
        'delta_litros': deltaLitros,
        'varianza_pct': varianzaPct,
        'tolerancia_dinamica': toleranciaDinamica,
        'nivel': nivel.name,
        'coherencia_volumetrica': coherenciaVolumetrica,
        'credibilidad_ocr': credibilidadOcr,
        'score_compuesto': scoreCompuesto,
        'medidor_no_confiable': medidorNoConfiable,
        'nota_volumetrica': notaVolumetrica,
        'resumen': resumen,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        litrosTickets,
        litrosTelemetria,
        varianzaPct,
        nivel,
        scoreCompuesto,
        timestamp,
      ];
}
