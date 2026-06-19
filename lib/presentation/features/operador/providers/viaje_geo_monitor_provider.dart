import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../domain/entities/viaje.dart';
import '../../../../domain/repositories/i_viaje_repository.dart';
import '../../../../injection_container.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado del geofence
// ─────────────────────────────────────────────────────────────────────────────

enum GeofenceZone {
  sinViaje,
  fueraDeRuta,
  cercaOrigen,
  enBodegaCarga,
  enTransito,
  cercaDestino,
  enDestino,
}

class GeoMonitorState {
  final GeofenceZone zona;
  final double? distanciaOrigenM;
  final double? distanciaDestinoM;
  final bool stopDetectado;
  final int segundosEnDestino;

  const GeoMonitorState({
    this.zona = GeofenceZone.sinViaje,
    this.distanciaOrigenM,
    this.distanciaDestinoM,
    this.stopDetectado = false,
    this.segundosEnDestino = 0,
  });

  GeoMonitorState copyWith({
    GeofenceZone? zona,
    double? distanciaOrigenM,
    double? distanciaDestinoM,
    bool? stopDetectado,
    int? segundosEnDestino,
  }) =>
      GeoMonitorState(
        zona: zona ?? this.zona,
        distanciaOrigenM: distanciaOrigenM ?? this.distanciaOrigenM,
        distanciaDestinoM: distanciaDestinoM ?? this.distanciaDestinoM,
        stopDetectado: stopDetectado ?? this.stopDetectado,
        segundosEnDestino: segundosEnDestino ?? this.segundosEnDestino,
      );

  String get zonaLabel => switch (zona) {
        GeofenceZone.sinViaje      => 'Sin viaje activo',
        GeofenceZone.fueraDeRuta   => 'En ruta',
        GeofenceZone.cercaOrigen   => 'Acercándose a bodega',
        GeofenceZone.enBodegaCarga => 'En bodega de carga',
        GeofenceZone.enTransito    => 'En tránsito',
        GeofenceZone.cercaDestino  => 'Acercándose a destino',
        GeofenceZone.enDestino     => 'En destino de descarga',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ViajeGeoMonitorNotifier extends StateNotifier<GeoMonitorState> {
  final IViajeRepository _viajeRepo;

  StreamSubscription<Position>? _posSub;
  Timer? _stopTimer;
  Timer? _contadorTimer;
  Position? _ultimaPosicion;
  bool _autoStartedThisSession = false;
  bool _autoCompletedThisSession = false;

  // Throttle de publicación de seguimiento a Torre de Control
  DateTime? _ultimoReporte;
  GeofenceZone? _zonaReportada;

  // Radio de geofences (metros)
  static const double _radioOrigenM   = 300;
  static const double _radioDestinoM  = 200;
  static const double _radioCercaM    = 600;

  // Velocidad promedio para estimar ETA sin API de ruteo de pago (costo-cero)
  static const double _velocidadPromedioKmh = 45;

  // Tiempo parado en destino para auto-completar (segundos)
  static const int _stopSegundos = 300; // 5 min

  ViajeGeoMonitorNotifier(this._viajeRepo) : super(const GeoMonitorState());

  void startMonitoring(Viaje viaje) {
    _posSub?.cancel();
    _stopTimer?.cancel();
    _contadorTimer?.cancel();
    _autoStartedThisSession = false;
    _autoCompletedThisSession = false;

    if (viaje.origenGeo == null && viaje.destinoGeo == null) {
      state = const GeoMonitorState(zona: GeofenceZone.sinViaje);
      return;
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );

    _posSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) => _evaluar(pos, viaje));
  }

  void stopMonitoring() {
    _posSub?.cancel();
    _stopTimer?.cancel();
    _contadorTimer?.cancel();
    _posSub = null;
    state = const GeoMonitorState(zona: GeofenceZone.sinViaje);
  }

  void _evaluar(Position pos, Viaje viaje) {
    final distOrigen = viaje.origenGeo != null
        ? Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            viaje.origenGeo!.lat, viaje.origenGeo!.lng)
        : null;

