import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/unidad.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/dashboard_provider.dart' show viajesActivosProvider;
import '../providers/unidades_provider.dart';
import '../widgets/fleet_map_widget.dart' show etaLabel;

/// Tablero de Entregas en Curso — la vista "siempre visible" del supervisor:
/// qué lleva cada vehículo, a dónde, en qué fase y cuándo llega.
class EntregasPage extends ConsumerWidget {
  const EntregasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viajesSP = ref.watch(viajesActivosProvider);
    final unidades = ref.watch(unidadesActivasProvider).valueOrNull ?? [];
    final placasPorUnidad = {for (final u in unidades) u.id: u};

    return viajesSP.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (todos) {
        final enCurso =
            todos.where((v) => v.estado == EstadoViaje.enCurso).toList()
              ..sort((a, b) => _ordenZona(b.seguimiento?.zona)
                  .compareTo(_ordenZona(a.seguimiento?.zona)));
        final programados =
            todos.where((v) => v.estado == EstadoViaje.programado).length;
        final porLlegar = enCurso
            .where((v) => v.seguimiento?.zona == 'cercaDestino' ||
                v.seguimiento?.zona == 'enDestino')
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── KPIs ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, 0),
              child: Row(children: [
                _Kpi(
                  icon: Icons.route_outlined,
                  label: 'En ruta ahora',
                  value: '${enCurso.length}',
                  color: GloboColors.estadoTransito,
                ),
                _Kpi(
                  icon: Icons.flag_outlined,
                  label: 'Por llegar',
                  value: '$porLlegar',
                  color: GloboColors.success,
                ),
                _Kpi(
                  icon: Icons.pending_actions_outlined,
                  label: 'Programados',
                  value: '$programados',
                  color: GloboColors.warning,
                ),
              ]),
            ),

            Expanded(
              child: enCurso.isEmpty
                  ? const _SinEntregas()
                  : ListView.separated(
                      padding: const EdgeInsets.all(GloboSpacing.md),
                      itemCount: enCurso.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: GloboSpacing.sm),
                      itemBuilder: (_, i) => _EntregaCard(
                        viaje: enCurso[i],
                        unidad: placasPorUnidad[enCurso[i].unidadId],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // Orden por avance: en tránsito al fondo, llegando arriba (lo urgente primero)
  int _ordenZona(String? zona) => switch (zona) {
        'enDestino'     => 5,
        'cercaDestino'  => 4,
        'enTransito'    => 3,
        'enBodegaCarga' => 2,
        'cercaOrigen'   => 1,
        _               => 0,
      };
}

class _EntregaCard extends StatelessWidget {
  final Viaje viaje;
  final Unidad? unidad;
  const _EntregaCard({required this.viaje, this.unidad});

  // Avance 0..1 según la fase del geofence
  double get _avance => switch (viaje.seguimiento?.zona) {
        'enDestino'     => 1.0,
        'cercaDestino'  => 0.85,
        'enTransito'    => 0.55,
        'enBodegaCarga' => 0.2,
        'cercaOrigen'   => 0.1,
        _               => 0.4,
      };

  String get _faseLabel => switch (viaje.seguimiento?.zona) {
        'cercaOrigen'   => 'Acercándose a carga',
        'enBodegaCarga' => 'En bodega de carga',
        'enTransito'    => 'En tránsito',
        'cercaDestino'  => 'Llegando al destino',
        'enDestino'     => 'En destino',
        _               => 'En ruta',
      };

  @override
  Widget build(BuildContext context) {
    final seg = viaje.seguimiento;
    final fresco = seg?.esReciente ?? false;
    final bandera = viaje.tieneBanderaRoja;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(
          color: bandera
              ? GloboColors.error.withAlpha(90)
              : GloboColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GloboSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: unidad + operador + ETA
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: GloboColors.estadoTransito.withAlpha(20),
                  borderRadius: GloboRadius.buttonRadius,
                ),
                child: const Icon(Icons.local_shipping,
                    color: GloboColors.estadoTransito, size: 20),
              ),
              const SizedBox(width: GloboSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unidad?.placas ?? viaje.unidadId,
                        style: GloboTypography.titleMedium),
                    Text(viaje.operadorNombre ?? 'Operador',
                        style: GloboTypography.caption,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (bandera)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.flag, size: 18, color: GloboColors.error),
                ),
              _EtaChip(etaMin: seg?.etaMin, fresco: fresco),
            ]),
            const SizedBox(height: GloboSpacing.sm),

            // Ruta origen → destino
            Row(children: [
              const Icon(Icons.circle, size: 9, color: GloboColors.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(viaje.origenDescripcion,
                    style: GloboTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: SizedBox(
                height: 12,
                child: VerticalDivider(
                    width: 10,
                    thickness: 1,
                    color: GloboColors.divider),
              ),
            ),
            Row(children: [
              const Icon(Icons.location_on,
                  size: 13, color: GloboColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(viaje.destinoDescripcion,
                    style: GloboTypography.bodyMedium
                        .copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: GloboSpacing.sm),

            // Barra de avance + fase
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _avance,
                    minHeight: 6,
                    backgroundColor: GloboColors.divider,
                    color: bandera
                        ? GloboColors.error
                        : GloboColors.estadoTransito,
                  ),
                ),
              ),
              const SizedBox(width: GloboSpacing.sm),
              Text(_faseLabel,
                  style: GloboTypography.labelSmall
                      .copyWith(color: GloboColors.textSecondary)),
            ]),

            if (seg != null && !fresco) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.gps_off,
                    size: 12, color: GloboColors.textTertiary),
                const SizedBox(width: 4),
                Text('Última posición hace rato — esperando GPS',
                    style: GloboTypography.caption
                        .copyWith(color: GloboColors.textTertiary)),
              ]),
            ] else if (seg == null) ...[
              const SizedBox(height: 6),
              Text('Sin reporte de posición todavía',
                  style: GloboTypography.caption
                      .copyWith(color: GloboColors.textTertiary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EtaChip extends StatelessWidget {
  final int? etaMin;
  final bool fresco;
  const _EtaChip({required this.etaMin, required this.fresco});

  @override
  Widget build(BuildContext context) {
    final texto = etaLabel(etaMin);
    if (texto.isEmpty) return const SizedBox.shrink();
    final color = fresco ? GloboColors.primary : GloboColors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: GloboRadius.chipRadius,
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule, size: 12, color: color),
        const SizedBox(width: 4),
        Text(texto,
            style: GloboTypography.labelSmall.copyWith(color: color)),
      ]),
    );
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: GloboSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
        decoration: BoxDecoration(
          color: GloboColors.surface,
          borderRadius: GloboRadius.cardRadius,
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: GloboSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style:
                        GloboTypography.headlineMedium.copyWith(color: color)),
                Text(label,
                    style: GloboTypography.caption,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SinEntregas extends StatelessWidget {
  const _SinEntregas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping_outlined,
              size: 48, color: GloboColors.textTertiary),
          const SizedBox(height: GloboSpacing.md),
          Text('No hay entregas en ruta',
              style: GloboTypography.titleMedium
                  .copyWith(color: GloboColors.textSecondary)),
          const SizedBox(height: GloboSpacing.xs),
          Text('Las entregas en curso aparecerán aquí con su avance y ETA',
              style: GloboTypography.caption),
        ],
      ),
    );
  }
}
