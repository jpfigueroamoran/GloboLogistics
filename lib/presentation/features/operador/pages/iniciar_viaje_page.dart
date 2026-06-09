import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/cliente.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/clientes_provider.dart';
import '../providers/iniciar_viaje_provider.dart';

class IniciarViajePage extends ConsumerStatefulWidget {
  final String operadorId;
  final String unidadId;

  const IniciarViajePage({
    super.key,
    required this.operadorId,
    required this.unidadId,
  });

  @override
  ConsumerState<IniciarViajePage> createState() => _IniciarViajePageState();
}

class _IniciarViajePageState extends ConsumerState<IniciarViajePage> {
  final _origenCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _gettingGps = false;
  GeoPoint? _gpsPoint;

  @override
  void dispose() {
    _origenCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(iniciarViajeProvider);

    ref.listen<IniciarViajeState>(iniciarViajeProvider, (_, next) {
      if (next.viajeCreado != null && mounted) {
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GloboColors.primary,
        leading: BackButton(
          color: Colors.white,
          onPressed: () {
            if (state.paso == PasoWizard.origen) {
              Navigator.of(context).pop();
            } else {
              ref.read(iniciarViajeProvider.notifier).irAtras();
            }
          },
        ),
        title: Text(
          _tituloStep(state.paso),
          style: GloboTypography.titleMedium
              .copyWith(color: GloboColors.textOnDark),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepIndicator(paso: state.paso),
        ),
      ),
      body: switch (state.paso) {
        PasoWizard.origen => _PasoOrigenBody(
            ctrl:        _origenCtrl,
            gettingGps:  _gettingGps,
            gpsPoint:    _gpsPoint,
            onGetGps:    _getGps,
            onContinuar: () => ref
                .read(iniciarViajeProvider.notifier)
                .setOrigen(_origenCtrl.text.trim(), geo: _gpsPoint),
          ),
        PasoWizard.destinos => _PasoDestinosBody(
            searchCtrl:  _searchCtrl,
            seleccionados: state.destinosSeleccionados,
            onSearch:    _onSearch,
            onAgregar:   (c) =>
                ref.read(iniciarViajeProvider.notifier).agregarDestino(c),
            onQuitar:    (id) =>
                ref.read(iniciarViajeProvider.notifier).quitarDestino(id),
            onContinuar: state.destinosSeleccionados.isNotEmpty
                ? () => ref.read(iniciarViajeProvider.notifier).irAConfirmar()
                : null,
          ),
        PasoWizard.confirmar => _PasoConfirmarBody(
            state:    state,
            onIniciar: () => ref
                .read(iniciarViajeProvider.notifier)
                .crearViaje(
                  operadorId: widget.operadorId,
                  unidadId:   widget.unidadId,
                ),
          ),
      },
    );
  }

  String _tituloStep(PasoWizard paso) => switch (paso) {
        PasoWizard.origen   => 'Punto de origen',
        PasoWizard.destinos => 'Seleccionar destinos',
        PasoWizard.confirmar => 'Confirmar viaje',
      };

  Future<void> _getGps() async {
    setState(() => _gettingGps = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Servicio de ubicación desactivado.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Permiso de ubicación denegado.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Permiso de ubicación denegado permanentemente.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _gpsPoint = GeoPoint(lat: pos.latitude, lng: pos.longitude);
        if (_origenCtrl.text.isEmpty) {
          _origenCtrl.text =
              '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        }
      });
    } catch (_) {
      _showSnack('No se pudo obtener la ubicación.');
    } finally {
      if (mounted) setState(() => _gettingGps = false);
    }
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      ref.read(clientesBusquedaProvider.notifier).limpiar();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(clientesBusquedaProvider.notifier).buscar(query);
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ── Step progress bar ─────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final PasoWizard paso;
  const _StepIndicator({required this.paso});

  @override
  Widget build(BuildContext context) {
    final progress = switch (paso) {
      PasoWizard.origen   => 1 / 3,
      PasoWizard.destinos => 2 / 3,
      PasoWizard.confirmar => 1.0,
    };
    return LinearProgressIndicator(
      value:           progress,
      backgroundColor: Colors.white24,
      valueColor:      const AlwaysStoppedAnimation<Color>(Colors.white70),
      minHeight:       4,
    );
  }
}

// ── Paso 1: Origen ────────────────────────────────────────────────────────────

class _PasoOrigenBody extends StatefulWidget {
  final TextEditingController ctrl;
  final bool gettingGps;
  final GeoPoint? gpsPoint;
  final VoidCallback onGetGps;
  final VoidCallback onContinuar;

