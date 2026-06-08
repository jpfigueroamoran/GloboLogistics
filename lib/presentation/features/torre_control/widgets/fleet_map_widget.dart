import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/unidad.dart';
import '../providers/unidades_provider.dart';

// Centro geográfico de México
const _mexicoCenter = CameraPosition(
  target: LatLng(23.6345, -102.5528),
  zoom: 5.2,
);

class FleetMapWidget extends ConsumerStatefulWidget {
  const FleetMapWidget({super.key});

  @override
  ConsumerState<FleetMapWidget> createState() => _FleetMapWidgetState();
}

class _FleetMapWidgetState extends ConsumerState<FleetMapWidget> {
  GoogleMapController? _controller;
  String? _selectedUnidadId;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Google Maps no soporta Windows/macOS/Linux en google_maps_flutter
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return _DesktopMapFallback(ref: ref);
    }

    final unidadesSP = ref.watch(unidadesActivasProvider);

    return Container(
      margin: const EdgeInsets.all(GloboSpacing.md),
      decoration: BoxDecoration(
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(color: GloboColors.divider),
      ),
      child: ClipRRect(
        borderRadius: GloboRadius.cardRadius,
        child: Stack(
          children: [
            unidadesSP.when(
              loading: () => _LoadingMap(),
              error: (e, _) => _MapError(message: e.toString()),
              data: (unidades) => _GoogleMapView(
                unidades: unidades,
                selectedId: _selectedUnidadId,
                onMapCreated: (c) => _controller = c,
                onMarkerTap: (id) =>
                    setState(() => _selectedUnidadId = id),
              ),
            ),

            // Overlay: leyenda
            Positioned(
              bottom: GloboSpacing.sm,
              left: GloboSpacing.sm,
              child: _MapLegend(),
            ),

            // Overlay: contador de unidades
            Positioned(
              top: GloboSpacing.sm,
              right: GloboSpacing.sm,
              child: unidadesSP.whenData(
                (u) => _UnitCountBadge(count: u.length),
              ).valueOrNull ??
                  const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google Map view ──────────────────────────────────────────────────────────

class _GoogleMapView extends StatelessWidget {
  final List<Unidad> unidades;
  final String? selectedId;
  final void Function(GoogleMapController) onMapCreated;
  final void Function(String) onMarkerTap;

  const _GoogleMapView({
    required this.unidades,
    required this.selectedId,
    required this.onMapCreated,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    for (final u in unidades) {
      final pos = u.ultimaPosicion;
      if (pos == null) continue;

      final hue = u.estado == EstadoUnidad.activa
          ? BitmapDescriptor.hueGreen
          : u.estado == EstadoUnidad.mantenimiento
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueRed;

      markers.add(Marker(
        markerId: MarkerId(u.id),
        position: LatLng(pos.lat, pos.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: u.placas,
          snippet: '${u.modelo} ${u.anio}',
        ),
        onTap: () => onMarkerTap(u.id),
      ));
    }

    return GoogleMap(
      initialCameraPosition: _mexicoCenter,
      markers: markers,
      onMapCreated: onMapCreated,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      mapType: MapType.normal,
      style: _darkMapStyle,
    );
  }
}

// ── Fallback para Windows (google_maps_flutter no soporta desktop) ────────────

class _DesktopMapFallback extends ConsumerWidget {
  const _DesktopMapFallback({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final unidadesSP = r.watch(unidadesActivasProvider);

    return Container(
      margin: const EdgeInsets.all(GloboSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1923),
        borderRadius: GloboRadius.cardRadius,
        border: Border.all(color: GloboColors.divider),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(GloboSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: GloboColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.map_outlined,
                    size: 16, color: GloboColors.accentGlow),
                const SizedBox(width: GloboSpacing.sm),
                Text(
                  'Posiciones de Flota',
                  style: GloboTypography.labelLarge
                      .copyWith(color: GloboColors.textOnDark),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: GloboColors.infoLight.withAlpha(20),
                    borderRadius: GloboRadius.chipRadius,
                    border: Border.all(
                        color: GloboColors.accentGlow.withAlpha(60)),
                  ),
                  child: Text(
                    'Mapa disponible en versión Web',
                    style: GloboTypography.caption
                        .copyWith(color: GloboColors.accentGlow, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          // Lista de unidades con posición
          Expanded(
            child: unidadesSP.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: GloboColors.accentGlow)),
              error: (e, _) => Center(
                  child: Text(e.toString(),
                      style: GloboTypography.caption)),
              data: (unidades) {
                final conPos =
                    unidades.where((u) => u.ultimaPosicion != null).toList();
                if (conPos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gps_off,
                            size: 32, color: GloboColors.steelGray),
                        const SizedBox(height: GloboSpacing.sm),
                        Text('Sin posición reportada',
                            style: GloboTypography.caption),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(GloboSpacing.sm),
                  itemCount: conPos.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 0, color: GloboColors.divider),
                  itemBuilder: (ctx, i) {
                    final u = conPos[i];
                    final pos = u.ultimaPosicion!;
                    final color = u.estado == EstadoUnidad.activa
                        ? GloboColors.success
                        : u.estado == EstadoUnidad.mantenimiento
                            ? GloboColors.warning
                            : GloboColors.error;
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      title: Text(u.placas,
                          style: GloboTypography.labelLarge
                              .copyWith(color: GloboColors.textOnDark)),
                      subtitle: Text(
                        '${pos.lat.toStringAsFixed(4)}, '
                        '${pos.lng.toStringAsFixed(4)}',
                        style: GloboTypography.monoData
                            .copyWith(fontSize: 11,
                                color: GloboColors.textOnDarkSecondary),
                      ),
                      trailing: Text(
                        u.modelo,
                        style: GloboTypography.caption
                            .copyWith(color: GloboColors.textTertiary),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers de UI ─────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: GloboRadius.buttonRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: GloboColors.success, label: 'Activa'),
          const SizedBox(width: GloboSpacing.sm),
          _LegendDot(color: GloboColors.warning, label: 'Mantenimiento'),
          const SizedBox(width: GloboSpacing.sm),
          _LegendDot(color: GloboColors.error, label: 'Baja'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8, height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 10)),
      ],
    );
  }
}

class _UnitCountBadge extends StatelessWidget {
  final int count;
  const _UnitCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: GloboRadius.buttonRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping,
              size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text('$count unidades',
              style: const TextStyle(
                  color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LoadingMap extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1A2B3C),
        child: const Center(
          child: CircularProgressIndicator(color: GloboColors.accentGlow),
        ),
      );
}

class _MapError extends StatelessWidget {
  final String message;
  const _MapError({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1A2B3C),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 32, color: GloboColors.error),
              const SizedBox(height: GloboSpacing.sm),
              Text(message, style: GloboTypography.caption),
            ],
          ),
        ),
      );
}

// ── Estilo oscuro del mapa (alineado con la paleta de Globo) ──────────────────

const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0f1923"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8f9eb0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0f1923"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1b3f6e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0b2545"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1565c0"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0d2137"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#42a5f5"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#1b3f6e"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#b0c4d8"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';
