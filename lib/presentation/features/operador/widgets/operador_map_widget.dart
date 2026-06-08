import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/theme_constants.dart';

final currentLocationProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  );
});

class OperadorMapWidget extends ConsumerStatefulWidget {
  const OperadorMapWidget({super.key});

  @override
  ConsumerState<OperadorMapWidget> createState() => _OperadorMapWidgetState();
}

class _OperadorMapWidgetState extends ConsumerState<OperadorMapWidget> {
  GoogleMapController? _controller;

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
                if (_controller != null) {
                  _controller!.animateCamera(CameraUpdate.newLatLng(latLng));
                }

                return GoogleMap(
                  initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
                  onMapCreated: (c) => _controller = c,
                  markers: {
                    Marker(
                      markerId: const MarkerId('me'),
                      position: latLng,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  style: _darkMapStyle,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0f1923"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8f9eb0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0f1923"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1b3f6e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#0b2545"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1565c0"}]}
]
''';
