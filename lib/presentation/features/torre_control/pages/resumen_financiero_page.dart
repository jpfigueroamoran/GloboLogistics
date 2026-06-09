import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/factura_cliente.dart'; // BucketAging
import '../providers/cxc_aging_provider.dart';
import '../providers/factura_cliente_provider.dart';
import '../providers/factura_proveedor_provider.dart';
import '../providers/resumen_financiero_provider.dart';

class ResumenFinancieroPage extends ConsumerWidget {
  const ResumenFinancieroPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt       = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final fmtCompact = NumberFormat.compactCurrency(locale: 'es_MX', symbol: '\$');
    final ingresos  = ref.watch(ingresosCobradosMesProvider);
    final gastos    = ref.watch(gastosPagadosMesProvider);
    final flujoNeto = ingresos - gastos;
    final cxcTotal  = ref.watch(cxcTotalPendienteProvider);
    final cxpTotal  = ref.watch(cxpTotalPendienteProvider);
    final margenPct = ingresos > 0 ? ((ingresos - gastos) / ingresos * 100) : 0.0;
    final tco       = ref.watch(tcoDesgloseProvider);
    final aging     = ref.watch(cxcAgingProvider);
    final resumen   = ref.watch(resumenMensualProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Strip ─────────────────────────────────────────────────────
          _SectionTitle('Métricas del Mes en Curso'),
          const SizedBox(height: GloboSpacing.sm),
          Row(children: [
            _KpiTile(label: 'Ingresos Cobrados',  value: fmt.format(ingresos),     icon: Icons.trending_up,        color: GloboColors.successAccent),
            const SizedBox(width: GloboSpacing.md),
            _KpiTile(label: 'Gastos Pagados',     value: fmt.format(gastos),       icon: Icons.trending_down,      color: GloboColors.error),
            const SizedBox(width: GloboSpacing.md),
            _KpiTile(label: 'Flujo Neto',         value: fmt.format(flujoNeto),    icon: Icons.account_balance,    color: flujoNeto >= 0 ? GloboColors.successAccent : GloboColors.error),
          ]),
          const SizedBox(height: GloboSpacing.sm),
          Row(children: [
            _KpiTile(label: 'CxC Pendiente',      value: fmtCompact.format(cxcTotal), icon: Icons.receipt_long_outlined,   color: GloboColors.warning),
            const SizedBox(width: GloboSpacing.md),
            _KpiTile(label: 'CxP Pendiente',      value: fmtCompact.format(cxpTotal), icon: Icons.payment_outlined,        color: GloboColors.error),
            const SizedBox(width: GloboSpacing.md),
            _KpiTile(label: 'Margen Bruto',       value: '${margenPct.toStringAsFixed(1)}%', icon: Icons.percent, color: margenPct >= 15 ? GloboColors.successAccent : GloboColors.warning),
          ]),

          const SizedBox(height: GloboSpacing.xl),

          // ── Charts row ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: TCO Donut
              Expanded(
                child: _ChartCard(
                  title: 'Desglose TCO Flota (Viajes Completados)',
                  height: 260,
                  child: tco.total == 0
                      ? const Center(child: Text('Sin datos de viajes completados.'))
                      : Row(children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sections: _tcoSections(tco),
                                centerSpaceRadius: 50,
                                sectionsSpace: 2,
                              ),
                            ),
                          ),
                          const SizedBox(width: GloboSpacing.md),
                          _TcoLegend(tco: tco, fmt: fmt),
                        ]),
                ),
              ),
              const SizedBox(width: GloboSpacing.lg),
              // Right: CxC Aging
              Expanded(
                child: _ChartCard(
                  title: 'Antigüedad CxC por Bucket',
                  height: 260,
                  child: aging.values.every((v) => v == 0)
                      ? const Center(child: Text('Sin CxC pendiente.'))
                      : BarChart(_agingBarData(aging, fmtCompact)),
                ),
              ),
            ],
          ),

          const SizedBox(height: GloboSpacing.lg),

          // ── Trend line chart ──────────────────────────────────────────────
          _ChartCard(
            title: 'Tendencia — Ingresos vs. Gastos (últimos 5 meses)',
            height: 220,
            child: resumen.isEmpty
                ? const Center(child: Text('Sin datos de tendencia.'))
                : Stack(children: [
                    LineChart(_trendLineData(resumen)),
                    Positioned(
                      top: 0, right: 0,
                      child: Row(children: [
                        _LegendDot(color: GloboColors.successAccent, label: 'Ingresos'),
                        const SizedBox(width: GloboSpacing.md),
                        _LegendDot(color: GloboColors.error, label: 'Gastos'),
                      ]),
                    ),
                  ]),
          ),
        ],
      ),
    );
  }

  static List<PieChartSectionData> _tcoSections(TcoDesglose tco) {
    const r = 60.0;
    return [
      if (tco.combustible > 0)
        PieChartSectionData(value: tco.combustible,   color: const Color(0xFF2196F3), title: '', radius: r),
      if (tco.mantenimiento > 0)
        PieChartSectionData(value: tco.mantenimiento, color: const Color(0xFF4CAF50), title: '', radius: r),
      if (tco.peajes > 0)
        PieChartSectionData(value: tco.peajes,        color: const Color(0xFFFF9800), title: '', radius: r),
      if (tco.otros > 0)
        PieChartSectionData(value: tco.otros,         color: const Color(0xFF9E9E9E), title: '', radius: r),
    ];
  }

  static BarChartData _agingBarData(
      Map<BucketAging, double> aging, NumberFormat fmt) {
    const labels = ['Cte', '1-30d', '31-60d', '61-90d', '+90d'];
    const colors = [
      Color(0xFF4CAF50), Color(0xFFFFB300), Color(0xFFFF7043),
      Color(0xFFE53935), Color(0xFF7B1FA2),
    ];
    final buckets = BucketAging.values;
    final maxVal  = aging.values.reduce((a, b) => a > b ? a : b);

    return BarChartData(
      maxY: maxVal > 0 ? maxVal * 1.2 : 100,
      barGroups: List.generate(buckets.length, (i) {
        final val = aging[buckets[i]] ?? 0;
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: colors[i],
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, _) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                labels[v.toInt()],
                style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
              ),
            ),
          ),
        ),
        leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: false),
    );
  }

  static LineChartData _trendLineData(List<ResumenMensual> resumen) {
    final ingresoSpots = resumen.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.ingresos / 1000))
        .toList();
    final gastosSpots = resumen.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.gastos / 1000))
        .toList();

    final allY   = [...ingresoSpots, ...gastosSpots].map((s) => s.y).toList();
    final maxY   = allY.isEmpty ? 100.0 : (allY.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();

    return LineChartData(
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: ingresoSpots,
          isCurved: true,
          color: GloboColors.successAccent,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: GloboColors.successAccent.withAlpha(25),
          ),
        ),
        LineChartBarData(
          spots: gastosSpots,
          isCurved: true,
          color: GloboColors.error,
          barWidth: 2,
          dashArray: [6, 3],
          dotData: const FlDotData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= resumen.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  resumen[i].etiqueta,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                ),
              );
            },
          ),
        ),
        leftTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            getTitlesWidget: (v, _) => Text(
              '\$${v.toStringAsFixed(0)}k',
              style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
            ),
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: Color(0x15000000), strokeWidth: 0.8),
      ),
      borderData: FlBorderData(show: false),
    );
  }
}

