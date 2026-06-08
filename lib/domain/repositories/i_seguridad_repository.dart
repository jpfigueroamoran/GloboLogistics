import 'package:dartz/dartz.dart';
import '../entities/alerta_seguridad.dart';
import '../entities/viaje.dart';
import '../../core/errors/failures.dart';

abstract interface class ISeguridadRepository {
  /// Returns the alertaId on success.
  Future<Either<Failure, String>> triggerSOS(
      String viajeId, String operadorId, String unidadId, GeoPoint posicion);
  Future<Either<Failure, Unit>> enviarPosicionSOS(
      String alertaId, GeoPoint posicion);
  Stream<List<AlertaSeguridad>> watchAlertasActivas();
  Future<Either<Failure, Unit>> atenderAlerta(
      String alertaId, String atendidaPor, String notas);
}
