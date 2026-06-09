import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/actividad_operativa.dart';
import '../../../../domain/entities/operador_score.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/operador_provider.dart';
import '../providers/viaje_geo_monitor_provider.dart';
import '../widgets/ocr_capture_widget.dart';
import '../widgets/operador_map_widget.dart';
import 'carga_combustible_page.dart';
import 'iniciar_viaje_page.dart';
import 'sos_page.dart';
import '../widgets/justificacion_dialog.dart';
import '../../../../injection_container.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';
import '../../../../demo/demo_providers.dart' show demoUserProvider;
import '../../../../presentation/features/torre_control/providers/operador_score_provider.dart';

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
        bottomNavigationBar: _QuickActionsBar(
          operadorId: widget.operadorId,
          unidadId:   widget.unidadId,
          viajeId:    state.viajeActivo?.id ?? '',
        ),
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
    final esProgramado = viaje?.estado == EstadoViaje.programado;

    // Activar geo monitor cuando hay viaje con coordenadas
    GeoMonitorState? geoState;
    if (viaje != null &&
        (viaje!.origenGeo != null || viaje!.destinoGeo != null)) {
      geoState = ref.watch(viajeGeoMonitorProvider(viaje!));

      // Escuchar auto-inicio y auto-cierre para notificar al operador
      ref.listen<GeoMonitorState>(viajeGeoMonitorProvider(viaje!), (prev, next) {
        if (!context.mounted) return;
        if (prev?.zona != GeofenceZone.enBodegaCarga &&
            next.zona == GeofenceZone.enBodegaCarga &&
            viaje!.estado == EstadoViaje.programado) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📦 Llegaste a la bodega — iniciando viaje automáticamente'),
              backgroundColor: GloboColors.success,
              duration: Duration(seconds: 4),
            ),
          );
        }
        if (!next.stopDetectado && (prev?.stopDetectado ?? false)) return;
        if (next.stopDetectado) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Destino alcanzado — viaje completado automáticamente'),
              backgroundColor: GloboColors.primary,
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScorePersonalCard(operadorId: operadorId),
          if (geoState != null) ...[
            const SizedBox(height: GloboSpacing.sm),
            _GeofenceBanner(geoState: geoState, viaje: viaje!),
          ],
          const SizedBox(height: GloboSpacing.md),
          _ViajeInfoCard(
            viaje:      viaje,
            operadorId: operadorId,
            unidadId:   unidadId,
          ),
          const SizedBox(height: GloboSpacing.lg),
          if (esProgramado)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill, size: 28),
                label: const Text('Comenzar Viaje'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GloboColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  textStyle: GloboTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                onPressed: () {
                  ref.read(operadorProvider.notifier).comenzarViajeAsignado(viaje!.id);
                },
              ),
            )
          else if (viaje != null) ...[
            if (viaje!.estado == EstadoViaje.enCurso)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _finalizarViaje(context, ref, viaje!),
                  icon: const Icon(Icons.flag_circle_outlined, size: 28),
                  label: const Text('Finalizar Viaje / Descarga'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GloboColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    textStyle: GloboTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
              ),
            const SizedBox(height: GloboSpacing.lg),
            const Text('Navegación Activa', style: TextStyle(fontWeight: FontWeight.bold, color: GloboColors.textTertiary)),
            const SizedBox(height: GloboSpacing.sm),
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                Wrap(
                  spacing: GloboSpacing.sm,
                  runSpacing: GloboSpacing.sm,
                  children: [
                    _MetricChip(
                      icon:  Icons.local_gas_station_outlined,
                      value: '${viaje!.litrosCargados.toStringAsFixed(0)} L',
                      label: 'cargados',
                    ),
                    if (viaje!.varianzaCombustible != null)
                      _MetricChip(
                        icon:    Icons.analytics_outlined,
                        value:   '${(viaje!.varianzaCombustible! * 100).toStringAsFixed(1)}%',
                        label:   'varianza',
                        isAlert: esBandera,
                      ),
                    if (viaje!.estado == EstadoViaje.enCurso && viaje!.fechaInicio != null)
                      _TripElapsedTimer(fechaInicio: viaje!.fechaInicio!),
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
            : Theme.of(context).colorScheme.surfaceContainerHighest,
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

// ── Quick Actions Bar ──────────────────────────────────────────────────────────

class _QuickActionsBar extends StatelessWidget {
  final String operadorId;
  final String unidadId;
  final String viajeId;

  const _QuickActionsBar({
    required this.operadorId,
    required this.unidadId,
    required this.viajeId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
      decoration: BoxDecoration(
        color: GloboColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _QuickActionButton(
              icon: Icons.local_gas_station,
              label: 'Combustible',
              color: GloboColors.warningAccent,
              onPressed: () {
                if (viajeId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Debes tener un viaje activo para registrar combustible')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CargaCombustiblePage(
                      viajeId: viajeId,
                      operadorId: operadorId,
                      unidadId: unidadId,
                    ),
                  ),
                );
              },
            ),
            _QuickActionButton(
              icon: Icons.receipt_long,
              label: 'Gastos',
              color: GloboColors.info,
              onPressed: () => _mostrarOcrDialog(context, 'Gastos'),
            ),
            _QuickActionButton(
              icon: Icons.warning_rounded,
              label: 'SOS',
              color: GloboColors.error,
              isAlert: true,
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SosPage(operadorId: operadorId, unidadId: unidadId, viajeId: viajeId),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOcrDialog(BuildContext context, String tipo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GloboRadius.lg)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: GloboSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Registrar $tipo', style: GloboTypography.titleMedium),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(GloboSpacing.md),
                    child: OcrCaptureWidget(
                      viajeId: viajeId,
                      operadorId: operadorId,
                      unidadId: unidadId,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isAlert;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.isAlert = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: GloboRadius.cardRadius,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: GloboSpacing.sm),
        decoration: BoxDecoration(
          color: isAlert ? color : color.withAlpha(20),
          borderRadius: GloboRadius.cardRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isAlert ? Colors.white : color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: GloboTypography.labelSmall.copyWith(
                color: isAlert ? Colors.white : color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Score personal del operador ───────────────────────────────────────────────

class _ScorePersonalCard extends ConsumerWidget {
  final String operadorId;
  const _ScorePersonalCard({required this.operadorId});

  Color _nivelColor(NivelScore nivel) => switch (nivel) {
        NivelScore.excelente => GloboColors.successAccent,
        NivelScore.bueno     => GloboColors.info,
        NivelScore.regular   => GloboColors.warningAccent,
        NivelScore.critico   => GloboColors.error,
      };

  String _nivelLabel(NivelScore nivel) => switch (nivel) {
        NivelScore.excelente => 'Excelente',
        NivelScore.bueno     => 'Bueno',
        NivelScore.regular   => 'Regular',
        NivelScore.critico   => 'Crítico',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(operadorScoresProvider);
    final score  = scores.where((s) => s.operadorId == operadorId).firstOrNull;

    if (score == null) return const SizedBox.shrink();

    final color = _nivelColor(score.nivel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(80)),
              ),
              alignment: Alignment.center,
              child: Text(
                score.scoreTotal.toStringAsFixed(0),
                style: GloboTypography.monoData.copyWith(
                    color: color, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: GloboSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mi Score',
                      style: GloboTypography.caption
                          .copyWith(letterSpacing: 0.6)),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withAlpha(18),
                          borderRadius: GloboRadius.chipRadius,
                          border: Border.all(color: color.withAlpha(60)),
                        ),
                        child: Text(
                          _nivelLabel(score.nivel),
                          style: GloboTypography.labelSmall
                              .copyWith(color: color, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: GloboSpacing.sm),
                      Text(
                        '${score.totalViajes} viaje${score.totalViajes == 1 ? '' : 's'}',
                        style: GloboTypography.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MetricChip(
                  icon:  Icons.check_circle_outline,
                  value: '${(score.tasaCompletitud * 100).toStringAsFixed(0)}%',
                  label: 'completitud',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Temporizador de viaje en curso ────────────────────────────────────────────

class _TripElapsedTimer extends StatefulWidget {
  final DateTime fechaInicio;
  const _TripElapsedTimer({required this.fechaInicio});

  @override
  State<_TripElapsedTimer> createState() => _TripElapsedTimerState();
}

class _TripElapsedTimerState extends State<_TripElapsedTimer> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.fechaInicio);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.fechaInicio);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _label {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m en ruta';
    return '${m}m en ruta';
  }

  @override
  Widget build(BuildContext context) {
    return _MetricChip(
      icon:  Icons.timer_outlined,
      value: _label,
      label: 'tiempo',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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

// ── Banner de geofence ────────────────────────────────────────────────────────

class _GeofenceBanner extends StatelessWidget {
  final GeoMonitorState geoState;
  final Viaje viaje;

  const _GeofenceBanner({required this.geoState, required this.viaje});

  (Color bg, Color fg, IconData icon) get _style => switch (geoState.zona) {
        GeofenceZone.enBodegaCarga => (
          GloboColors.successLight,
          GloboColors.successAccent,
          Icons.warehouse_outlined,
        ),
        GeofenceZone.cercaOrigen => (
          GloboColors.warningLight,
          GloboColors.warningAccent,
          Icons.near_me_outlined,
        ),
        GeofenceZone.enDestino => (
          GloboColors.infoLight,
          GloboColors.info,
          Icons.flag_outlined,
        ),
        GeofenceZone.cercaDestino => (
          GloboColors.infoLight,
          GloboColors.primaryAccent,
          Icons.near_me_outlined,
        ),
        _ => (
          GloboColors.backgroundSecondary,
          GloboColors.textSecondary,
          Icons.gps_fixed,
        ),
      };

  String get _distanciaLabel {
    if (geoState.zona == GeofenceZone.enBodegaCarga ||
        geoState.zona == GeofenceZone.cercaOrigen) {
      final d = geoState.distanciaOrigenM;
      return d != null ? '${d.toStringAsFixed(0)} m' : '';
    }
    final d = geoState.distanciaDestinoM;
    return d != null ? '${d.toStringAsFixed(0)} m al destino' : '';
  }

  @override
  Widget build(BuildContext context) {
    if (geoState.zona == GeofenceZone.sinViaje ||
        geoState.zona == GeofenceZone.fueraDeRuta ||
        geoState.zona == GeofenceZone.enTransito) {
      return const SizedBox.shrink();
    }

    final (bg, fg, icon) = _style;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(color: fg.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  geoState.zonaLabel,
                  style: GloboTypography.labelLarge.copyWith(color: fg),
                ),
                if (_distanciaLabel.isNotEmpty)
                  Text(
                    _distanciaLabel,
                    style: GloboTypography.caption.copyWith(color: fg),
                  ),
              ],
            ),
          ),
          if (geoState.zona == GeofenceZone.enDestino &&
              geoState.segundosEnDestino > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Auto-cierre',
                  style: GloboTypography.caption.copyWith(color: fg),
                ),
                Text(
                  _formatTimer(geoState.segundosEnDestino),
                  style: GloboTypography.monoData
                      .copyWith(color: fg, fontSize: 13),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _formatTimer(int segs) {
    final restante = 300 - segs;
    final m = restante ~/ 60;
    final s = restante % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
