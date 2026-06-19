import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/theme_constants.dart';
import '../../../../domain/entities/unidad.dart';
import '../../../../domain/entities/viaje.dart';
import '../providers/dashboard_provider.dart' show viajesActivosProvider;
import '../providers/unidades_provider.dart';

// Estado operativo derivado (lo que de verdad le importa al supervisor)
enum _EstadoOperativo { enRuta, disponible, taller, baja }

(_EstadoOperativo, Color) _operativo(Unidad u) {
  if (u.estado == EstadoUnidad.baja) return (_EstadoOperativo.baja, GloboColors.error);
  if (u.estado == EstadoUnidad.mantenimiento) {
    return (_EstadoOperativo.taller, GloboColors.warning);
  }
  if (u.enRuta) return (_EstadoOperativo.enRuta, GloboColors.estadoTransito);
  return (_EstadoOperativo.disponible, GloboColors.success);
}

String _zonaLabel(String zona) => switch (zona) {
      'cercaOrigen'   => 'Acercándose a carga',
      'enBodegaCarga' => 'En bodega de carga',
      'enTransito'    => 'En tránsito',
      'cercaDestino'  => 'Llegando al destino',
      'enDestino'     => 'En destino',
      _               => 'En ruta',
    };

String etaLabel(int? etaMin) {
  if (etaMin == null) return '';
  if (etaMin <= 0) return 'En el destino';
  if (etaMin < 60) return 'ETA ~$etaMin min';
  final h = etaMin ~/ 60;
  final m = etaMin % 60;
  return 'ETA ~${h}h ${m}m';
}

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
    // Viaje en curso por unidad — para mostrar destino y ETA en el mapa
    final viajes = ref.watch(viajesActivosProvider).valueOrNull ?? [];
    final viajePorUnidad = <String, Viaje>{};
    for (final v in viajes) {
      if (v.estado == EstadoViaje.enCurso && v.unidadId.isNotEmpty) {
        viajePorUnidad[v.unidadId] = v;
      }
    }

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
                viajePorUnidad: viajePorUnidad,
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
  final Map<String, Viaje> viajePorUnidad;
  final String? selectedId;
  final MapController mapController;
  final void Function(String) onMarkerTap;

  const _FlutterMapView({
    required this.unidades,
    required this.viajePorUnidad,
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

      final (estadoOp, color) = _operativo(u);
      final viaje = viajePorUnidad[u.id];
      final isSelected = u.id == selectedId;

      markers.add(
        Marker(
          point: LatLng(pos.lat, pos.lng),
          width: isSelected ? 220 : 40,
          height: isSelected ? 116 : 40,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => onMarkerTap(u.id),
            child: isSelected
                ? _InfoTooltip(unidad: u, viaje: viaje, color: color)
                : _MarkerPin(color: color, enRuta: estadoOp == _EstadoOperativo.enRuta),
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

// ── Pin del marcador (anillo pulsante si va en ruta) ──────────────────────────
class _MarkerPin extends StatelessWidget {
  final Color color;
  final bool enRuta;
  const _MarkerPin({required this.color, required this.enRuta});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (enRuta)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(45),
              border: Border.all(color: color.withAlpha(120)),
            ),
          ),
        Icon(
          enRuta ? Icons.local_shipping : Icons.location_on,
          color: color,
          size: enRuta ? 22 : 36,
          shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
        ),
      ],
    );
  }
}

// ── Info Tooltip (para marcadores seleccionados) ──────────────────────────────
class _InfoTooltip extends StatelessWidget {
  final Unidad unidad;
  final Viaje? viaje;
  final Color color;

  const _InfoTooltip(
      {required this.unidad, required this.viaje, required this.color});

  @override
  Widget build(BuildContext context) {
    final seg = viaje?.seguimiento;
    return Container(
      decoration: BoxDecoration(
        color: GloboColors.surface,
        borderRadius: GloboRadius.buttonRadius,
        border: Border.all(color: color),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping, size: 13, color: color),
            const SizedBox(width: 4),
            Text(unidad.placas,
                style: GloboTypography.labelSmall.copyWith(color: color)),
          ]),
          if (viaje != null) ...[
            const SizedBox(height: 2),
            Text('→ ${viaje!.destinoDescripcion}',
                style: GloboTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            if (seg != null) ...[
              const SizedBox(height: 2),
              Text(_zonaLabel(seg.zona),
                  style: GloboTypography.caption
                      .copyWith(color: GloboColors.estadoTransito)),
              if (etaLabel(seg.etaMin).isNotEmpty)
                Text(etaLabel(seg.etaMin),
                    style: GloboTypography.labelSmall
                        .copyWith(color: GloboColors.primary)),
            ] else
              Text('Esperando GPS…', style: GloboTypography.caption),
          ] else
            Text('${unidad.modelo} ${unidad.anio} · Disponible',
                style: GloboTypography.caption),
          const Icon(Icons.arrow_drop_down, color: GloboColors.steelGray),
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
          _LegendDot(color: GloboColors.estadoTransito, label: 'En ruta'),
          const SizedBox(width: GloboSpacing.sm),
          _LegendDot(color: GloboColors.success, label: 'Disponible'),
          const SizedBox(width: GloboSpacing.sm),
          _LegendDot(color: GloboColors.warning, label: 'Taller'),
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
