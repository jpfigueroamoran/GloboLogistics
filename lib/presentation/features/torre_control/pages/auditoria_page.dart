import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/litro_exacto_panel_widget.dart';

enum _Periodo { hoy, semana, mes, todo }

String _periodoLabel(_Periodo p) => switch (p) {
      _Periodo.hoy    => 'Hoy',
      _Periodo.semana => 'Últimos 7 días',
      _Periodo.mes    => 'Últimos 30 días',
      _Periodo.todo   => 'Todo',
    };

class AuditoriaPage extends ConsumerStatefulWidget {
  const AuditoriaPage({super.key});

  @override
  ConsumerState<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends ConsumerState<AuditoriaPage> {
  _Periodo _periodo = _Periodo.todo;

  bool _enPeriodo(Viaje v) {
    if (_periodo == _Periodo.todo) return true;
    final ref = v.fechaFin ?? v.fechaInicio ?? v.createdAt;
    final ahora = DateTime.now();
    return switch (_periodo) {
      _Periodo.hoy => ref.year == ahora.year &&
          ref.month == ahora.month &&
          ref.day == ahora.day,
      _Periodo.semana =>
        ref.isAfter(ahora.subtract(const Duration(days: 7))),
      _Periodo.mes =>
        ref.isAfter(ahora.subtract(const Duration(days: 30))),
      _Periodo.todo => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viajesSP = ref.watch(viajesActivosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AUDITORÍA LITRO EXACTO',
              style: GloboTypography.labelSmall.copyWith(
                letterSpacing: 2,
                color: GloboColors.textTertiary,
              ),
            ),
            const Text('Conciliación Combustible'),
          ],
        ),
        actions: [
          PopupMenuButton<_Periodo>(
            initialValue: _periodo,
            onSelected: (p) => setState(() => _periodo = p),
            itemBuilder: (_) => _Periodo.values
                .map((p) => PopupMenuItem(
                      value: p,
                      child: Row(children: [
                        if (p == _periodo)
                          const Icon(Icons.check,
                              size: 16, color: GloboColors.primary)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(_periodoLabel(p)),
                      ]),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.md),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.filter_list, size: 16),
                const SizedBox(width: 4),
                Text(_periodoLabel(_periodo),
                    style: GloboTypography.labelLarge),
              ]),
            ),
          ),
          const SizedBox(width: GloboSpacing.md),
        ],
      ),
      body: viajesSP.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (viajes) => _AuditoriaContent(
          viajes: viajes.where(_enPeriodo).toList(),
        ),
      ),
    );
  }
}

class _AuditoriaContent extends StatelessWidget {
  final List<Viaje> viajes;

  const _AuditoriaContent({required this.viajes});

  @override
  Widget build(BuildContext context) {
    final conBandera = viajes.where((v) => v.tieneBanderaRoja).toList();
    final sinBandera = viajes.where((v) => !v.tieneBanderaRoja).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Lista de viajes ──────────────────────────────────────────
        Expanded(
          flex: 3,
          child: Column(
            children: [
              if (conBandera.isNotEmpty)
                _SeccionViajes(
                  titulo: 'Banderas Rojas',
                  icono: Icons.flag,
                  color: GloboColors.error,
                  viajes: conBandera,
                ),
              _SeccionViajes(
                titulo: 'Viajes Conciliados',
                icono: Icons.check_circle_outline,
                color: GloboColors.success,
                viajes: sinBandera,
              ),
            ],
          ),
        ),
        // ── Panel de conciliación ────────────────────────────────────
        Container(
          width: 380,
          color: GloboColors.surface,
          child: const LitroExactoPanelWidget(),
        ),
      ],
    );
  }
}

