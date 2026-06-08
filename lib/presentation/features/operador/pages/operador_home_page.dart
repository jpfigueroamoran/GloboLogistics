import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/actividad_operativa.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/operador_provider.dart';
import '../providers/sos_provider.dart';
import '../widgets/estado_selector_widget.dart';
import '../widgets/ocr_capture_widget.dart';
import '../widgets/operador_map_widget.dart';
import 'iniciar_viaje_page.dart';
import 'sos_page.dart';
import '../widgets/justificacion_dialog.dart';
import '../../../../injection_container.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';
import '../../../../demo/demo_providers.dart' show demoUserProvider;

import '../widgets/connectivity_sync_listener.dart';
import '../providers/gps_tracker_provider.dart';

class OperadorHomePage extends ConsumerStatefulWidget {
  final String operadorId;
  final String unidadId;
  final String? nombreOperador;

  const OperadorHomePage({
    super.key,
    required this.operadorId,
    required this.unidadId,
    this.nombreOperador,
  });

  @override
  ConsumerState<OperadorHomePage> createState() => _OperadorHomePageState();
}

class _OperadorHomePageState extends ConsumerState<OperadorHomePage> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gpsTrackerProvider.notifier).startTracking(widget.unidadId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(operadorProvider);
    final viajeSP = ref.watch(viajeActivoStreamProvider(widget.operadorId));

    return ConnectivitySyncListener(
      child: Scaffold(
        backgroundColor: GloboColors.backgroundSecondary,
        appBar: _buildAppBar(context, ref, state),
        body: viajeSP.when(
          loading: () => const _LoadingBody(),
          error:   (e, _) => _ErrorBody(message: e.toString()),
          data: (viajes) {
            final viaje = viajes.isNotEmpty ? viajes.first : null;
            if (state.viajeActivo == null && viaje != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(operadorProvider.notifier).setViajeActivo(viaje);
              });
            }
            return _OperadorBody(
              viaje:      viaje,
              operadorId: widget.operadorId,
              unidadId:   widget.unidadId,
            );
          },
        ),
        floatingActionButton: _SosButton(
          operadorId: widget.operadorId,
          unidadId:   widget.unidadId,
          viajeId:    state.viajeActivo?.id ?? '',
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, WidgetRef ref, OperadorState state) {
    return AppBar(
      backgroundColor: GloboColors.primary,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'GLOBO LOGISTICS',
            style: GloboTypography.labelSmall.copyWith(
              color: GloboColors.textOnDarkSecondary,
              letterSpacing: 2,
              fontSize: 9,
            ),
          ),
          Text(
            widget.nombreOperador ?? 'Módulo Operador',
            style: GloboTypography.titleMedium
                .copyWith(color: GloboColors.textOnDark),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      // ── Menú desplegable de estado + sincronización ───────────────────────
      actions: [
        _EstadoMenuButton(state: state),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Cerrar sesión',
          onPressed: () {
            ref.read(demoUserProvider.notifier).state = null;
          },
        ),
      ],
    );
  }
}

// ── Menú desplegable de la derecha ────────────────────────────────────────────

class _EstadoMenuButton extends StatelessWidget {
  final OperadorState state;
  const _EstadoMenuButton({required this.state});

