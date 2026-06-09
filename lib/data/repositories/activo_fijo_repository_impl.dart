import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/activo_fijo.dart';
import '../../domain/repositories/i_activo_fijo_repository.dart';
import '../datasources/remote/activo_fijo_firestore_datasource.dart';
import '../models/activo_fijo_model.dart';

class ActivoFijoRepositoryImpl implements IActivoFijoRepository {
  final ActivoFijoFirestoreDatasource _ds;
  ActivoFijoRepositoryImpl(this._ds);

  @override
  Stream<List<ActivoFijo>> watchActivosFijos() => _ds.watchActivosFijos();

  @override
  Future<Either<Failure, String>> crearActivo(ActivoFijo activo) async {
    try {
      final id = await _ds.crearActivo(ActivoFijoModel.fromEntity(activo));
      return Right(id);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> actualizarActivo(ActivoFijo activo) async {
    try {
      await _ds.actualizarActivo(
          activo.id, ActivoFijoModel.fromEntity(activo).toFirestore());
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> eliminarActivo(String id) async {
    try {
      await _ds.eliminarActivo(id);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
