import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/regla_alerta.dart';
import '../providers/reglas_alerta_provider.dart';

class AlertasReglasPage extends ConsumerWidget {
  const AlertasReglasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reglas        = ref.watch(reglasAlertaProvider);
    final viajesAlerta  = ref.watch(viajesEnAlertaProvider);

    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(reglas: reglas, activas: viajesAlerta.length),
          const SizedBox(height: GloboSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lista de reglas configurables
                Expanded(
                  flex: 3,
                  child: _ReglasList(reglas: reglas),
                ),
                const SizedBox(width: GloboSpacing.md),
                // Viajes que dispararon alguna regla
                Expanded(
                  flex: 2,
                  child: _DispararosPanel(viajesAlerta: viajesAlerta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Encabezado ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final List<ReglaAlerta> reglas;
  final int activas;
  const _Header({required this.reglas, required this.activas});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reglas de Alerta', style: GloboTypography.headlineMedium),
              Text(
                '${reglas.where((r) => r.activa).length} activas · '
                '$activas disparadas ahora',
                style: GloboTypography.bodyMedium,
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Nueva Regla'),
          onPressed: () {},
        ),
      ],
    );
  }
}

// ── Lista de reglas ───────────────────────────────────────────────────────────

class _ReglasList extends ConsumerWidget {
  final List<ReglaAlerta> reglas;
  const _ReglasList({required this.reglas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Text('Reglas Configuradas',
                style: GloboTypography.titleMedium),
          ),
          const Divider(height: 0),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: reglas.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) =>
                  _ReglaRow(regla: reglas[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReglaRow extends ConsumerWidget {
  final ReglaAlerta regla;
  const _ReglaRow({required this.regla});

  IconData get _condicionIcon => switch (regla.condicion) {
        CondicionAlerta.varianzaCombustible => Icons.local_gas_station_outlined,
        CondicionAlerta.sosActivados        => Icons.sos_outlined,
        CondicionAlerta.banderasRojas       => Icons.flag_outlined,
        CondicionAlerta.tiempoSinActividad  => Icons.signal_wifi_off_outlined,
        CondicionAlerta.odometroAlto        => Icons.speed_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: regla.activa
              ? GloboColors.primary.withAlpha(20)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: GloboRadius.cardRadius,
        ),
        child: Icon(
          _condicionIcon,
          size: 20,
          color: regla.activa
              ? GloboColors.primary
              : GloboColors.steelGrayLight,
        ),
      ),
      title: Text(regla.nombre, style: GloboTypography.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(regla.descripcionCondicion, style: GloboTypography.caption),
          const SizedBox(height: 2),
          _AccionesChips(acciones: regla.acciones),
        ],
      ),
      trailing: Switch(
        value: regla.activa,
        onChanged: (_) => ref
            .read(reglasAlertaProvider.notifier)
            .toggleActiva(regla.id),
        activeColor: GloboColors.primary,
      ),
    );
  }
}

class _AccionesChips extends StatelessWidget {
  final List<AccionAlerta> acciones;
  const _AccionesChips({required this.acciones});

  String _label(AccionAlerta a) => switch (a) {
        AccionAlerta.notificarSupervisor  => 'Notificar',
        AccionAlerta.bloquearAsignacion   => 'Bloquear',
        AccionAlerta.generarAuditoria     => 'Auditar',
      };

  Color _color(AccionAlerta a) => switch (a) {
        AccionAlerta.notificarSupervisor  => GloboColors.accentBright,
        AccionAlerta.bloquearAsignacion   => GloboColors.error,
        AccionAlerta.generarAuditoria     => GloboColors.warningAccent,
      };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: acciones
          .map((a) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _color(a).withAlpha(20),
                  borderRadius: GloboRadius.chipRadius,
                ),
                child: Text(
                  _label(a),
                  style:
                      GloboTypography.labelSmall.copyWith(color: _color(a)),
                ),
              ))
          .toList(),
    );
  }
}

// ── Panel de disparados ────────────────────────────────────────────────────────

class _DispararosPanel extends StatelessWidget {
  final List<dynamic> viajesAlerta;
  const _DispararosPanel({required this.viajesAlerta});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 18, color: GloboColors.warningAccent),
                const SizedBox(width: GloboSpacing.sm),
                Text('Disparadas Ahora',
                    style: GloboTypography.titleMedium),
                const Spacer(),
                if (viajesAlerta.isNotEmpty)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: GloboColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${viajesAlerta.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 0),
          Expanded(
            child: viajesAlerta.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 40,
                            color: GloboColors.successAccent),
                        SizedBox(height: GloboSpacing.sm),
                        Text('Sin alertas activas',
                            style: GloboTypography.bodyMedium),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: viajesAlerta.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (ctx, i) {
                      final item = viajesAlerta[i];
                      return ListTile(
                        leading: const Icon(Icons.warning_rounded,
                            color: GloboColors.error, size: 20),
                        title: Text(
                          item.viaje.origenDescripcion,
                          style: GloboTypography.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.regla.nombre,
                          style: GloboTypography.caption,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
