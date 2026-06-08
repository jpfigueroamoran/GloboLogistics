import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../domain/entities/viaje.dart' show GeoPoint;
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../injection_container.dart';

final gpsTrackerProvider = StateNotifierProvider<GpsTrackerNotifier, bool>((ref) {
  return GpsTrackerNotifier(sl<FirestoreDatasource>());
});

class GpsTrackerNotifier extends StateNotifier<bool> {
  final FirestoreDatasource _remote;
  StreamSubscription<Position>? _positionStream;

  GpsTrackerNotifier(this._remote) : super(false);

  Future<void> startTracking(String unidadId) async {
    if (state) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    state = true;
    
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Notificar cada 10 metros
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      // Subir a Firestore
      _remote.updatePosicionUnidad(
        unidadId,
        GeoPoint(lat: position.latitude, lng: position.longitude),
      ).catchError((_) {
        // Manejar error silenciosamente si falla la red (se encarga el offline sync)
      });
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    state = false;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
