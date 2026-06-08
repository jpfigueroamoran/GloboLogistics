import 'package:equatable/equatable.dart';

enum NivelScore { excelente, bueno, regular, critico }

class OperadorScore extends Equatable {
  final String operadorId;
  final String nombreOperador;
  final int totalViajes;
  final double promedioVarianza;   // 0.0 – 1.0
  final int viajesBanderaRoja;
  final int alertasSOS;
  final double tasaCompletitud;    // 0.0 – 1.0

  const OperadorScore({
    required this.operadorId,
    required this.nombreOperador,
    required this.totalViajes,
    required this.promedioVarianza,
    required this.viajesBanderaRoja,
    required this.alertasSOS,
    required this.tasaCompletitud,
  });

  // ── Score compuesto 0-100 ─────────────────────────────────────────────────
  // 40 % varianza + 30 % SOS-libre + 30 % completitud

  double get scoreVarianza {
    if (promedioVarianza <= 0.015) return 100;
    if (promedioVarianza <= 0.03)  return 80;
    if (promedioVarianza <= 0.05)  return 60;
    if (promedioVarianza <= 0.10)  return 40;
    return 20;
  }

  double get scoreSOS {
    if (totalViajes == 0) return 100;
    final ratio = alertasSOS / totalViajes;
    if (ratio == 0)    return 100;
    if (ratio <= 0.05) return 80;
    if (ratio <= 0.10) return 60;
    return 30;
  }

  double get scoreCompletitud => (tasaCompletitud * 100).clamp(0, 100);

  double get scoreTotal =>
      (scoreVarianza * 0.40 + scoreSOS * 0.30 + scoreCompletitud * 0.30)
          .clamp(0, 100);

  NivelScore get nivel {
    if (scoreTotal >= 85) return NivelScore.excelente;
    if (scoreTotal >= 65) return NivelScore.bueno;
    if (scoreTotal >= 45) return NivelScore.regular;
    return NivelScore.critico;
  }

  @override
  List<Object?> get props => [operadorId, totalViajes, scoreTotal];
}