  Color get _dotColor => switch (state.estadoActual) {
        EstadoOperador.offline  => GloboColors.estadoOffline,
        EstadoOperador.carga    => GloboColors.estadoCarga,
        EstadoOperador.transito => GloboColors.estadoTransito,
        EstadoOperador.descarga => GloboColors.estadoDescarga,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: 'Estado del operador',
      color: GloboColors.surface,
      shape: RoundedRectangleBorder(borderRadius: GloboRadius.cardRadius),
      offset: const Offset(0, 48),
      // Botón compacto en el AppBar
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.more_vert, color: Colors.white, size: 22),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dotColor,
                  border: Border.all(
                      color: GloboColors.primary, width: 1.5),
                ),
              ),
            ),
            if (state.pendientesSincronizacion > 0)
              Positioned(
                top: -8,
                left: -8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: GloboColors.warning,
                    borderRadius: GloboRadius.chipRadius,
                  ),
                  child: Text(
                    '${state.pendientesSincronizacion}',
                    style: GloboTypography.labelSmall.copyWith(
                        color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Estado actual',
                  style: GloboTypography.caption
                      .copyWith(letterSpacing: 0.8)),
              const SizedBox(height: 6),
              _EstadoChipCompact(estadoActual: state.estadoActual),
              if (state.pendientesSincronizacion > 0) ...[
                const Divider(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_problem,
                        size: 14, color: GloboColors.warning),
                    const SizedBox(width: 6),
                    Text(
                      '${state.pendientesSincronizacion} pendiente(s) de sync',
                      style: GloboTypography.caption
                          .copyWith(color: GloboColors.warning),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EstadoChipCompact extends StatelessWidget {
  final EstadoOperador estadoActual;
  const _EstadoChipCompact({required this.estadoActual});

  Color get _color => switch (estadoActual) {
        EstadoOperador.offline  => GloboColors.estadoOffline,
        EstadoOperador.carga    => GloboColors.estadoCarga,
        EstadoOperador.transito => GloboColors.estadoTransito,
        EstadoOperador.descarga => GloboColors.estadoDescarga,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(18),
        borderRadius: GloboRadius.chipRadius,
        border: Border.all(color: _color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: _color),
          ),
          const SizedBox(width: 6),
          Text(
            estadoActual.label,
            style: GloboTypography.labelSmall
                .copyWith(color: _color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Body principal ────────────────────────────────────────────────────────────

class _OperadorBody extends ConsumerWidget {
  final Viaje? viaje;
  final String operadorId;
  final String unidadId;

  const _OperadorBody({
    this.viaje,
    required this.operadorId,
    required this.unidadId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operadorProvider);
    final esProgramado = viaje?.estado == EstadoViaje.programado;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ViajeInfoCard(
            viaje:      viaje,
            operadorId: operadorId,
            unidadId:   unidadId,
          ),
          if (esProgramado) ...[
            const SizedBox(height: GloboSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Aceptar y Comenzar Viaje'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GloboColors.success,
                  padding: const EdgeInsets.symmetric(vertical: GloboSpacing.lg),
                  textStyle: GloboTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  ref.read(operadorProvider.notifier).comenzarViajeAsignado(viaje!.id);
                },
              ),
            ),
          ] else if (viaje != null) ...[
            const SizedBox(height: GloboSpacing.md),
            EstadoSelectorWidget(
              estadoActual: state.estadoActual,
              onEstadoChanged: (nuevo) => ref
                  .read(operadorProvider.notifier)
                  .cambiarEstado(nuevo, viaje?.id),
            ),
            const SizedBox(height: GloboSpacing.md),
            if (viaje!.estado == EstadoViaje.enCurso)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _finalizarViaje(context, ref, viaje!),
                  icon: const Icon(Icons.flag_circle_outlined),
                  label: const Text('Finalizar Viaje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GloboColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: GloboSpacing.md),
                  ),
                ),
              ),
            const SizedBox(height: GloboSpacing.md),
            OcrCaptureWidget(
              viajeId:    viaje?.id    ?? '',
              operadorId: operadorId,
              unidadId:   unidadId,
            ),
            const SizedBox(height: GloboSpacing.md),
            const OperadorMapWidget(),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _finalizarViaje(BuildContext context, WidgetRef ref, Viaje viaje) async {
    final varianza = viaje.varianzaCombustible ?? 0.0;
    
    if (varianza > 0.05) {
      final motivo = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const JustificacionDialog(),
      );
      
      if (motivo != null && motivo.isNotEmpty) {
        await sl<IViajeRepository>().justificarVarianza(viaje.id, motivo);
      }
    }
    
    await sl<IViajeRepository>().actualizarEstado(viaje.id, EstadoViaje.completado);
    ref.read(operadorProvider.notifier).cambiarEstado(EstadoOperador.offline, viaje.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viaje finalizado correctamente.'),
        backgroundColor: GloboColors.success,
      ),
    );
  }
}

// ── Tarjeta de viaje ──────────────────────────────────────────────────────────

class _ViajeInfoCard extends StatelessWidget {
  final Viaje?  viaje;
  final String  operadorId;
  final String  unidadId;

  const _ViajeInfoCard({
    this.viaje,
    required this.operadorId,
    required this.unidadId,
  });

  @override
  Widget build(BuildContext context) {
    if (viaje == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(GloboSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estado sin viaje
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: GloboColors.backgroundSecondary,
                      borderRadius: GloboRadius.buttonRadius,
                    ),
                    child: const Icon(Icons.no_transfer,
                        color: GloboColors.textTertiary, size: 20),
                  ),
                  const SizedBox(width: GloboSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sin viaje activo',
                            style: GloboTypography.titleMedium),
                        Text(
                          'Inicia un nuevo viaje cuando estés listo',
                          style: GloboTypography.caption,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GloboSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: GloboSpacing.md),
              // Botón integrado en la card
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IniciarViajePage(
                        operadorId: operadorId,
                        unidadId:   unidadId,
                      ),
                    ),
                  ),
                  icon:  const Icon(Icons.add_road, size: 18),
                  label: const Text('Iniciar nuevo viaje'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final esBandera = viaje!.tieneBanderaRoja;
    final tieneMultiDestino = viaje!.destinos.isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: GloboRadius.cardRadius,
        side: BorderSide(
          color: esBandera
              ? GloboColors.error.withAlpha(80)
              : GloboColors.divider,
          width: esBandera ? 1.5 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.md,
                vertical: GloboSpacing.sm),
            decoration: BoxDecoration(
              color: GloboColors.primary.withAlpha(8),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(GloboRadius.md)),
              border: const Border(
                  bottom: BorderSide(
                      color: GloboColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    size: 16, color: GloboColors.primary),
                const SizedBox(width: GloboSpacing.sm),
                Expanded(
                  child: Text(
                      viaje!.estado == EstadoViaje.programado
                          ? 'Nuevo Viaje Asignado'
                          : 'Viaje en curso',
                      style: GloboTypography.labelLarge
                          .copyWith(color: GloboColors.primary)),
                ),
                if (tieneMultiDestino) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GloboColors.infoLight,
                      borderRadius: GloboRadius.chipRadius,
                    ),
                    child: Text(
                      '${viaje!.destinos.length} parada${viaje!.destinos.length > 1 ? 's' : ''}',
                      style: GloboTypography.caption
                          .copyWith(color: GloboColors.info),
                    ),
                  ),
                  const SizedBox(width: GloboSpacing.sm),
                ],
                if (esBandera)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: GloboColors.errorLight,
                      borderRadius: GloboRadius.buttonRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag,
                            size: 12, color: GloboColors.error),
                        const SizedBox(width: 4),
                        Text('Bandera roja',
                            style: GloboTypography.caption
                                .copyWith(color: GloboColors.error)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Ruta
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteRow(
                  icon:      Icons.circle,
                  iconColor: GloboColors.success,
                  iconSize:  10,
                  label:     'Origen',
                  value:     viaje!.origenDescripcion,
                ),
                if (tieneMultiDestino)
                  ..._buildMultiStopRoute(viaje!.destinos)
                else ...[
                  _connector(),
                  _RouteRow(
                    icon:      Icons.location_on,
                    iconColor: GloboColors.primary,
                    iconSize:  14,
                    label:     'Destino',
                    value:     viaje!.destinoDescripcion,
                  ),
                ],
                const SizedBox(height: GloboSpacing.md),
                // Métricas rápidas
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MetricChip(
                      icon:  Icons.local_gas_station_outlined,
                      value: '${viaje!.litrosCargados.toStringAsFixed(0)} L',
                      label: 'cargados',
                    ),
                    if (viaje!.varianzaCombustible != null) ...[
                      const SizedBox(width: GloboSpacing.sm),
                      _MetricChip(
                        icon:    Icons.analytics_outlined,
                        value:   '${(viaje!.varianzaCombustible! * 100).toStringAsFixed(1)}%',
                        label:   'varianza',
                        isAlert: esBandera,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMultiStopRoute(List<Destino> destinos) {
    final widgets = <Widget>[];
    for (int i = 0; i < destinos.length; i++) {
      final d = destinos[i];
      final esUltimo = i == destinos.length - 1;
      final completado = d.estado == EstadoDestino.completado;

      widgets.add(_connector(
        color: completado
            ? GloboColors.success.withAlpha(80)
            : GloboColors.steelGrayExtraLight,
      ));
      widgets.add(_RouteRow(
        icon:      esUltimo ? Icons.location_on : Icons.location_on_outlined,
        iconColor: completado ? GloboColors.success : GloboColors.primary,
        iconSize:  14,
        label:     'Parada ${i + 1}${esUltimo ? ' (final)' : ''}',
        value:     d.descripcion,
        badge:     completado ? '✓' : '${i + 1}',
        badgeColor: completado ? GloboColors.success : GloboColors.primary,
      ));
    }
    return widgets;
  }

  Widget _connector({Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, top: 2, bottom: 2),
      child: Container(
        width: 1,
        height: 16,
        color: color ?? GloboColors.steelGrayExtraLight,
      ),
    );
  }
}

// ── Fila de ruta ──────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final double   iconSize;
  final String   label;
  final String   value;
  final String?  badge;
  final Color?   badgeColor;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: badge != null
              ? Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: (badgeColor ?? iconColor).withAlpha(18),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: badgeColor ?? iconColor, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: badgeColor ?? iconColor,
                    ),
                  ),
                )
              : Icon(icon, size: iconSize, color: iconColor),
        ),
        const SizedBox(width: GloboSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GloboTypography.caption
                      .copyWith(fontSize: 9, letterSpacing: 0.5)),
              Text(
                value,
                style: GloboTypography.bodyMedium
                    .copyWith(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Chip métrica ──────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String   value;
  final String   label;
  final bool     isAlert;

  const _MetricChip({
    required this.icon,
    required this.value,
    required this.label,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isAlert ? GloboColors.error : GloboColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAlert
            ? GloboColors.errorLight
            : GloboColors.backgroundSecondary,
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Text(value,
                  style: GloboTypography.monoData
                      .copyWith(fontSize: 12, color: color)),
              Text(label,
                  style:
                      GloboTypography.caption.copyWith(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Botón SOS ─────────────────────────────────────────────────────────────────

class _SosButton extends ConsumerWidget {
  final String operadorId;
  final String unidadId;
  final String viajeId;

  const _SosButton({
    required this.operadorId,
    required this.unidadId,
    required this.viajeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sosState = ref.watch(sosProvider);

    return GestureDetector(
      onLongPress: () => _onSosPressed(context, ref),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width:  72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: sosState.isActive
              ? GloboColors.sosPrimary
              : GloboColors.sosSecondary,
          boxShadow: [
            BoxShadow(
              color: (sosState.isActive
                      ? GloboColors.sosPulse
                      : GloboColors.sosPrimary)
                  .withAlpha(sosState.isActive ? 120 : 60),
              blurRadius:   sosState.isActive ? 24 : 8,
              spreadRadius: sosState.isActive ? 8  : 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_rounded,
                color: Colors.white, size: 28),
            Text(
              sosState.isActive ? 'SOS ON' : 'SOS',
              style: GloboTypography.labelSmall
                  .copyWith(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _onSosPressed(BuildContext context, WidgetRef ref) {
    if (ref.read(sosProvider).isActive) {
      _showCancelConfirmation(context, ref);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SosPage(
          operadorId: operadorId,
          unidadId:   unidadId,
          viajeId:    viajeId,
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar SOS?'),
        content:
            const Text('Confirma solo si la situación está resuelta.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mantener SOS'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: GloboColors.error),
            onPressed: () {
              ref.read(sosProvider.notifier).cancelarSOS();
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar SOS'),
          ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});
  @override
  Widget build(BuildContext context) =>
      Center(child: Text(message, style: GloboTypography.bodyMedium));
}