  const _PasoOrigenBody({
    required this.ctrl,
    required this.gettingGps,
    required this.gpsPoint,
    required this.onGetGps,
    required this.onContinuar,
  });

  @override
  State<_PasoOrigenBody> createState() => _PasoOrigenBodyState();
}

class _PasoOrigenBodyState extends State<_PasoOrigenBody> {
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _canContinue = widget.ctrl.text.trim().isNotEmpty;
    widget.ctrl.addListener(() {
      final val = widget.ctrl.text.trim().isNotEmpty;
      if (val != _canContinue) setState(() => _canContinue = val);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: GloboSpacing.md),
          Text('¿Dónde inicia el viaje?',
              style: GloboTypography.headlineMedium),
          const SizedBox(height: GloboSpacing.sm),
          Text(
            'Ingresa el nombre del punto de partida.',
            style: GloboTypography.bodyMedium
                .copyWith(color: GloboColors.textSecondary),
          ),
          const SizedBox(height: GloboSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del origen',
                    hintText: 'Ej: CDMX — Bodega Central Vallejo',
                    prefixIcon: Icon(Icons.circle,
                        size: 10, color: GloboColors.success),
                  ),
                ),
              ),
              const SizedBox(width: GloboSpacing.sm),
              _GpsButton(
                loading:  widget.gettingGps,
                captured: widget.gpsPoint != null,
                onPressed: widget.onGetGps,
              ),
            ],
          ),
          if (widget.gpsPoint != null) ...[
            const SizedBox(height: GloboSpacing.sm),
            Row(
              children: [
                const Icon(Icons.gps_fixed,
                    size: 13, color: GloboColors.success),
                const SizedBox(width: 4),
                Text(
                  'GPS: ${widget.gpsPoint!.lat.toStringAsFixed(5)}, '
                  '${widget.gpsPoint!.lng.toStringAsFixed(5)}',
                  style: GloboTypography.caption
                      .copyWith(color: GloboColors.success),
                ),
              ],
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canContinue ? widget.onContinuar : null,
              icon:  const Icon(Icons.arrow_forward),
              label: const Text('Continuar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: GloboSpacing.md),
        ],
      ),
    );
  }
}

class _GpsButton extends StatelessWidget {
  final bool loading;
  final bool captured;
  final VoidCallback onPressed;

  const _GpsButton({
    required this.loading,
    required this.captured,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Capturar ubicación GPS',
      child: SizedBox(
        height: 56,
        width: 56,
        child: OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(
              color: captured ? GloboColors.success : GloboColors.divider,
              width: captured ? 1.5 : 1,
            ),
            backgroundColor:
                captured ? GloboColors.successLight : null,
            shape: RoundedRectangleBorder(
                borderRadius: GloboRadius.buttonRadius),
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  captured ? Icons.gps_fixed : Icons.gps_not_fixed,
                  size: 20,
                  color: captured
                      ? GloboColors.success
                      : GloboColors.textTertiary,
                ),
        ),
      ),
    );
  }
}

// ── Paso 2: Destinos ──────────────────────────────────────────────────────────