class _SeccionViajes extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Color color;
  final List<Viaje> viajes;

  const _SeccionViajes({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.viajes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, GloboSpacing.sm),
          child: Row(
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: GloboSpacing.sm),
              Text(titulo,
                  style: GloboTypography.titleMedium
                      .copyWith(color: color)),
              const SizedBox(width: GloboSpacing.sm),
              _Badge(count: viajes.length, color: color),
            ],
          ),
        ),
        ...viajes.map((v) => _ViajeAuditoriaRow(viaje: v)),
        const SizedBox(height: GloboSpacing.sm),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;

  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        '$count',
        style: GloboTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _ViajeAuditoriaRow extends StatelessWidget {
  final Viaje viaje;

  const _ViajeAuditoriaRow({required this.viaje});

  @override
  Widget build(BuildContext context) {
    final varianza = viaje.varianzaCombustible;
    final varianzaStr = varianza != null
        ? '${(varianza * 100).toStringAsFixed(2)} %'
        : 'Sin datos';

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del viaje
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${viaje.origenDescripcion} → ${viaje.destinoDescripcion}',
                    style: GloboTypography.titleMedium,
                  ),
                ),
                if (viaje.tieneBanderaRoja)
                  const Icon(Icons.flag,
                      color: GloboColors.error, size: 18),
              ],
            ),
            const SizedBox(height: GloboSpacing.sm),
            // Métricas de conciliación
            Row(
              children: [
                _MetricCell(
                  label: 'TICKETS OCR',
                  value: '${viaje.litrosConsumiidosTickets.toStringAsFixed(1)} L',
                  color: GloboColors.primaryAccent,
                ),
                _MetricCell(
                  label: 'TELEMETRÍA',
                  value: '${viaje.litrosConsumiidosTelemetria.toStringAsFixed(1)} L',
                  color: GloboColors.steelGray,
                ),
                _MetricCell(
                  label: 'VARIANZA',
                  value: varianzaStr,
                  color: viaje.tieneBanderaRoja
                      ? GloboColors.error
                      : GloboColors.success,
                ),
                _MetricCell(
                  label: 'TCO',
                  value: '\$${viaje.tco.total.toStringAsFixed(0)}',
                  color: GloboColors.textPrimary,
                ),
              ],
            ),
            const SizedBox(height: GloboSpacing.sm),
            // Barra de varianza visual
            if (varianza != null) _VarianzaBar(varianza: varianza),
          ],
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GloboTypography.labelSmall
                  .copyWith(fontSize: 9, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value,
              style: GloboTypography.monoData
                  .copyWith(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _VarianzaBar extends StatelessWidget {
  final double varianza; // 0.0 – 1.0+

  const _VarianzaBar({required this.varianza});

  @override
  Widget build(BuildContext context) {
    // Normalizar a 0–1 con 20% como máximo visual
    final normalized = (varianza.abs() / 0.20).clamp(0.0, 1.0);
    final color = varianza.abs() <= 0.015
        ? GloboColors.success
        : varianza.abs() <= 0.05
            ? GloboColors.warning
            : GloboColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Varianza',
                style: GloboTypography.caption
                    .copyWith(fontSize: 10)),
            const Spacer(),
            _UmbralLabel(
                label: '1.5%',
                passed: varianza.abs() <= 0.015),
            const SizedBox(width: 8),
            _UmbralLabel(
                label: '5%', passed: varianza.abs() <= 0.05),
            const SizedBox(width: 8),
            _UmbralLabel(
                label: '15%',
                passed: varianza.abs() <= 0.15),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.all(Radius.circular(3)),
              ),
            ),
            FractionallySizedBox(
              widthFactor: normalized,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
            // Línea umbral 1.5 %
            Positioned(
              left: MediaQuery.of(context).size.width * (0.015 / 0.20) * 0.5,
              child: Container(
                  width: 1, height: 6, color: GloboColors.divider),
            ),
          ],
        ),
      ],
    );
  }
}

class _UmbralLabel extends StatelessWidget {
  final String label;
  final bool passed;

  const _UmbralLabel({required this.label, required this.passed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: passed
            ? GloboColors.successLight
            : GloboColors.errorLight,
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
      child: Text(
        label,
        style: GloboTypography.labelSmall.copyWith(
          fontSize: 9,
          color: passed ? GloboColors.success : GloboColors.error,
        ),
      ),
    );
  }
}
