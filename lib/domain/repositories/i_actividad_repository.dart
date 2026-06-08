import 'package:dartz/dartz.dart';
import '../entities/actividad_operativa.dart';
import '../../core/errors/failures.dart';

abstract interface class IActividadRepository {
  Future<Either<Failure, Unit>> logActividad(ActividadOperativa actividad);
  Future<Either<Failure, Unit>> sincronizarPendientes();
  Stream<List<ActividadOperativa>> watchActividadesByViaje(String viajeId);
  Future<List<ActividadOperativa>> getActividadesPendientes();
}