// ── Widgets de soporte ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GloboTypography.labelSmall.copyWith(
        letterSpacing: 1.5,
        color: GloboColors.textTertiary,
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(GloboSpacing.md),
        decoration: BoxDecoration(
          color: GloboColors.surface,
          borderRadius: GloboRadius.cardRadius,
          border: Border.all(color: GloboColors.divider),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: GloboRadius.buttonRadius,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: GloboSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,  style: GloboTypography.labelSmall),
                Text(value,  style: GloboTypography.titleMedium.copyWith(color: color)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final double height;
  final Widget child;
  const _ChartCard({required this.title, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GloboSpacing.md),
      decoration: BoxDecoration(
        color: GloboColors.surface,
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(color: GloboColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GloboTypography.titleMedium),
          const SizedBox(height: GloboSpacing.md),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

class _TcoLegend extends StatelessWidget {
  final TcoDesglose tco;
  final NumberFormat fmt;
  const _TcoLegend({required this.tco, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final items = [
      (const Color(0xFF2196F3), 'Combustible',   tco.combustible),
      (const Color(0xFF4CAF50), 'Mantenimiento', tco.mantenimiento),
      (const Color(0xFFFF9800), 'Peajes',         tco.peajes),
      (const Color(0xFF9E9E9E), 'Otros',          tco.otros),
    ].where((e) => e.$3 > 0).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: e.$1, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.$2, style: GloboTypography.caption),
            Text(fmt.format(e.$3),
                style: GloboTypography.monoData.copyWith(fontSize: 11)),
          ]),
        ]),
      )).toList(),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: GloboTypography.caption),
    ]);
  }
}
