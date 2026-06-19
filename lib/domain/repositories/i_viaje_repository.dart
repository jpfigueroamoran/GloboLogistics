import 'package:dartz/dartz.dart';
import '../entities/viaje.dart';
import '../../core/errors/failures.dart';

abstract interface class IViajeRepository {
  Stream<List<Viaje>> watchViajesActivos();
  Future<Either<Failure, Viaje>> getViaje(String id);
  Future<Either<Failure, String>> crearViaje(Viaje viaje);
  Future<Either<Failure, Unit>> actualizarEstado(
      String viajeId, EstadoViaje nuevoEstado);
  Future<Either<Failure, Unit>> asignarViaje(
      String viajeId, String operadorId, String unidadId);
  Future<Either<Failure, Unit>> justificarVarianza(
      String viajeId, String motivo);
  Future<Either<Failure, Unit>> actualizarTco(String viajeId, TcoViaje tco);
  Future<Either<Failure, Unit>> marcarBanderaRoja(
      String viajeId, double varianza);

  /// El dispositivo del operador publica progreso en vivo (zona/ETA) para que
  /// Torre de Control lo vea. Falla en silencio sin red — se reintenta solo.
  Future<Either<Failure, Unit>> actualizarSeguimiento(
      String viajeId, SeguimientoViaje seguimiento);

  Stream<List<Viaje>> watchViajesPorOperador(String operadorId);
  Stream<List<Viaje>> watchViajesCompletados();
}
