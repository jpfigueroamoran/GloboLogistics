import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/dashboard_provider.dart';

class TcoPanelWidget extends ConsumerWidget {
  const TcoPanelWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viajesSP = ref.watch(viajesActivosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanelHeader(),
        Expanded(
          child: viajesSP.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(e.toString())),
            data: (viajes) => _TcoContent(viajes: viajes),
          ),
        ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: GloboColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              size: 18, color: GloboColors.primary),
          const SizedBox(width: GloboSpacing.sm),
          Text('TCO por Viaje',
              style: GloboTypography.titleMedium),
          const Spacer(),
          Text('Hoy',
              style: GloboTypography.caption
                  .copyWith(color: GloboColors.textTertiary)),
        ],
      ),
    );
  }
}

class _TcoContent extends StatelessWidget {
  final List<Viaje> viajes;

  const _TcoContent({required this.viajes});

  @override
  Widget build(BuildContext context) {
    if (viajes.isEmpty) {
      return const Center(
        child: Text('Sin datos de TCO'),
      );
    }

    // Calcula totales agregados
    double totalCombustible = 0;
    double totalMantenimiento = 0;
    double totalPeajes = 0;
    double totalOtros = 0;

    for (final v in viajes) {
      totalCombustible += v.tco.combustible;
      totalMantenimiento += v.tco.mantenimiento;
      totalPeajes += v.tco.peajes;
      totalOtros += v.tco.otros;
    }

    final grandTotal =
        totalCombustible + totalMantenimiento + totalPeajes + totalOtros;

    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        children: [
          // Gráfica de pastel
          SizedBox(
            height: 120,
            child: grandTotal == 0
                ? const Center(child: Text('Sin costos registrados'))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        if (totalCombustible > 0)
                          _pieSec(totalCombustible, grandTotal,
                              GloboColors.primaryAccent, 'Diésel'),
                        if (totalMantenimiento > 0)
                          _pieSec(totalMantenimiento, grandTotal,
                              GloboColors.warning, 'Mant.'),
                        if (totalPeajes > 0)
                          _pieSec(totalPeajes, grandTotal,
                              GloboColors.steelGray, 'Peajes'),
                        if (totalOtros > 0)
                          _pieSec(totalOtros, grandTotal,
                              GloboColors.steelGrayLight, 'Otros'),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: GloboSpacing.sm),

          // Leyenda
          _LegendRow(
              color: GloboColors.primaryAccent,
              label: 'Combustible',
              monto: totalCombustible),
          _LegendRow(
              color: GloboColors.warning,
              label: 'Mantenimiento',
              monto: totalMantenimiento),
          _LegendRow(
              color: GloboColors.steelGray,
              label: 'Peajes',
              monto: totalPeajes),

          const Divider(height: GloboSpacing.md),
          Row(
            children: [
              Text('TOTAL',
                  style: GloboTypography.labelLarge),
              const Spacer(),
              Text(
                '\$${grandTotal.toStringAsFixed(0)} MXN',
                style: GloboTypography.headlineMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSec(
      double val, double total, Color color, String title) {
    final pct = (val / total) * 100;
    return PieChartSectionData(
      color: color,
      value: val,
      title: '${pct.toStringAsFixed(0)}%',
      radius: 40,
      titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double monto;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.monto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
          const SizedBox(width: GloboSpacing.sm),
          Text(label, style: GloboTypography.bodyMedium),
          const Spacer(),
          Text(
            '\$${monto.toStringAsFixed(0)}',
            style: GloboTypography.monoData
                .copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
