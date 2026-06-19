import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../demo/demo_providers.dart' show appModeProvider;
import '../../../../domain/entities/mantenimiento.dart';
import '../../../../injection_container.dart';
import '../providers/mantenimiento_provider.dart';
import '../providers/unidades_provider.dart';

class MantenimientoPage extends ConsumerWidget {
  const MantenimientoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unidadesAsync  = ref.watch(unidadesActivasProvider);
    final mantenimientos = ref.watch(mantenimientosProvider);
    final criticos       = ref.watch(mantenimientosCriticosProvider);

    if (unidadesAsync.isLoading) return const _MantenimientoShimmer();

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

  /// Registra el servicio realizado: la unidad vuelve a estar activa y se
  /// fija el odómetro del próximo servicio. Cierra el ciclo de mantenimiento.
  Future<void> _registrarServicio(BuildContext context, WidgetRef ref) async {
    if (ref.read(appModeProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('El registro de servicio es en modo producción'),
      ));
      return;
    }
    final fmt = NumberFormat.decimalPattern('es_MX');
    final sugerido = item.odometroActual + 20000;
    final ctrl = TextEditingController(text: '$sugerido');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Registrar servicio · ${item.placas}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Odómetro actual: ${fmt.format(item.odometroActual)} km',
                style: GloboTypography.caption),
            const SizedBox(height: GloboSpacing.md),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Próximo servicio (odómetro km)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: GloboColors.success,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Marcar atendida'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final proximo = double.tryParse(ctrl.text.trim()) ?? sugerido.toDouble();
    try {
      await sl<FirestoreDatasource>().actualizarUnidad(item.unidadId, {
        'estado': 'activa',
        'proximo_mantenimiento_odometro': proximo,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${item.placas} lista — próximo servicio a '
            '${fmt.format(proximo.round())} km'),
        backgroundColor: GloboColors.success,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
                Consumer(
                  builder: (context, ref, _) => ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: GloboColors.success,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.build_circle_outlined, size: 15),
                    label: const Text('Registrar servicio'),
                    onPressed: () => _registrarServicio(context, ref),
                  ),
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

// ── Skeleton de carga ─────────────────────────────────────────────────────────

class _MantenimientoShimmer extends StatelessWidget {
  const _MantenimientoShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? GloboColors.darkBackgroundTertiary : GloboColors.backgroundTertiary,
      highlightColor: isDark ? GloboColors.darkSurfaceElevated : GloboColors.backgroundSecondary,
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 380,
            mainAxisExtent: 220,
            crossAxisSpacing: GloboSpacing.md,
            mainAxisSpacing: GloboSpacing.md,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: GloboRadius.cardRadius,
              border: Border.all(color: GloboColors.divider),
            ),
          ),
        ),
      ),
    );
  }
}
