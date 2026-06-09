import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/unidad.dart';
import '../providers/unidades_provider.dart';

// Centro geográfico de México
const _mexicoCenter = LatLng(23.6345, -102.5528);

class FleetMapWidget extends ConsumerStatefulWidget {
  const FleetMapWidget({super.key});

  @override
  ConsumerState<FleetMapWidget> createState() => _FleetMapWidgetState();
}

class _FleetMapWidgetState extends ConsumerState<FleetMapWidget> {
  final MapController _mapController = MapController();
  String? _selectedUnidadId;

  @override
  Widget build(BuildContext context) {
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
              data: (unidades) => _FlutterMapView(
                unidades: unidades,
                selectedId: _selectedUnidadId,
                mapController: _mapController,
                onMarkerTap: (id) => setState(() => _selectedUnidadId = id),
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
              ).valueOrNull ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flutter Map view ──────────────────────────────────────────────────────────

class _FlutterMapView extends StatelessWidget {
  final List<Unidad> unidades;
  final String? selectedId;
  final MapController mapController;
  final void Function(String) onMarkerTap;

  const _FlutterMapView({
    required this.unidades,
    required this.selectedId,
    required this.mapController,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    for (final u in unidades) {
      final pos = u.ultimaPosicion;
      if (pos == null) continue;

      final color = u.estado == EstadoUnidad.activa
          ? GloboColors.success
          : u.estado == EstadoUnidad.mantenimiento
              ? GloboColors.warning
              : GloboColors.error;

      final isSelected = u.id == selectedId;

      markers.add(
        Marker(
          point: LatLng(pos.lat, pos.lng),
          width: isSelected ? 180 : 40,
          height: isSelected ? 80 : 40,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => onMarkerTap(u.id),
            child: isSelected
                ? _InfoTooltip(unidad: u, color: color)
                : Icon(
                    Icons.location_on,
                    color: color,
                    size: 40,
                    shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
                  ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: _mexicoCenter,
        initialZoom: 5.2,
        onTap: (_, __) => onMarkerTap(''), // Deseleccionar al tocar mapa
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.globo.logistics',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

// ── Info Tooltip (para marcadores seleccionados) ──────────────────────────────
class _InfoTooltip extends StatelessWidget {
  final Unidad unidad;
  final Color color;

  const _InfoTooltip({required this.unidad, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GloboColors.surface,
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: color),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(GloboSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(unidad.placas, style: GloboTypography.labelSmall.copyWith(color: color)),
          Text('${unidad.modelo} ${unidad.anio}', style: GloboTypography.caption),
          const SizedBox(height: 4),
          Icon(Icons.arrow_drop_down, color: GloboColors.steelGray.withAlpha(120)),
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
            width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
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
          const Icon(Icons.local_shipping, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text('$count unidades', style: const TextStyle(color: Colors.white, fontSize: 11)),
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
              const Icon(Icons.error_outline, size: 32, color: GloboColors.error),
              const SizedBox(height: GloboSpacing.sm),
              Text(message, style: GloboTypography.caption),
            ],
          ),
        ),
      );
}
