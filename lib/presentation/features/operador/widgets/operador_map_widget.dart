import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/theme_constants.dart';

// Proveedor de simulación para desktop o fallback
final currentLocationProvider = StreamProvider<Position>((ref) async* {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    );
  } catch (e) {
    // Fallback simulado para entornos de prueba sin GPS
    yield Position(
      longitude: -100.9855,
      latitude: 22.1565,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }
});

class OperadorMapWidget extends ConsumerStatefulWidget {
  const OperadorMapWidget({super.key});

  @override
  ConsumerState<OperadorMapWidget> createState() => _OperadorMapWidgetState();
}

class _OperadorMapWidgetState extends ConsumerState<OperadorMapWidget> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(GloboSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.map, color: GloboColors.primary, size: 20),
                const SizedBox(width: GloboSpacing.sm),
                Text('Mi Ubicación en Tiempo Real', style: GloboTypography.titleMedium),
              ],
            ),
          ),
          SizedBox(
            height: 250,
            child: locationAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error al obtener ubicación: $e')),
              data: (pos) {
                final latLng = LatLng(pos.latitude, pos.longitude);
                
                // Animar el mapa a la nueva posición suavemente
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapController.move(latLng, 15);
                });

                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: latLng,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.globo.logistics',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: latLng,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.my_location,
                            color: GloboColors.primary,
                            size: 30,
                            shadows: [Shadow(color: GloboColors.accentGlow, blurRadius: 10)],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
