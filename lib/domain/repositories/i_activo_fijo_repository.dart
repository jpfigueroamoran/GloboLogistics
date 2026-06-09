import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/activo_fijo.dart';

abstract class IActivoFijoRepository {
  Stream<List<ActivoFijo>> watchActivosFijos();
  Future<Either<Failure, String>> crearActivo(ActivoFijo activo);
  Future<Either<Failure, Unit>> actualizarActivo(ActivoFijo activo);
  Future<Either<Failure, Unit>> eliminarActivo(String id);
}
