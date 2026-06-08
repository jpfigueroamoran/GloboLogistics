// Adaptado de LitroExacto ReportEvidenceService para el contexto de flota.
// Evalúa la calidad de la evidencia de un costo operativo (ticket OCR)
// antes de que sea conciliado en la auditoría "Litro Exacto" de Globo.

enum NivelEvidencia { fuerte, parcial, debil, inconsistente }

class PerfilEvidenciaCosto {
  final NivelEvidencia nivel;
  final int score;
  final bool aportaAuditoria;
  final double pesoAuditoria; // 0.0–1.0
  final List<String> factoresFavorables;
  final List<String> observaciones;

  const PerfilEvidenciaCosto({
    required this.nivel,
    required this.score,
    required this.aportaAuditoria,
    required this.pesoAuditoria,
    required this.factoresFavorables,
    required this.observaciones,
  });

  String get nivelLabel => switch (nivel) {
        NivelEvidencia.fuerte       => 'Fuerte',
        NivelEvidencia.parcial      => 'Parcial',
        NivelEvidencia.debil        => 'Débil',
        NivelEvidencia.inconsistente => 'Inconsistente',
      };

  String get resumenCorto => switch (nivel) {
        NivelEvidencia.fuerte        => 'Ticket válido. Aporta a la auditoría de combustible.',
        NivelEvidencia.parcial       => 'Ticket aceptable. Se recomienda reforzar en próximas cargas.',
        NivelEvidencia.debil         => 'Registro de referencia. No suficiente para conciliación.',
        NivelEvidencia.inconsistente => 'Inconsistencias detectadas. Solo referencia informativa.',
      };
}

/// Parámetros de entrada para la evaluación.
class DatosTicketEvaluacion {
  final double? litrosOcr;
  final double? montoOcr;
  final double? precioOcrPorLitro;
  final String? folio;
  final DateTime? fechaTicket;
  final bool tieneImagen;
  final bool imagenEsFisica;
  final double capacidadTanque;
  final double? coherenciaVolumetrica; // 0–100, del FuelGaugeService
  final double confianzaOcr;           // 0–1, del MLKit
  final bool datosManuales;

  const DatosTicketEvaluacion({
    this.litrosOcr,
    this.montoOcr,
    this.precioOcrPorLitro,
    this.folio,
    this.fechaTicket,
    required this.tieneImagen,
    required this.imagenEsFisica,
    required this.capacidadTanque,
    this.coherenciaVolumetrica,
    required this.confianzaOcr,
    this.datosManuales = false,
  });
}

abstract final class CostoEvidenceService {
  static PerfilEvidenciaCosto evaluar(DatosTicketEvaluacion datos) {
    var score = (datos.confianzaOcr * 60).round().clamp(0, 60);
    final favorables = <String>[];
    final observaciones = <String>[];

    // ── Datos mínimos del ticket ───────────────────────────────────────
    final tieneTicketCompleto = datos.litrosOcr != null &&
        datos.montoOcr != null &&
        datos.precioOcrPorLitro != null;

    if (tieneTicketCompleto) {
      score += 12;
      favorables.add('Ticket con litros, monto y precio por litro detectados.');
    } else {
      score -= 12;
      observaciones.add('Faltan datos del ticket (litros, monto o precio).');
    }

    if (datos.folio != null) {
      score += 5;
      favorables.add('Folio de ticket detectado.');
    } else {
      observaciones.add('Sin folio en el ticket.');
    }

    // ── Imagen física vs captura de pantalla ──────────────────────────
    if (datos.tieneImagen) {
      if (datos.imagenEsFisica) {
        score += 8;
        favorables.add('Imagen se comporta como captura física del ticket.');
      } else {
        score -= 18;
        observaciones.add('La imagen no parece una foto física confiable.');
      }
    } else {
      score -= 10;
      observaciones.add('Sin imagen adjunta del ticket.');
    }

    // ── Coherencia volumétrica (del FuelGaugeService) ─────────────────
    if (datos.coherenciaVolumetrica != null) {
      final cv = datos.coherenciaVolumetrica!;
      if (cv >= 90) {
        score += 10;
        favorables.add('Litros coherentes con el cambio de medidor del tanque.');
      } else if (cv >= 70) {
        score += 5;
        favorables.add('Coherencia volumétrica aceptable.');
      } else if (cv < 45) {
        score -= 20;
        observaciones.add('Los litros no coinciden con el cambio del medidor del tanque.');
      }
    }

    // ── Litros dentro del rango del tanque ───────────────────────────
    if (datos.litrosOcr != null && datos.capacidadTanque > 0) {
      if (datos.litrosOcr! > datos.capacidadTanque * 1.05) {
        score -= 35;
        observaciones.add('Los litros exceden la capacidad física del tanque registrado.');
      } else if (datos.litrosOcr! >= datos.capacidadTanque * 0.05) {
        score += 8;
        favorables.add('Litros coherentes con la capacidad del tanque.');
      }
    }

    // ── Coherencia matemática precio × litros = total ────────────────
    if (tieneTicketCompleto) {
      final coherente = _coherenciaMatematica(
        monto: datos.montoOcr!,
        litros: datos.litrosOcr!,
        precio: datos.precioOcrPorLitro!,
      );
      if (coherente) {
        score += 5;
        favorables.add('Precio × litros ≈ total (coherencia matemática verificada).');
      } else {
        score -= 10;
        observaciones.add('Inconsistencia matemática: precio × litros ≠ total del ticket.');
      }
    }

    // ── Captura manual (penalización) ────────────────────────────────
    if (datos.datosManuales) {
      score -= 10;
      observaciones.add('Captura manual: sirve para historial, no para conciliación automática.');
    }

    score = score.clamp(0, 100);

    final nivel = switch (score) {
      >= 85 => NivelEvidencia.fuerte,
      >= 65 => NivelEvidencia.parcial,
      >= 45 => NivelEvidencia.debil,
      _     => NivelEvidencia.inconsistente,
    };

    final aportaAuditoria = datos.imagenEsFisica &&
        !datos.datosManuales &&
        nivel != NivelEvidencia.inconsistente;

    final pesoAuditoria = switch (nivel) {
      NivelEvidencia.fuerte        => aportaAuditoria ? 1.0  : 0.0,
      NivelEvidencia.parcial       => aportaAuditoria ? 0.6  : 0.0,
      NivelEvidencia.debil         => 0.15,
      NivelEvidencia.inconsistente => 0.0,
    };

    return PerfilEvidenciaCosto(
      nivel: nivel,
      score: score,
      aportaAuditoria: aportaAuditoria,
      pesoAuditoria: pesoAuditoria,
      factoresFavorables: favorables,
      observaciones: observaciones,
    );
  }

  static bool _coherenciaMatematica({
    required double monto,
    required double litros,
    required double precio,
    double tolerancia = 0.02,
  }) {
    if (precio <= 0 || litros <= 0) return false;
    final calc = precio * litros;
    return ((calc - monto) / monto).abs() <= tolerancia;
  }
}
