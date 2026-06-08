import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';

class HistorialViajesPage extends ConsumerStatefulWidget {
  const HistorialViajesPage({super.key});

  @override
  ConsumerState<HistorialViajesPage> createState() => _HistorialViajesPageState();
}

class _HistorialViajesPageState extends ConsumerState<HistorialViajesPage> {
  String _filtroOperador = 'Todos';
  String _filtroUnidad = 'Todas';

  @override
  Widget build(BuildContext context) {
    final viajesSP = ref.watch(viajesCompletadosProvider);

    return Scaffold(
      backgroundColor: GloboColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: GloboColors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HISTORIAL Y TCO',
              style: GloboTypography.labelSmall.copyWith(
                letterSpacing: 2,
                color: GloboColors.textTertiary,
              ),
            ),
            const Text('Auditoría Retrospectiva y Detección de Fugas'),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Exportar CSV'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generando reporte CSV...')),
              );
            },
          ),
          const SizedBox(width: GloboSpacing.md),
        ],
      ),
      body: viajesSP.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (viajes) {
          if (viajes.isEmpty) {
            return const Center(child: Text('No hay viajes completados.'));
          }

          // Aplicar filtros
          var filtrados = viajes;
          if (_filtroOperador != 'Todos') {
            filtrados = filtrados.where((v) => v.operadorId == _filtroOperador).toList();
          }
          if (_filtroUnidad != 'Todas') {
            filtrados = filtrados.where((v) => v.unidadId == _filtroUnidad).toList();
          }

          return Column(
            children: [
              _TopOffendersPanel(viajes: viajes),
              _FiltrosPanel(
                viajes: viajes,
                operadorSeleccionado: _filtroOperador,
                unidadSeleccionada: _filtroUnidad,
                onOperadorChanged: (val) => setState(() => _filtroOperador = val!),
                onUnidadChanged: (val) => setState(() => _filtroUnidad = val!),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(GloboSpacing.md),
                  itemCount: filtrados.length,
                  itemBuilder: (ctx, i) => _HistorialRow(viaje: filtrados[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Top Offenders Panel ───────────────────────────────────────────────────────

class _TopOffendersPanel extends StatelessWidget {
  final List<Viaje> viajes;

  const _TopOffendersPanel({required this.viajes});

  @override
  Widget build(BuildContext context) {
    if (viajes.isEmpty) return const SizedBox.shrink();

    // Calcular la ruta con más fuga (mayor varianza promedio)
    final rutas = <String, List<double>>{};
    for (var v in viajes) {
      if (v.varianzaCombustible != null) {
        final key = '${v.origenDescripcion} - ${v.destinoDescripcion}';
        rutas.putIfAbsent(key, () => []).add(v.varianzaCombustible!);
      }
    }

    String rutaMasFuga = 'N/A';
    double maxVarianzaRuta = 0.0;
    rutas.forEach((ruta, varianzas) {
      final prom = varianzas.reduce((a, b) => a + b) / varianzas.length;
      if (prom > maxVarianzaRuta) {
        maxVarianzaRuta = prom;
        rutaMasFuga = ruta;
      }
    });

    // Unidad con peor rendimiento km/L
    // distanciaKm ≈ litrosTelemetria × 3.5 (rendimiento base flota — mismo factor que CF recalcularTco)
    final rendPorUnidad = <String, List<double>>{};
    for (final v in viajes) {
      if (v.litrosCargados > 0 && v.litrosConsumiidosTelemetria > 0) {
        final km = v.litrosConsumiidosTelemetria * 3.5;
        rendPorUnidad.putIfAbsent(v.unidadId, () => []).add(km / v.litrosCargados);
      }
    }
    String peorUnidad = 'Sin datos';
    String peorRendStr = '—';
    if (rendPorUnidad.isNotEmpty) {
      double minRend = double.infinity;
      rendPorUnidad.forEach((uid, rends) {
        final prom = rends.reduce((a, b) => a + b) / rends.length;
        if (prom < minRend) {
          minRend = prom;
          peorUnidad = uid;
        }
      });
      if (minRend.isFinite) peorRendStr = '${minRend.toStringAsFixed(1)} Km/L';
    }

    return Container(
      padding: const EdgeInsets.all(GloboSpacing.md),
      margin: const EdgeInsets.all(GloboSpacing.md),
      decoration: BoxDecoration(
        color: GloboColors.surface,
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(color: GloboColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: GloboColors.warning),
              const SizedBox(width: GloboSpacing.sm),
              Text('Top Offenders (Áreas de Oportunidad)', style: GloboTypography.titleMedium),
            ],
          ),
          const SizedBox(height: GloboSpacing.md),
          Row(
            children: [
              Expanded(
                child: _OffenderCard(
                  titulo: 'Ruta con Mayor Fuga Promedio',
                  valor: rutaMasFuga,
                  metrica: '${(maxVarianzaRuta * 100).toStringAsFixed(1)}% Varianza',
                  color: GloboColors.warning,
                ),
              ),
              const SizedBox(width: GloboSpacing.md),
              Expanded(
                child: _OffenderCard(
                  titulo: 'Unidad con Peor Rendimiento',
                  valor: peorUnidad,
                  metrica: peorRendStr,
                  color: GloboColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OffenderCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String metrica;
  final Color color;

  const _OffenderCard({
    required this.titulo,
    required this.valor,
    required this.metrica,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GloboSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: GloboTypography.labelSmall),
          const SizedBox(height: 4),
          Text(valor, style: GloboTypography.titleMedium, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(metrica, style: GloboTypography.labelLarge.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Filtros Panel ─────────────────────────────────────────────────────────────

class _FiltrosPanel extends StatelessWidget {
  final List<Viaje> viajes;
  final String operadorSeleccionado;
  final String unidadSeleccionada;
  final ValueChanged<String?> onOperadorChanged;
  final ValueChanged<String?> onUnidadChanged;

  const _FiltrosPanel({
    required this.viajes,
    required this.operadorSeleccionado,
    required this.unidadSeleccionada,
    required this.onOperadorChanged,
    required this.onUnidadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final operadores = ['Todos', ...viajes.map((v) => v.operadorId).toSet()];
    final unidades = ['Todas', ...viajes.map((v) => v.unidadId).toSet()];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18, color: GloboColors.textTertiary),
          const SizedBox(width: GloboSpacing.sm),
          const Text('Filtros: ', style: GloboTypography.bodyMedium),
          const SizedBox(width: GloboSpacing.md),
          DropdownButton<String>(
            value: operadorSeleccionado,
            items: operadores.map((op) => DropdownMenuItem(value: op, child: Text(op == 'Todos' ? 'Todos los Operadores' : op))).toList(),
            onChanged: onOperadorChanged,
            underline: const SizedBox(),
          ),
          const SizedBox(width: GloboSpacing.lg),
          DropdownButton<String>(
            value: unidadSeleccionada,
            items: unidades.map((u) => DropdownMenuItem(value: u, child: Text(u == 'Todas' ? 'Todas las Unidades' : u))).toList(),
            onChanged: onUnidadChanged,
            underline: const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ── Fila de Historial ─────────────────────────────────────────────────────────

class _HistorialRow extends StatelessWidget {
  final Viaje viaje;

  const _HistorialRow({required this.viaje});

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy, HH:mm');
    final finStr = viaje.fechaFin != null ? format.format(viaje.fechaFin!) : 'N/A';
    
    // Km estimado: litrosTelemetria × 3.5 km/L base (mismo factor que CF recalcularTco)
    final litros = viaje.litrosCargados;
    final kmEstimado = viaje.litrosConsumiidosTelemetria > 0
        ? viaje.litrosConsumiidosTelemetria * 3.5
        : 0.0;
    final rendimiento = (litros > 0 && kmEstimado > 0)
        ? (kmEstimado / litros).toStringAsFixed(1)
        : 'N/A';
    
    final varianza = viaje.varianzaCombustible;
    final varianzaStr = varianza != null ? '${(varianza * 100).toStringAsFixed(1)}%' : 'N/A';
    final isAlerta = varianza != null && varianza > 0.05;

    return Card(
      margin: const EdgeInsets.only(bottom: GloboSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(viaje.id, style: GloboTypography.labelSmall),
                      Text('${viaje.origenDescripcion} → ${viaje.destinoDescripcion}', style: GloboTypography.titleMedium),
                      Text(finStr, style: GloboTypography.caption),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Operador', style: GloboTypography.labelSmall),
                      Text(viaje.operadorId, style: GloboTypography.bodyMedium),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unidad', style: GloboTypography.labelSmall),
                      Text(viaje.unidadId, style: GloboTypography.bodyMedium),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rendimiento', style: GloboTypography.labelSmall),
                      Text('$rendimiento Km/L', style: GloboTypography.monoData),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Varianza', style: GloboTypography.labelSmall),
                      Text(
                        varianzaStr,
                        style: GloboTypography.monoData.copyWith(
                          color: isAlerta ? GloboColors.error : GloboColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TCO Final', style: GloboTypography.labelSmall),
                      Text('\$${viaje.tco.total.toStringAsFixed(2)}', style: GloboTypography.titleLarge),
                    ],
                  ),
                ),
              ],
            ),
            if (viaje.justificacionVarianza != null && viaje.justificacionVarianza!.isNotEmpty) ...[
              const SizedBox(height: GloboSpacing.sm),
              const Divider(),
              const SizedBox(height: GloboSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 16, color: GloboColors.info),
                  const SizedBox(width: GloboSpacing.sm),
                  Expanded(
                    child: Text(
                      'Justificación del Operador: ${viaje.justificacionVarianza}',
                      style: GloboTypography.bodyMedium.copyWith(color: GloboColors.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