    final distDestino = viaje.destinoGeo != null
        ? Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            viaje.destinoGeo!.lat, viaje.destinoGeo!.lng)
        : null;

    GeofenceZone zona;

    // Prioridad: destino > origen > en tránsito
    if (distDestino != null && distDestino < _radioDestinoM) {
      zona = GeofenceZone.enDestino;
      _manejarLlegadaDestino(pos, viaje);
    } else if (distDestino != null && distDestino < _radioCercaM) {
      zona = GeofenceZone.cercaDestino;
      _cancelarStopTimer();
    } else if (distOrigen != null && distOrigen < _radioOrigenM) {
      zona = GeofenceZone.enBodegaCarga;
      _cancelarStopTimer();
      _manejarLlegadaOrigen(viaje);
    } else if (distOrigen != null && distOrigen < _radioCercaM) {
      zona = GeofenceZone.cercaOrigen;
      _cancelarStopTimer();
    } else if (viaje.estado == EstadoViaje.enCurso) {
      zona = GeofenceZone.enTransito;
      _cancelarStopTimer();
    } else {
      zona = GeofenceZone.fueraDeRuta;
      _cancelarStopTimer();
    }

    _ultimaPosicion = pos;

    state = state.copyWith(
      zona: zona,
      distanciaOrigenM: distOrigen,
      distanciaDestinoM: distDestino,
    );

    _publicarSeguimiento(viaje, zona, distDestino);
  }

  /// Publica zona + ETA al viaje para que Torre de Control lo vea en vivo.
  /// Throttle: solo cuando cambia la zona o han pasado >30 s, para no escribir
  /// en cada ping de GPS (cuida la cuota gratuita de Firestore).
  void _publicarSeguimiento(
      Viaje viaje, GeofenceZone zona, double? distDestino) {
    if (viaje.estado != EstadoViaje.enCurso) return;

    final ahora = DateTime.now();
    final cambioZona = zona != _zonaReportada;
    final pasoTiempo = _ultimoReporte == null ||
        ahora.difference(_ultimoReporte!).inSeconds >= 30;
    if (!cambioZona && !pasoTiempo) return;

    _ultimoReporte = ahora;
    _zonaReportada = zona;

    int? etaMin;
    if (distDestino != null && distDestino > 0) {
      final horas = (distDestino / 1000) / _velocidadPromedioKmh;
      etaMin = (horas * 60).ceil();
    } else if (zona == GeofenceZone.enDestino) {
      etaMin = 0;
    }

    _viajeRepo.actualizarSeguimiento(
      viaje.id,
      SeguimientoViaje(
        zona: zona.name,
        distanciaDestinoM: distDestino,
        etaMin: etaMin,
      ),
    );
  }

  void _manejarLlegadaOrigen(Viaje viaje) {
    if (_autoStartedThisSession) return;
    if (viaje.estado != EstadoViaje.programado) return;

    _autoStartedThisSession = true;
    _viajeRepo.actualizarEstado(viaje.id, EstadoViaje.enCurso);
  }

  void _manejarLlegadaDestino(Position pos, Viaje viaje) {
    if (_autoCompletedThisSession) return;
    if (viaje.estado != EstadoViaje.enCurso) return;

    // Verificar si hay movimiento real
    if (_ultimaPosicion != null) {
      final mov = Geolocator.distanceBetween(
        _ultimaPosicion!.latitude, _ultimaPosicion!.longitude,
        pos.latitude, pos.longitude,
      );
      if (mov > 30) {
        // Hubo movimiento: reiniciar contador
        _cancelarStopTimer();
        _iniciarContador(viaje.id);
        return;
      }
    }

    // Iniciar contador solo si no hay uno activo
    if (_stopTimer == null || !_stopTimer!.isActive) {
      _iniciarContador(viaje.id);
    }
  }

  void _iniciarContador(String viajeId) {
    var segs = 0;
    _contadorTimer?.cancel();
    _contadorTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      segs++;
      state = state.copyWith(segundosEnDestino: segs);
      if (segs >= _stopSegundos) t.cancel();
    });

    _stopTimer = Timer(const Duration(seconds: _stopSegundos), () {
      _autoCompletedThisSession = true;
      _contadorTimer?.cancel();
      state = state.copyWith(stopDetectado: true);
      // Auto-complete triggers Fn15 lifecycle pipeline
      _viajeRepo.actualizarEstado(viajeId, EstadoViaje.completado);
    });
  }

  void _cancelarStopTimer() {
    _stopTimer?.cancel();
    _contadorTimer?.cancel();
    _stopTimer = null;
    if (state.segundosEnDestino > 0 || state.stopDetectado) {
      state = state.copyWith(segundosEnDestino: 0, stopDetectado: false);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stopTimer?.cancel();
    _contadorTimer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider — family por viajeId (se recrea cuando cambia el viaje)
// ─────────────────────────────────────────────────────────────────────────────

final viajeGeoMonitorProvider = StateNotifierProvider.autoDispose
    .family<ViajeGeoMonitorNotifier, GeoMonitorState, Viaje>(
  (ref, viaje) {
    final notifier = ViajeGeoMonitorNotifier(sl<IViajeRepository>());
    notifier.startMonitoring(viaje);
    ref.onDispose(notifier.stopMonitoring);
    return notifier;
  },
);
