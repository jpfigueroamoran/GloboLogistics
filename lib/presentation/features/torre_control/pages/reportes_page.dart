import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../core/utils/pdf_report_generator.dart';
import '../../../../domain/entities/factura_proveedor.dart';
import '../providers/reportes_providers.dart';

class ReportesPage extends ConsumerWidget {
  const ReportesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header + botón PDF ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analítica de Operaciones',
                      style: GloboTypography.headlineMedium),
                  Text(
                    'KPIs y exportación de reportes ejecutivos',
                    style: GloboTypography.bodyLarge
                        .copyWith(color: GloboColors.textSecondary),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _exportarPDF(context),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exportar Reporte (PDF)'),
                style: FilledButton.styleFrom(
                  backgroundColor: GloboColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: GloboSpacing.xl),

          // ── Fila de gráficas ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _ViajesTendenciaChart()),
              const SizedBox(width: GloboSpacing.lg),
              Expanded(flex: 1, child: _GastosDistribucionChart()),
            ],
          ),
          const SizedBox(height: GloboSpacing.lg),

          // ── Score de operadores ───────────────────────────────
          const _OperadoresScoreChart(),
        ],
      ),
    );
  }

  void _exportarPDF(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando reporte PDF…'),
        duration: Duration(seconds: 1),
      ),
    );
    await PdfReportGenerator.generateAndPrint();
  }
}

// ── Gráfico 1: Tendencia de Viajes ───────────────────────────────────────────

class _ViajesTendenciaChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tendencias = ref.watch(tendenciaViajesProvider);

    if (tendencias.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tendencia de Viajes (Últimos 6 meses)',
                style: GloboTypography.titleMedium),
            const SizedBox(height: GloboSpacing.lg),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 120,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = [
                            'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'
                          ];
                          final i = value.toInt();
                          if (i < 0 || i >= tendencias.length) {
                            return const SizedBox();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              i < labels.length
                                  ? labels[i]
                                  : tendencias[i].nombreMes,
                              style: const TextStyle(
                                  color: GloboColors.textSecondary,
                                  fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 36),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(
                      show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: tendencias.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.aTiempo.toDouble(),
                          color: GloboColors.primary,
                          width: 14,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: e.value.conIncidencia.toDouble(),
                          color: GloboColors.error,
                          width: 14,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: GloboSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: GloboColors.primary, text: 'A Tiempo'),
                const SizedBox(width: GloboSpacing.lg),
                _LegendItem(
                    color: GloboColors.error, text: 'Con Incidencia'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gráfico 2: Distribución de Gastos ────────────────────────────────────────

class _GastosDistribucionChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gastos = ref.watch(distribucionGastosProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distribución de Gastos (Mes Actual)',
                style: GloboTypography.titleMedium),
            const SizedBox(height: GloboSpacing.lg),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: gastos.isEmpty
                      ? [
                          PieChartSectionData(
                            color: GloboColors.divider,
                            value: 100,
                            title: '0%',
                            radius: 50,
                          ),
                        ]
                      : gastos
                          .map((g) => PieChartSectionData(
                                color: _colorPorTipo(g.tipo),
                                value: g.porcentaje,
                                title:
                                    '${g.porcentaje.toStringAsFixed(0)}%',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ))
                          .toList(),
                ),
              ),
            ),
            const SizedBox(height: GloboSpacing.md),
            if (gastos.isEmpty)
              const Text('Sin datos de gastos este mes.')
            else
              ...gastos.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _LegendItem(
                    color: _colorPorTipo(g.tipo),
                    text:
                        '${g.tipo.label}  \$${(g.montoTotal / 1000).toStringAsFixed(1)}k',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _colorPorTipo(TipoProveedor tipo) => switch (tipo) {
      TipoProveedor.combustible   => const Color(0xFF1976D2),
      TipoProveedor.mantenimiento => const Color(0xFFE53935),
      TipoProveedor.llantas       => const Color(0xFFFBC02D),
      TipoProveedor.refacciones   => const Color(0xFF43A047),
      TipoProveedor.seguro        => const Color(0xFF8E24AA),
      TipoProveedor.otro          => const Color(0xFF757575),
    };

// ── Gráfico 3: Evolución del Score de Operadores ──────────────────────────────

class _OperadoresScoreChart extends ConsumerWidget {
  const _OperadoresScoreChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(evolucionScoreProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evolución del Score de Operadores',
                style: GloboTypography.titleMedium),
            const SizedBox(height: GloboSpacing.lg),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                      show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const labels = [
                            'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun'
                          ];
                          final i = value.toInt();
                          if (i < 0 || i >= labels.length) {
                            return const SizedBox();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              labels[i],
                              style: const TextStyle(
                                  color: GloboColors.textSecondary,
                                  fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: true, reservedSize: 36),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 60,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: scores
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value.score))
                          .toList(),
                      isCurved: true,
                      color: GloboColors.successAccent,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: GloboColors.successAccent.withAlpha(40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared: Leyenda ───────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(text, style: GloboTypography.caption),
      ],
    );
  }
}