class _PasoDestinosBody extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final List<Cliente> seleccionados;
  final void Function(String) onSearch;
  final void Function(Cliente) onAgregar;
  final void Function(String) onQuitar;
  final VoidCallback? onContinuar;

  const _PasoDestinosBody({
    required this.searchCtrl,
    required this.seleccionados,
    required this.onSearch,
    required this.onAgregar,
    required this.onQuitar,
    required this.onContinuar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultados = ref.watch(clientesBusquedaProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GloboSpacing.md, GloboSpacing.md, GloboSpacing.md, 0),
          child: TextField(
            controller: searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Buscar cliente',
              hintText: 'Nombre o dirección...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onSearch,
          ),
        ),

        // Resultados de búsqueda
        if (resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
            decoration: BoxDecoration(
              color: GloboColors.surface,
              border: Border.all(color: GloboColors.divider),
              borderRadius: GloboRadius.cardRadius,
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap:  true,
              padding:     EdgeInsets.zero,
              itemCount:   resultados.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: 0.5),
              itemBuilder: (_, i) {
                final c = resultados[i];
                final yaAgregado = seleccionados.any((s) => s.id == c.id);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: GloboColors.primary.withAlpha(16),
                    child: Text(
                      c.nombre.substring(0, 1).toUpperCase(),
                      style: GloboTypography.labelSmall
                          .copyWith(color: GloboColors.primary),
                    ),
                  ),
                  title: Text(c.nombre,
                      style: GloboTypography.bodyMedium
                          .copyWith(color: GloboColors.textPrimary)),
                  subtitle: Text(
                    c.direccion,
                    style: GloboTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: yaAgregado
                      ? const Icon(Icons.check_circle,
                          color: GloboColors.success, size: 20)
                      : IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              size: 20),
                          onPressed: () => onAgregar(c),
                          tooltip: 'Agregar destino',
                        ),
                );
              },
            ),
          ),

        // Lista de destinos seleccionados
        if (seleccionados.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: GloboSpacing.md, vertical: GloboSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.route, size: 15, color: GloboColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Ruta de entrega (${seleccionados.length})',
                  style: GloboTypography.labelLarge
                      .copyWith(color: GloboColors.primary),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: GloboSpacing.md),
              itemCount: seleccionados.length,
              itemBuilder: (_, i) {
                final c = seleccionados[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: GloboSpacing.sm),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: GloboColors.primary,
                      child: Text(
                        '${i + 1}',
                        style: GloboTypography.labelSmall
                            .copyWith(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text(c.nombre,
                        style: GloboTypography.bodyMedium
                            .copyWith(color: GloboColors.textPrimary)),
                    subtitle: Text(
                      c.direccion,
                      style: GloboTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: GloboColors.error, size: 20),
                      onPressed: () => onQuitar(c.id),
                      tooltip: 'Quitar destino',
                    ),
                  ),
                );
              },
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_location_alt_outlined,
                      size: 52, color: GloboColors.steelGrayExtraLight),
                  const SizedBox(height: GloboSpacing.sm),
                  Text(
                    'Sin destinos seleccionados',
                    style: GloboTypography.bodyMedium
                        .copyWith(color: GloboColors.textTertiary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Busca y agrega al menos un cliente',
                    style: GloboTypography.caption,
                  ),
                ],
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(GloboSpacing.md),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onContinuar,
              icon:  const Icon(Icons.arrow_forward),
              label: const Text('Continuar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Paso 3: Confirmar ─────────────────────────────────────────────────────────

class _PasoConfirmarBody extends StatelessWidget {
  final IniciarViajeState state;
  final VoidCallback onIniciar;

  const _PasoConfirmarBody({
    required this.state,
    required this.onIniciar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GloboSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: GloboSpacing.md),
          Text('Resumen del viaje', style: GloboTypography.headlineMedium),
          const SizedBox(height: GloboSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(GloboSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResumenRow(
                    icon:      Icons.circle,
                    iconColor: GloboColors.success,
                    label:     'Origen',
                    value:     state.origenDescripcion ?? '',
                  ),
                  ...state.destinosSeleccionados.asMap().entries.map((e) {
                    final esUltimo =
                        e.key == state.destinosSeleccionados.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 7, top: 2, bottom: 2),
                          child: Container(
                            width: 1,
                            height: 14,
                            color: GloboColors.steelGrayExtraLight,
                          ),
                        ),
                        _ResumenRow(
                          icon:      esUltimo
                              ? Icons.location_on
                              : Icons.location_on_outlined,
                          iconColor: GloboColors.primary,
                          label:     'Parada ${e.key + 1}',
                          value:     e.value.nombre,
                          subtitle:  e.value.direccion,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: GloboSpacing.md),
            Container(
              padding: const EdgeInsets.all(GloboSpacing.sm),
              decoration: BoxDecoration(
                color: GloboColors.errorLight,
                borderRadius: GloboRadius.buttonRadius,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: GloboColors.error, size: 16),
                  const SizedBox(width: GloboSpacing.sm),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: GloboTypography.caption
                          .copyWith(color: GloboColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.loading ? null : onIniciar,
              icon: state.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(state.loading ? 'Iniciando...' : 'Iniciar viaje'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GloboColors.successAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: GloboSpacing.md),
        ],
      ),
    );
  }
}

class _ResumenRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label;
  final String   value;
  final String?  subtitle;

  const _ResumenRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: GloboSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GloboTypography.caption
                    .copyWith(fontSize: 9, letterSpacing: 0.5),
              ),
              Text(
                value,
                style: GloboTypography.bodyMedium
                    .copyWith(
                        color:      GloboColors.textPrimary,
                        fontWeight: FontWeight.w500),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GloboTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
