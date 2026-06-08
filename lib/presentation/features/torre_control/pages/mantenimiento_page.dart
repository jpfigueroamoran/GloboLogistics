import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/mantenimiento.dart';
import '../providers/mantenimiento_provider.dart';

class MantenimientoPage extends ConsumerWidget {
  const MantenimientoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mantenimientos = ref.watch(mantenimientosProvider);
    final criticos       = ref.watch(mantenimientosCriticosProvider);

    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(total: mantenimientos.length, criticos: criticos),
          const SizedBox(height: GloboSpacing.md),
          Expanded(
            child: mantenimientos.isEmpty
                ? const Center(child: Text('Sin unidades registradas'))
                : _MantenimientoGrid(mantenimientos: mantenimientos),
          ),
        ],
      ),
    );
  }
}

// ── Encabezado ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int total;
  final int criticos;
  const _Header({required this.total, required this.criticos});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mantenimiento Predictivo',
                  style: GloboTypography.headlineMedium),
              Text('$total unidades · $criticos críticas',
                  style: GloboTypography.bodyMedium),
            ],
          ),
        ),
        if (criticos > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
            decoration: BoxDecoration(
              color: GloboColors.errorLight,
              borderRadius: GloboRadius.cardRadius,
              border: Border.all(color: GloboColors.error.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_rounded,
                    size: 18, color: GloboColors.error),
                const SizedBox(width: GloboSpacing.sm),
                Text(
                  '$criticos unidades requieren servicio',
                  style: GloboTypography.labelLarge
                      .copyWith(color: GloboColors.error),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Grid de tarjetas de mantenimiento ────────────────────────────────────────

class _MantenimientoGrid extends StatelessWidget {
  final List<MantenimientoPrevisto> mantenimientos;
  const _MantenimientoGrid({required this.mantenimientos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 380,
        mainAxisExtent: 220,
        crossAxisSpacing: GloboSpacing.md,
        mainAxisSpacing: GloboSpacing.md,
      ),
      itemCount: mantenimientos.length,
      itemBuilder: (_, i) =>
          _MantenimientoCard(item: mantenimientos[i]),
    );
  }
}

class _MantenimientoCard extends StatelessWidget {
  final MantenimientoPrevisto item;
  const _MantenimientoCard({required this.item});

  Color get _urgenciaColor {
    if (item.nivelUrgencia >= 0.8) return GloboColors.error;
    if (item.nivelUrgencia >= 0.5) return GloboColors.warningAccent;
    return GloboColors.successAccent;
  }

  String get _estadoLabel => switch (item.estado) {
        EstadoMantenimiento.pendiente   => 'Pendiente',
        EstadoMantenimiento.programado  => 'Programado',
        EstadoMantenimiento.enProceso   => 'En proceso',
        EstadoMantenimiento.completado  => 'Completado',
      };

  String get _tipoLabel => switch (item.tipo) {
        TipoMantenimiento.preventivo  => 'Preventivo',
        TipoMantenimiento.correctivo  => 'Correctivo',
        TipoMantenimiento.inspeccion  => 'Inspección',
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(
          color: item.esCritico
              ? GloboColors.error.withAlpha(120)
              : GloboColors.divider,
          width: item.esCritico ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.placas,
                          style: GloboTypography.titleLarge),
                      Text(item.modeloUnidad,
                          style: GloboTypography.caption),
                    ],
                  ),
                ),
                _TipoChip(label: _tipoLabel, color: _urgenciaColor),
              ],
            ),
            const SizedBox(height: GloboSpacing.sm),
            const Divider(height: GloboSpacing.md),
            _OdometroRow(item: item),
            const SizedBox(height: GloboSpacing.sm),
            // Barra de progreso hacia el próximo servicio
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.kmRestantes <= 0
                    ? 1.0
                    : (item.odometroActual % 20000) / 20000,
                minHeight: 8,
                backgroundColor: _urgenciaColor.withAlpha(25),
                valueColor:
                    AlwaysStoppedAnimation<Color>(_urgenciaColor),
              ),
            ),
            const SizedBox(height: GloboSpacing.sm),
            Text(
              item.descripcion,
              style: GloboTypography.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _estadoLabel,
                  style: GloboTypography.labelSmall
                      .copyWith(color: _urgenciaColor),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {},
                  child: const Text('Programar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TipoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TipoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: GloboRadius.chipRadius,
      ),
      child: Text(
        label,
        style: GloboTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _OdometroRow extends StatelessWidget {
  final MantenimientoPrevisto item;
  const _OdometroRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final restantes = item.kmRestantes;
    final label = restantes <= 0
        ? 'VENCIDO por ${-restantes} km'
        : '$restantes km para próximo servicio';

    return Row(
      children: [
        const Icon(Icons.speed_outlined, size: 16, color: GloboColors.steelGray),
        const SizedBox(width: 4),
        Text(
          '${item.odometroActual} km',
          style: GloboTypography.monoData.copyWith(fontSize: 12),
        ),
        const Spacer(),
        Text(
          label,
          style: GloboTypography.caption.copyWith(
            color: restantes <= 0
                ? GloboColors.error
                : GloboColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
