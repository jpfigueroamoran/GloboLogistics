import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import '../../entities/viaje.dart';
import '../../repositories/i_seguridad_repository.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';

class TriggerSosUsecase {
  final ISeguridadRepository _repository;

  Timer? _locationTimer;
  String? _activeSosAlertaId;

  TriggerSosUsecase(this._repository);

  Future<Either<Failure, Unit>> call({
    required String viajeId,
    required String operadorId,
    required String unidadId,
  }) async {
    try {
      // Verificar permisos GPS
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const Left(PermissionFailure('GPS requerido para activar SOS.'));
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final geoPoint = GeoPoint(lat: pos.latitude, lng: pos.longitude);

      final result = await _repository.triggerSOS(
          viajeId, operadorId, unidadId, geoPoint);

      result.fold(
        (_) {},
        (alertaId) {
          _activeSosAlertaId = alertaId;
          _startLocationPing();
        },
      );

      return result.map((_) => unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  void _startLocationPing() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: AppConstants.sosIntervalSeconds),
      (_) => _pingLocation(),
    );
  }

  Future<void> _pingLocation() async {
    if (_activeSosAlertaId == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _repository.enviarPosicionSOS(
        _activeSosAlertaId!,
        GeoPoint(lat: pos.latitude, lng: pos.longitude),
      );
    } catch (_) {
      // Silencioso: se reintenta en el siguiente ciclo
    }
  }

  void cancelarSOS() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _activeSosAlertaId = null;
  }
}
