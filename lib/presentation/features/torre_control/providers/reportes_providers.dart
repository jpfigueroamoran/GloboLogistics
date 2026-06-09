import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/factura_proveedor.dart';
import 'factura_proveedor_provider.dart';
import 'dashboard_provider.dart';

// ── 1. Proveedor de Distribución de Gastos ──────────────────────────────────
class GastoCategoria {
  final TipoProveedor tipo;
  final double montoTotal;
  final double porcentaje;

  GastoCategoria(this.tipo, this.montoTotal, this.porcentaje);
}

final distribucionGastosProvider = Provider<List<GastoCategoria>>((ref) {
  final facturas = ref.watch(facturasProveedorProvider).valueOrNull ?? [];
  
  // Usar todas las facturas del mes actual, o todas en general para demo
  double total = 0;
  final map = <TipoProveedor, double>{};
  
  for (final f in facturas) {
    total += f.monto;
    map[f.tipoProveedor] = (map[f.tipoProveedor] ?? 0) + f.monto;
  }

  if (total == 0) return [];

  final list = map.entries.map((e) {
    return GastoCategoria(e.key, e.value, (e.value / total) * 100);
  }).toList();

  list.sort((a, b) => b.montoTotal.compareTo(a.montoTotal));
  return list;
});

// ── 2. Proveedor de Tendencia de Viajes (Últimos 6 meses) ───────────────────
class MesTendencia {
  final int mes; // 1-12
  final String nombreMes;
  final int aTiempo;
  final int conIncidencia;

  MesTendencia(this.mes, this.nombreMes, this.aTiempo, this.conIncidencia);
}

final tendenciaViajesProvider = Provider<List<MesTendencia>>((ref) {
  final activos     = ref.watch(viajesActivosProvider).valueOrNull ?? [];
  final completados = ref.watch(viajesCompletadosProvider).valueOrNull ?? [];

  final todos = [...activos, ...completados];

  final ahora = DateTime.now();
  const nombresMeses = ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  // Build ordered list of last 6 (year, month) keys
  final meses = <(int, int)>[];
  for (int i = 5; i >= 0; i--) {
    var m = ahora.month - i;
    var y = ahora.year;
    if (m <= 0) { m += 12; y--; }
    meses.add((y, m));
  }

  return meses.map((ym) {
    final (year, mes) = ym;
    final viajesMes = todos.where((v) {
      final d = v.createdAt;
      return d.year == year && d.month == mes;
    }).toList();

    final incidencias = viajesMes.where((v) => v.tieneBanderaRoja).length;
    return MesTendencia(mes, nombresMeses[mes], viajesMes.length - incidencias, incidencias);
  }).toList();
});

// ── 3. Proveedor de Evolución de Score Global ───────────────────────────────
class ScoreMes {
  final int mes;
  final double score;
  ScoreMes(this.mes, this.score);
}

final evolucionScoreProvider = Provider<List<ScoreMes>>((ref) {
  final tendencias = ref.watch(tendenciaViajesProvider);
  
  // Fórmula de Score basada en el ratio de incidencias
  return tendencias.map((t) {
    final total = t.aTiempo + t.conIncidencia;
    double score = 100.0;
    if (total > 0) {
      final penalizacion = (t.conIncidencia / total) * 40; // Max penalización 40 pts
      score = 100.0 - penalizacion;
    } else {
      score = 85.0; // Valor base si no hay viajes
    }
    return ScoreMes(t.mes, score);
  }).toList();
});
